"""
Generatore della bozza di scheda CER per CER_configuration/.

La pipeline di generazione profili sa gia' tutto quello che serve a compilare
la meta' meccanica di una scheda CER: quante utenze ci sono, come si chiamano
le colonne del CSV, da quale archetipo vengono e in che ordine stanno. Finora
quelle informazioni venivano ricopiate a mano in CER_configuration/CER_C_P_E.txt,
ed e' li' che nascevano i disallineamenti: align_members_to_users.m pretende
che l'insieme dei nome_csv coincida ESATTAMENTE con le colonne numeriche di
profili_tutti.csv, in entrambe le direzioni, e una colonna aggiunta al YAML e
dimenticata nella scheda ferma MATLAB.

Questo modulo scrive la parte meccanica e si ferma dove finisce cio' che il
Python puo' sapere. Il fotovoltaico, i dati socio-economici e l'identita' della
comunita' restano da compilare a mano: la testata del file li elenca.

IL FILE PRODOTTO NON E' ANCORA CARICABILE, ed e' voluto. MAIN.m fa
    dir("CER_configuration/CER_*.txt")
e carica ogni file trovato in un for senza try/catch: una bozza incompleta
depositata come CER_*.txt fermerebbe l'intero batch. Il prefisso 'bozza_' la
tiene fuori da quel glob. La cartella e' pero' gia' quella definitiva, cosi' i
percorsi relativi '../' sono corretti: attivarla e' una rinomina, nient'altro.
"""

import calendar
import logging
import os
import sqlite3
from datetime import datetime
from pathlib import Path

logger = logging.getLogger(__name__)


# Default per archetipo, ricavati da CER_configuration/CER_5_1_0.txt: sono le
# scelte gia' fatte a mano per questa CER, non stime nuove. Rigenerare la
# configurazione attuale deve percio' riprodurre quella scheda, e la scheda
# scritta a mano fa da oracolo di collaudo.
#
# P_prel_kW e' potenza IMPEGNATA da contratto, non il picco RAMP (office 9.2,
# small_industry 21.0, retail 4.4 kW): sono due grandezze diverse, e la prima
# non si deduce dalla seconda.
DEFAULT_RAMP: dict[str, tuple[str, str, str]] = {
    # use_case      : (categoria,     tariffa,            P_prel_kW)
    "office":         ("terziario",   "BIORARIA",         "10"),
    "small_industry": ("industriale", "ORARIO_VARIABILE", "50"),
    "retail":         ("commerciale", "MONORARIA",        "15"),
}

# Le famiglie LPG sono tutte domestiche: un default solo, non una tabella.
DEFAULT_LPG: tuple[str, str, str] = ("domestico", "MONORARIA", "3")

# Percorsi di [FILE] che il Python non calcola: gli stessi della scheda
# esistente, relativi alla cartella della scheda (CER_configuration/).
PREZZI_ZONALI = "../20250101_20251231_MGP_PrezziZonali_Nord.xlsx"
CARTELLA_PV = "../PV_Generation"
SCENARIO_ECONOMICO = "scenario_economico.txt"

# [GOVERNANCE]: scelte deliberate dalla CER, riprese da CER_5_1_0.txt.
GOVERNANCE: list[tuple[str, str]] = [
    ("ct_riserva", "0.00"),
    ("ct_quota_fissa", "0.30"),
    ("ct_quota_prelievi", "0.50"),
    ("ct_quota_prosumer", "0.60"),
    ("psk_alpha", "0.50"),
    ("as_campioni", "1000"),
    ("as_seed", "42"),
]

INTESTAZIONE_MEMBRI = [
    "id", "nome_csv", "ruolo", "categoria", "archetipo", "tariffa",
    "P_prel_kW", "n_comp", "n_perc", "reddito_EUR", "gas_kWh",
    "quota_inv_EUR", "mutuo_EUR_anno", "impianto",
]

INTESTAZIONE_IMPIANTI = [
    "id", "proprietario", "kWp", "file_produzione", "tilt", "azimut",
    "anno_esercizio", "capex_EUR", "opex_EUR_anno",
]

# Colonne incolonnate a destra, come in CER_5_1_0.txt: sono quelle che si
# leggono confrontandole fra loro, e allineate a destra si confrontano a colpo
# d'occhio. Il resto va a sinistra, come il testo.
COLONNE_A_DESTRA = {
    "id", "P_prel_kW", "n_comp", "n_perc", "reddito_EUR", "gas_kWh",
    "quota_inv_EUR", "mutuo_EUR_anno", "kWp", "tilt", "azimut",
    "anno_esercizio", "capex_EUR", "opex_EUR_anno",
}


def _n_comp_da_db(percorso_db: Path, riferimenti: list[str]) -> dict[str, int]:
    """Numero di componenti per ogni household_ref, letto dal catalogo LPG.

    E' un dato che il progetto gia' possiede: lasciarlo a '?' nella scheda lo
    farebbe comparire nel registro delle ipotesi senza che manchi davvero.

    La connessione e' in sola lettura e immutable, cosi' sqlite non crea file
    -wal accanto al catalogo. Ogni errore (db assente - e' gitignorato -,
    schema diverso, template non trovato) degrada a dizionario vuoto: n_comp
    esce '?' e la generazione prosegue.

    Args:
        percorso_db: Catalogo .db3 di pyLPG.
        riferimenti: household_ref cosi' come scritti nel YAML.

    Returns:
        Mappa household_ref -> numero di componenti. Vuota se il db non e'
        leggibile; priva delle voci non trovate.
    """
    if not percorso_db.is_file():
        logger.warning(
            "Catalogo LPG non trovato (%s): n_comp restera' '?' nella bozza.",
            percorso_db,
        )
        return {}

    conteggi: dict[str, int] = {}
    try:
        uri = f"file:{percorso_db.as_posix()}?mode=ro&immutable=1"
        con = sqlite3.connect(uri, uri=True)
        try:
            cur = con.cursor()
            for ref in riferimenti:
                # Il codice ('CHR54') e' l'unica parte che il db condivide col
                # YAML: i nomi differiscono per punteggiatura e spazi
                # ('CHR54 Retired Couple, no work' vs household_ref).
                codice = ref.split("_", 1)[0]
                riga = cur.execute(
                    "SELECT ID FROM tblModularHouseholds WHERE Name LIKE ?",
                    (f"{codice} %",),
                ).fetchone()
                if riga is None:
                    logger.warning(
                        "Template %s non trovato nel catalogo LPG.", codice
                    )
                    continue
                n = cur.execute(
                    "SELECT COUNT(DISTINCT PersonID) FROM tblCHHPersons "
                    "WHERE ParentHouseholdID = ?",
                    (riga[0],),
                ).fetchone()[0]
                if n:
                    conteggi[ref] = int(n)
        finally:
            con.close()
    except sqlite3.Error as e:
        logger.warning(
            "Catalogo LPG non interrogabile (%s): n_comp restera' '?'.", e
        )
        return {}

    return conteggi


def _righe_membri(
    config: dict, base_path: Path
) -> tuple[list[list[str]], list[str]]:
    """Costruisce le righe di [MEMBRI] nell'ordine in cui la pipeline le produce.

    Ricalcola gli stessi nomi di colonna dei due runner - RAMP prima, LPG poi,
    come il join di generate_load_profiles.py - e ci appende il suffisso _kWh
    che export_to_csv aggiunge in fase di scrittura.

    Args:
        config: Configurazione YAML completa.
        base_path: Cartella CER_LoadProfiles/, per risolvere lpg.database.

    Returns:
        (righe, da_compilare): le righe come liste di celle gia' formattate, e
        gli archetipi privi di default, che lasciano celle a '?'.
    """
    righe: list[list[str]] = []
    da_compilare: list[str] = []
    idx = 0

    # --- RAMP: aziende e PMI ------------------------------------------------
    for uc in config.get("ramp", {}).get("use_cases", []):
        nome = uc["name"]
        default = DEFAULT_RAMP.get(nome)
        if default is None:
            logger.warning(
                "Use case RAMP '%s' senza default noti: categoria, tariffa e "
                "P_prel_kW restano '?' nella bozza.",
                nome,
            )
            da_compilare.append(nome)
            default = ("?", "?", "?")
        categoria, tariffa, potenza = default

        for i in range(uc["num_users"]):
            idx += 1
            righe.append([
                str(idx), f"{nome}_{i + 1}_kWh", "C", categoria, nome,
                tariffa, potenza,
                # Un'azienda non ha nucleo familiare ne' bolletta gas: '-' e'
                # "non applicabile", diverso da '?' che e' "non ancora noto".
                "-", "-", "-", "-",
                "?", "0", "-",
            ])

    # --- LPG: famiglie ------------------------------------------------------
    # lpg_runner.py numera le famiglie con un contatore suo, che riparte da 1 e
    # scorre tutti i gruppi: household_1, household_2, ... a prescindere da
    # quante utenze RAMP ci sono.
    famiglie = config.get("lpg", {}).get("households", [])
    lpg_config = config.get("lpg", {})
    percorso_db = base_path / lpg_config.get(
        "database", "lpg_db/profilegenerator.IT.db3"
    )
    n_comp = _n_comp_da_db(percorso_db, [f["household_ref"] for f in famiglie])
    categoria, tariffa, potenza = DEFAULT_LPG
    idx_lpg = 0

    for gruppo in famiglie:
        ref = gruppo["household_ref"]
        # La chiave 'archetipo' e' facoltativa: fissa le contrazioni gia' usate
        # a mano (CHR02_coppia_lav) al posto della derivazione automatica.
        archetipo = gruppo.get(
            "archetipo", f"{ref.split('_', 1)[0]}_{gruppo['label']}"
        )
        componenti = str(n_comp.get(ref, "?"))

        for _ in range(gruppo["count"]):
            idx += 1
            idx_lpg += 1
            righe.append([
                str(idx), f"household_{idx_lpg}_kWh", "C", categoria,
                archetipo, tariffa, potenza, componenti,
                # Domestici: '?' e mai '-'. load_cer_input.m rifiuta un '-' in
                # n_comp / n_perc / reddito_EUR su una riga 'domestico'.
                "?", "?", "?",
                "?", "0", "-",
            ])

    return righe, da_compilare


def _tabella(intestazione: list[str], righe: list[list[str]]) -> list[str]:
    """Formatta una tabella a pipe con le colonne allineate.

    L'allineamento e' solo estetico - il parser fa strtrim su ogni cella - ma
    tiene le bozze leggibili quanto le schede scritte a mano, che e' la
    condizione perche' vengano davvero rilette e completate.

    Nessun '|' iniziale o finale: split(riga, "|") produrrebbe due celle vuote
    in piu' e load_cer_input.m rifiuterebbe la riga per conteggio colonne.
    """
    larghezze = [
        max([len(intestazione[i])] + [len(r[i]) for r in righe])
        for i in range(len(intestazione))
    ]

    def allinea(cella: str, i: int) -> str:
        larghezza = larghezze[i]
        if intestazione[i] in COLONNE_A_DESTRA:
            return cella.rjust(larghezza)
        return cella.ljust(larghezza)

    out = [" | ".join(allinea(t, i) for i, t in enumerate(intestazione)).rstrip()]
    for r in righe:
        out.append(" | ".join(allinea(c, i) for i, c in enumerate(r)).rstrip())
    return out


def _percorso_relativo(destinazione: Path, partenza: Path) -> str:
    """Percorso di destinazione visto da partenza, con separatori POSIX.

    I percorsi di [FILE] sono relativi alla cartella della scheda, non alla
    cartella di lavoro di MATLAB, e devono restare relativi perche' il progetto
    giri anche spostato di cartella o su un'altra macchina.
    """
    return os.path.relpath(destinazione, partenza).replace(os.sep, "/")


def scrivi_bozza_scheda(
    config: dict,
    colonne: list[str],
    percorso_profili: Path,
    base_path: Path,
    marca: str,
    cartella_schede: Path | None = None,
) -> Path:
    """Scrive in CER_configuration/ la bozza di scheda CER di questo run.

    Args:
        config: Configurazione YAML completa.
        colonne: Nomi delle colonne numeriche come finiscono nel CSV, cioe'
            l'output di postprocessing.nomi_colonne_esportate().
        percorso_profili: CSV a cui la scheda deve puntare (la copia in
            storico/ se il versionamento e' attivo, altrimenti il nome fisso).
        base_path: Cartella CER_LoadProfiles/.
        marca: Marca temporale del run, formato YYYYMMDD_HHMMSS.
        cartella_schede: Cartella di destinazione. Default:
            <radice progetto>/CER_configuration.

    Returns:
        Percorso della bozza scritta.

    Raises:
        ValueError: Se le utenze ricostruite dal YAML non coincidono con le
            colonne del CSV appena scritto. E' il controllo che rende
            l'automatismo affidabile: piuttosto che produrre una scheda che
            align_members_to_users.m rifiuterebbe a valle, si ferma qui, dove
            l'errore e' ancora leggibile.
    """
    if cartella_schede is None:
        cartella_schede = base_path.parent / "CER_configuration"

    righe, da_compilare = _righe_membri(config, base_path)

    # La scheda dichiara utenze che il CSV deve avere, una per una. Se le due
    # liste divergono la colpa e' quasi sempre di un runner fallito a meta':
    # meglio dirlo adesso col nome delle utenze mancanti.
    ricostruite = [r[1] for r in righe]
    if ricostruite != list(colonne):
        raise ValueError(
            "Le utenze ricostruite dal YAML non coincidono con le colonne del "
            f"CSV.\n  YAML: {ricostruite}\n  CSV:  {list(colonne)}"
        )

    anno = config["simulation"]["year"]
    n_ore = 8784 if calendar.isleap(anno) else 8760
    n_membri = len(righe)

    testa = [
        "# =============================================================================",
        "# BOZZA di scheda CER generata da generate_load_profiles.py",
        f"# Run del {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}   (marca {marca})",
        "#",
        "# Compilata con cio' che la pipeline sa: utenze, archetipi, percorsi, anno.",
        "# NON e' ancora caricabile. DA COMPILARE A MANO PRIMA DI ATTIVARLA:",
        "#",
        "#   [IMPIANTI]  vuota: la pipeline non conosce il fotovoltaico. Serve almeno",
        "#               una riga, altrimenti load_cer_input.m si ferma.",
        "#   [CER]       nome, comune, provincia, zona_mercato (nord|centro|sud)",
        "#   [MEMBRI]    ruolo P o E per chi possiede un impianto, e il suo id nella",
        "#               colonna 'impianto' (ora tutti C, nessun impianto)",
        "#   [RIEPILOGO] ricontare consumatori/prosumer/produttori_puri e la potenza",
        "#               installata dopo aver assegnato gli impianti",
        "#",
    ]
    if da_compilare:
        testa += [
            "#   [MEMBRI]    categoria, tariffa e P_prel_kW a '?' per gli archetipi",
            f"#               senza default: {', '.join(da_compilare)}",
            "#",
        ]
    testa += [
        "# PER ATTIVARLA: rinominare in CER_<C>_<P>_<E>.txt (consumatori, prosumer,",
        "#                produttori puri), stessa cartella. MAIN.m carica i soli file",
        "#                che iniziano per 'CER_', quindi finche' si chiama 'bozza_'",
        "#                questa scheda viene ignorata e non puo' rompere nulla.",
        "#",
        "# Le sezioni [MERCATO], [INVESTIMENTO] e [POVERTA_ENERGETICA] non stanno qui:",
        f"# le innesta il loader da {SCENARIO_ECONOMICO}. Dichiararle anche in questo",
        "# file fa fermare il caricamento per doppione.",
        "# =============================================================================",
    ]

    corpo = [
        "[CER]",
        "nome            = ?",
        "comune          = ?",
        "provincia       = ?",
        "zona_mercato    = ?",
        "cabina_primaria = ?",
        "forma_giuridica = ?",
        f"anno            = {anno}",
        f"n_ore           = {n_ore}",
        "[RIEPILOGO]",
        f"membri_totali             = {n_membri}",
        f"consumatori               = {n_membri}",
        "prosumer                  = 0",
        "produttori_puri           = 0",
        "penetrazione_prosumer_pct = 0.0",
        "potenza_installata_kWp    = ?",
        "impianti_totali           = ?",
        "[FILE]",
        f"profili_carico     = {_percorso_relativo(percorso_profili, cartella_schede)}",
        f"prezzi_zonali      = {PREZZI_ZONALI}",
        f"cartella_pv        = {CARTELLA_PV}",
        f"scenario_economico = {SCENARIO_ECONOMICO}",
        "[GOVERNANCE]",
    ]
    larghezza_gov = max(len(k) for k, _ in GOVERNANCE)
    corpo += [f"{k.ljust(larghezza_gov)} = {v}" for k, v in GOVERNANCE]

    corpo += ["[MEMBRI]"]
    corpo += _tabella(INTESTAZIONE_MEMBRI, righe)

    corpo += [
        "[IMPIANTI]",
        # Intestazione senza righe: e' l'unica sezione che il Python non puo'
        # compilare. L'esempio commentato si attiva togliendo il '#'.
        " | ".join(INTESTAZIONE_IMPIANTI),
        "# Esempio da completare (togliere il '#' e adattare):",
        "# PV01 | <nome_csv del proprietario> | <kWp> | <export_PVsyst>.CSV | ? | ? |"
        f" {anno} | ? | ?",
    ]

    nome_file = f"bozza_CER_{n_membri}_0_0_{marca}.txt"
    cartella_schede.mkdir(parents=True, exist_ok=True)
    percorso = cartella_schede / nome_file
    percorso.write_text("\n".join(testa + corpo) + "\n", encoding="utf-8")

    logger.info(
        "Bozza scheda CER: %s (%d membri, nessun impianto)", percorso, n_membri
    )
    return percorso
