"""Livello di riferimento ARERA per la validazione dei profili NON domestici.

Gemello non domestico di `lpg_db/riferimento_arera.py`. Costruisce, a partire dai
file grezzi ARERA dei consumi provinciali per attivita' economica, il bersaglio
contro cui si valida il LIVELLO dei profili RAMP:

  - livello annuo    consumo medio annuo per POD, in kWh, per ATECO e classe;
  - forma mensile    quota di ciascun mese sul totale annuo;
  - rumore di fonte  quanto cambia il riferimento da un anno all'altro.

DOVE FINISCE QUESTO MODULO E DOVE COMINCIA L'ALTRO. I dati ARERA non domestici
sono **solo mensili**: non esiste una traccia oraria come quella dei domestici
trattati orari. La forma oraria viene percio' da una fonte diversa, i profili
standard GSE, in `riferimento_gse_nd.py`. La divisione dei compiti e' quella gia'
dichiarata in CONTESTO_LPG_RAMP.md §9 punto 4:

    livello e stagionalita' mensile -> ARERA per ATECO e classe di potenza
    forma oraria dentro il mese     -> profili standard GSE

FONTE DEI DATI. Portale ARERA, dati di consumo provinciali per i clienti non
domestici in bassa tensione ("Dati provincia", parti 1-3, anno 2025), file CSV
uno per classe tariffaria BTA. Ogni riga e' il prelievo medio mensile per punto
di prelievo di una terna (provincia, classe di potenza, classe ATECO). I file
stanno sotto `CER_LoadProfiles/File Non Domestici/`, non versionati per
dimensione (vedi .gitignore); quello che si versiona e' la cache in
`ramp_db/dati/riferimento_arera_nd/`, con accanto lo SHA-256 di ogni sorgente.

DIFFERENZE DI FORMATO RISPETTO AL LATO DOMESTICO, tutte verificate sui file:

  1. Sono CSV, non xlsx: separatore ';', virgola decimale, BOM UTF-8.
  2. Non c'e' la riga di riepilogo annuale che sul lato domestico si nasconde
     nel campo 'Anno Mese': qui 'Anno' e 'Mese' sono due colonne distinte e i
     mesi vanno da 1 a 12 senza totali intrusi.
  3. Esiste pero' una riga con i campi ATECO VUOTI: e' l'aggregato che ARERA
     stessa pubblica per l'intera classe di potenza. Non va sommata alle altre
     (raddoppierebbe i totali) ma e' il valore corretto da usare quando si
     vuole "tutti gli ATECO insieme": si ottiene con ateco=None.
  4. La classe BTA3 compare in DUE file, con due sottofasce diverse
     (3-4,5 kW e 4,5-6 kW). Sono trattate come due classi distinte.

LE DUE ANNUALITA' NON HANNO LO STESSO FORMATO, e nemmeno la stessa copertura:

  5. Nomi di colonna diversi per gli stessi campi ('Tariffa potenza kW' nel
     2025, 'TARIFFA_POTENZA_KW' nel 2024; 'Prelievo medio mensile' contro
     'Prelievo medio (kWh)'), il 2024 non ha la colonna 'Regione' e ripete due
     volte la colonna 'Anno'. Le ETICHETTE DI CLASSE sono invece identiche
     ("BTA1: 0 <>= 1,5" ...), il che rende le due annualita' confrontabili.
  6. Numeri scritti in modo diverso: il 2025 usa la virgola decimale con molte
     cifre (15,82709464), il 2024 valori interi con il punto come separatore
     delle migliaia (17.655 vale 17655). Letti con la sola convenzione del
     2025 i valori del 2024 restano stringhe e ogni media fallisce.
  7. Il mese e' un numero nel 2025 e un'abbreviazione nel 2024 ('Gen' ...
     'Sett' con due t, che non e' l'abbreviazione di nessuna libreria).
  8. Lo zip provinciale 2024 contiene DUE COPPIE di file byte-identici
     (BTA5 e BTA6, pubblicati due volte con nomi diversi): vanno deduplicati
     per contenuto, o le loro righe verrebbero contate due volte.

QUATTRO LIMITI DA DICHIARARE IN TESI:

  0. La pubblicazione provinciale 2024 copre le sole DODICI PROVINCE LOMBARDE
     (Bergamo, Brescia, Como, Cremona, Lecco, Lodi, Mantova, Milano, Monza e
     della Brianza, Pavia, Sondrio, Varese), mentre il 2025 copre tutte le 110
     province italiane. Milano c'e' in entrambe, quindi il rumore di fonte fra
     due anni resta calcolabile per la CER di questo progetto; per una
     provincia fuori dalla Lombardia esiste il solo 2025, e rumore_fonte() lo
     dice invece di restituire un numero costruito su un anno solo.
  1. Il dato e' mensile: la forma oraria non e' validabile su questa fonte.
  2. ARERA non pubblica il NUMERO di POD per classe e ATECO. Non si puo' quindi
     costruire una media pesata fra classi di potenza, ne' verificare a quale
     classe appartenga davvero una data utenza: la classe di confronto resta
     un'assunzione dichiarata, e per questo si riporta anche la classe
     adiacente (ADIACENTI).
  3. L'elenco delle province ARERA non coincide con quello ISTAT corrente:
     compaiono entita' sarde pre-riforma (es. "Sulcis Iglesiente") e la Valle
     d'Aosta come provincia. Il confronto e' per uguaglianza esatta del nome,
     come sul lato domestico.

Uso:
    python riferimento_arera_nd.py --ispeziona
    python riferimento_arera_nd.py Milano --ateco 82.11
    python riferimento_arera_nd.py Milano --ateco 82.11 --classe BTA4 --anni 2025
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from pathlib import Path

import pandas as pd

# Radice dei dati esterni. Sovrascrivibile con CER_DATI_ESTERNI, cosi' lo script
# resta valido se la cartella viene spostata. Il default punta alla cartella del
# progetto, dove i file sono stati scaricati.
RADICE_PREDEFINITA = Path(__file__).resolve().parents[1] / "File Non Domestici"

QUI = Path(__file__).resolve().parent
CACHE = QUI / "dati" / "riferimento_arera_nd"

# Versione della logica di lettura. VA INCREMENTATA a ogni modifica del modo in
# cui i file grezzi vengono interpretati (nomi di colonna, formato dei numeri,
# codifica dei mesi, deduplicazione dei sorgenti): finisce nel manifesto della
# cache e la invalida. Senza, una cache scritta da un parser sbagliato resta
# valida per sempre, perche' i sorgenti da cui deriva non sono cambiati.
VERSIONE_PARSER = 2

# Le classi tariffarie come ARERA le scrive nella colonna 'Tariffa potenza kW'.
# Sono la chiave canonica: gli alias servono solo alla riga di comando. BTA3
# compare due volte perche' ARERA pubblica separatamente le due sottofasce.
CLASSI = [
    "BTA1: 0 <>= 1,5",
    "BTA2: 1,5 <>= 3",
    "BTA3: 3 <>= 4,5",
    "BTA3: 4,5 <>= 6",
    "BTA4: 6 <>= 10",
    "BTA5: >10",
    "BTA6: potenza disponibile >16,5",
]

ALIAS_CLASSI = {
    "BTA1": CLASSI[0], "0-1.5": CLASSI[0],
    "BTA2": CLASSI[1], "1.5-3": CLASSI[1],
    "BTA3a": CLASSI[2], "3-4.5": CLASSI[2],
    "BTA3b": CLASSI[3], "4.5-6": CLASSI[3],
    "BTA4": CLASSI[4], "6-10": CLASSI[4],
    "BTA5": CLASSI[5], "10-16.5": CLASSI[5],
    "BTA6": CLASSI[6], ">16.5": CLASSI[6],
}

# Sigla breve di ogni classe, per le stampe.
SIGLA = {
    CLASSI[0]: "BTA1", CLASSI[1]: "BTA2", CLASSI[2]: "BTA3a", CLASSI[3]: "BTA3b",
    CLASSI[4]: "BTA4", CLASSI[5]: "BTA5", CLASSI[6]: "BTA6",
}

# Classe immediatamente superiore, da riportare accanto a quella scelta: la
# classe di un archetipo e' un'assunzione, non un dato.
ADIACENTI = {
    CLASSI[0]: CLASSI[1], CLASSI[1]: CLASSI[2], CLASSI[2]: CLASSI[3],
    CLASSI[3]: CLASSI[4], CLASSI[4]: CLASSI[5], CLASSI[5]: CLASSI[6],
    CLASSI[6]: CLASSI[5],
}

# Nomi di colonna dei CSV ARERA non domestici -> chiavi interne. Le due
# annualita' scrivono gli stessi campi con nomi diversi, e il 2024 non ha
# affatto la regione: la mappa copre entrambe le forme.
RINOMINA = {
    "anno": "anno",
    "mese": "mese",
    "regione": "regione",
    "provincia": "provincia",
    "tariffa potenza kw": "classe",       # 2025
    "tariffa_potenza_kw": "classe",       # 2024
    "divisione ateco": "divisione",
    "gruppo ateco": "gruppo",
    "classe ateco": "ateco",
    "prelievo medio mensile": "kwh",      # 2025
    "prelievo medio (kwh)": "kwh",        # 2024
}

# Le sole colonne che sopravvivono alla normalizzazione. Tenere una lista
# esplicita rende innocue le colonne che cambiano da un anno all'altro.
COLONNE_INTERNE = ["anno", "mese", "classe", "divisione", "gruppo", "ateco", "kwh"]

# Il 2024 scrive il mese come abbreviazione italiana invece che come numero.
# "Sett" ha due t e non e' l'abbreviazione usata da nessuna libreria standard:
# va mappata a mano o settembre sparisce in silenzio.
MESI = {"gen": 1, "feb": 2, "mar": 3, "apr": 4, "mag": 5, "giu": 6,
        "lug": 7, "ago": 8, "set": 9, "sett": 9, "ott": 10, "nov": 11, "dic": 12}


def radice() -> Path:
    """Cartella che contiene i file ARERA non domestici scaricati."""
    percorso = Path(os.environ.get("CER_DATI_ESTERNI", RADICE_PREDEFINITA))
    if not percorso.is_dir():
        sys.exit(
            f"Cartella dei dati esterni non trovata: {percorso}\n"
            f"Impostare la variabile d'ambiente CER_DATI_ESTERNI."
        )
    return percorso


def impronta(percorso: Path) -> str:
    """SHA-256 di un file, per invalidare la cache quando la sorgente cambia."""
    h = hashlib.sha256()
    with percorso.open("rb") as f:
        for blocco in iter(lambda: f.read(1 << 20), b""):
            h.update(blocco)
    return h.hexdigest()


def file_sorgenti() -> dict[str, Path]:
    """I CSV ARERA non domestici, cercati per nome ovunque sotto la radice.

    I file stanno in sottocartelle con nomi irregolari ("Dati_provincia_2025_-_
    Parte_1/Dati provincia 2025 - Parte 1/"): cercare per schema di nome invece
    che per percorso rende lo script immune alla riorganizzazione della
    cartella, come gia' fa il lato domestico.
    """
    trovati = sorted(radice().glob("**/BTA*.csv"))
    if not trovati:
        sys.exit(
            f"Nessun CSV ARERA non domestico (BTA*.csv) trovato sotto {radice()}.\n"
            f"Eseguire prima: python riferimento_arera_nd.py --ispeziona"
        )
    # Lo zip provinciale 2024 pubblicato da ARERA contiene DUE COPPIE di file
    # identici ("BTA5 potenza maggiore da 10" e "...di 0"; "BTA6 ... maggiore
    # 16_5" e "..._16_5"), con lo stesso SHA-256. Leggerli tutti conterebbe due
    # volte le stesse righe. Si deduplica per contenuto e non per nome, cosi' la
    # guardia regge anche se un domani la coppia venisse rinominata. La chiave
    # e' il percorso relativo alla radice, perche' due annualita' diverse
    # possono contenere file omonimi.
    unici: dict[str, Path] = {}
    viste: set[str] = set()
    for percorso in trovati:
        firma = impronta(percorso)
        if firma in viste:
            continue
        viste.add(firma)
        unici[str(percorso.relative_to(radice()))] = percorso
    return unici


def _codice(valore: object) -> str:
    """Estrae il codice da un campo ATECO 'codice  descrizione'.

    ARERA scrive '82.11  Attivita di ...' e '1 PRODUZIONI VEGETALI ...': il
    codice e' sempre il primo token. Le divisioni sotto 10 non hanno lo zero
    iniziale ('1', non '01'), per questo le interrogazioni vengono normalizzate
    in _normalizza_ateco().
    """
    testo = str(valore).strip()
    if not testo or testo.lower() == "nan":
        return ""
    return testo.split()[0]


def _normalizza_ateco(codice: str) -> str:
    """Toglie gli zeri iniziali dalla parte di divisione, come li scrive ARERA."""
    testo = str(codice).strip()
    if "." in testo:
        testa, coda = testo.split(".", 1)
        return f"{testa.lstrip('0') or '0'}.{coda}"
    return testo.lstrip("0") or "0"


def _mese(valore: object) -> int:
    """Numero del mese, sia che il file lo scriva come 1-12 sia come 'Gen'."""
    testo = str(valore).strip().lower()
    if testo.isdigit():
        return int(testo)
    if testo not in MESI:
        sys.exit(f"Mese non riconosciuto nei file ARERA: '{valore}'.")
    return MESI[testo]


def _numero(serie: pd.Series) -> pd.Series:
    """Converte i valori numerici scritti all'italiana, in entrambe le forme.

    Il 2025 scrive la virgola decimale (15,82709464), il 2024 il punto come
    separatore delle migliaia su valori interi (17.655 vale 17655). Togliere i
    punti e poi portare la virgola a punto copre entrambi i casi, ed e' corretto
    anche sulla forma mista 1.234,56 che i due file non usano ma che la
    convenzione italiana ammette.
    """
    testo = serie.astype(str).str.strip()
    testo = testo.str.replace(".", "", regex=False).str.replace(",", ".", regex=False)
    return pd.to_numeric(testo, errors="coerce")


def _normalizza(df: pd.DataFrame) -> pd.DataFrame:
    """Uniforma i nomi di colonna, ripulisce i valori testuali, estrae i codici.

    I valori testuali dei file ARERA hanno spazi in coda in modo non uniforme:
    senza lo strip un filtro su una provincia o su una classe restituisce zero
    righe in silenzio. E' la stessa trappola gia' nota sui file domestici.

    Il file 2024 ripete inoltre la colonna 'Anno' due volte (pandas rinomina la
    seconda 'Anno.1'): le duplicate si scartano subito, perche' in uscita si
    tengono comunque le sole COLONNE_INTERNE.
    """
    df = df.copy()
    df.columns = [RINOMINA.get(c.strip().lower(), c.strip().lower())
                  for c in df.columns]
    df = df.loc[:, ~df.columns.duplicated()]
    for col in ("provincia", "classe"):
        df[col] = df[col].astype(str).str.strip()
    for col in ("divisione", "gruppo", "ateco"):
        df[col] = [_codice(v) for v in df[col]]
    df["mese"] = [_mese(v) for v in df["mese"]]
    df["anno"] = df["anno"].astype(int)
    df["kwh"] = _numero(df["kwh"])
    return df


# ---------------------------------------------------------------------------
# Estrazione con cache
#
# I sette CSV sommano circa 2,5 milioni di righe: una lettura completa richiede
# qualche decina di secondi. La cache tiene il sottoinsieme di una provincia ed
# e' legata all'impronta dei sorgenti, quindi un file riscaricato la invalida da
# solo. Si versiona: senza, la validazione non sarebbe rieseguibile da chi clona
# il progetto, che i 692 MB di sorgenti non li ha.
# ---------------------------------------------------------------------------

def _cache_valida(destinazione: Path, sorgenti: dict[str, Path]) -> bool:
    """Vera se la cache e' stata scritta dalle stesse sorgenti E dallo stesso parser.

    La seconda condizione non e' teorica: durante lo sviluppo una cache scritta
    quando il punto delle migliaia del file 2024 veniva ancora letto come
    separatore decimale e' sopravvissuta alla correzione del parser - gli
    SHA-256 delle sorgenti non erano cambiati, quindi la cache risultava valida
    e il livello annuo 2024 restava mille volte piu' piccolo del vero. Una cache
    legata alla sola impronta dei sorgenti rende silenziosi proprio gli errori
    di lettura.
    """
    manifesto = destinazione.with_suffix(".json")
    if not (destinazione.exists() and manifesto.exists()):
        return False
    atteso = json.loads(manifesto.read_text(encoding="utf-8"))
    if atteso.get("versione_parser") != VERSIONE_PARSER:
        return False
    firme = atteso.get("sorgenti", {})
    if set(firme) != set(sorgenti):
        return False
    return all(firme[nome] == impronta(percorso)
               for nome, percorso in sorgenti.items())


def _scrivi_cache(destinazione: Path, df: pd.DataFrame,
                  sorgenti: dict[str, Path]) -> None:
    destinazione.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(destinazione, index=False)
    destinazione.with_suffix(".json").write_text(
        json.dumps({"versione_parser": VERSIONE_PARSER,
                    "sorgenti": {n: impronta(p) for n, p in sorgenti.items()}},
                   indent=2),
        encoding="utf-8",
    )


_memoria: dict[str, pd.DataFrame] = {}


def mensili(provincia: str, verboso: bool = True) -> pd.DataFrame:
    """Tutti i prelievi medi mensili ARERA di una provincia, in forma lunga.

    Args:
        provincia: nome come compare nei file ARERA, es. "Milano".
        verboso: stampa l'avanzamento della lettura a cache fredda.

    Returns:
        DataFrame con colonne anno, mese, classe, divisione, gruppo, ateco, kwh.
        La riga con i campi ATECO vuoti e' l'aggregato ARERA della classe e
        viene conservata: e' il valore corretto per "tutti gli ATECO insieme".
    """
    if provincia in _memoria:
        return _memoria[provincia]

    destinazione = CACHE / f"mensili_{provincia}.csv"
    sorgenti = file_sorgenti()
    if _cache_valida(destinazione, sorgenti):
        risultato = pd.read_csv(destinazione,
                                dtype={"divisione": str, "gruppo": str, "ateco": str},
                                keep_default_na=False, na_values=[""])
    else:
        if verboso:
            print(f"  lettura dei CSV ARERA non domestici "
                  f"(a cache fredda richiede qualche decina di secondi)...")
        righe = []
        assenti = []
        for nome, percorso in sorgenti.items():
            if verboso:
                print(f"    {nome}")
            d = pd.read_csv(percorso, sep=";", encoding="utf-8-sig", dtype=str)
            d = _normalizza(d)
            d = d[d["provincia"] == provincia]
            if d.empty:
                # Non e' un errore: la pubblicazione provinciale 2024 copre le
                # sole province lombarde, quindi per ogni altra provincia
                # quell'annualita' semplicemente non esiste. Fermarsi qui
                # renderebbe inutilizzabile anche l'anno che c'e'.
                assenti.append(nome)
                continue
            righe.append(d[COLONNE_INTERNE])
        if not righe:
            sys.exit(f"Provincia '{provincia}' assente in tutti i file ARERA "
                     f"sotto {radice()}.")
        if assenti and verboso:
            print(f"    provincia assente in {len(assenti)} file su "
                  f"{len(sorgenti)}: quelle annualita' non la coprono")
        risultato = pd.concat(righe, ignore_index=True)
        _scrivi_cache(destinazione, risultato, sorgenti)

    _memoria[provincia] = risultato
    return risultato


# ---------------------------------------------------------------------------
# Interfaccia di alto livello
# ---------------------------------------------------------------------------

def risolvi_classe(nome: str) -> str:
    """Accetta sia la stringa ARERA completa sia un alias breve (BTA4, 6-10)."""
    if nome in CLASSI:
        return nome
    if nome in ALIAS_CLASSI:
        return ALIAS_CLASSI[nome]
    sys.exit(
        f"Classe di potenza non riconosciuta: '{nome}'.\n"
        f"Alias ammessi: {', '.join(sorted(ALIAS_CLASSI))}"
    )


def anni_disponibili(provincia: str = "Milano") -> list[int]:
    """Anni presenti nei file scaricati. Serve a non promettere piu' di quanto c'e'."""
    return sorted(int(a) for a in mensili(provincia, verboso=False)["anno"].unique())


def _seleziona(provincia: str, ateco: str | None, classe: str,
               anni: tuple[int, ...]) -> pd.DataFrame:
    """Righe mensili di una terna (ATECO, classe, anni).

    Con ateco=None si usa la riga aggregata pubblicata da ARERA per l'intera
    classe di potenza. E' l'unico modo corretto di ottenere "tutti gli ATECO":
    mediare a mano le righe per ATECO darebbe una media non pesata, perche' il
    numero di POD per ATECO non e' pubblicato.
    """
    classe = risolvi_classe(classe)
    d = mensili(provincia)
    d = d[(d["classe"] == classe) & (d["anno"].isin(anni))]

    if ateco is None:
        d = d[(d["ateco"].fillna("") == "") & (d["divisione"].fillna("") == "")]
        etichetta = "aggregato ARERA di classe"
    else:
        codice = _normalizza_ateco(ateco)
        livello = {0: "divisione", 1: "gruppo", 2: "ateco"}[
            len(codice.split(".")[1]) if "." in codice else 0]
        d = d[d[livello] == codice]
        etichetta = f"{livello} {codice}"

    if d.empty:
        sys.exit(f"Nessun dato ARERA per {provincia} / {SIGLA.get(classe, classe)} "
                 f"/ {etichetta} / anni {anni}.")
    return d


def livello_annuo(provincia: str, ateco: str | None, classe: str,
                  anni: tuple[int, ...] = (2024, 2025)) -> pd.Series:
    """Consumo medio annuo per POD, in kWh, per anno.

    Si somma il dettaglio mensile: se un mese mancasse, il totale annuo sarebbe
    parziale e la somma lo rende evidente invece di nasconderlo.

    Nota: quando l'interrogazione seleziona piu' righe ATECO (es. una divisione
    intera) i valori vengono MEDIATI, non sommati, perche' ogni riga e' un
    prelievo medio per POD e non un totale. La media non e' pesata sul numero di
    POD, che ARERA non pubblica: e' un'approssimazione da dichiarare.
    """
    d = _seleziona(provincia, ateco, classe, anni)
    per_mese = d.groupby(["anno", "mese"])["kwh"].mean()
    conteggio = per_mese.groupby("anno").size()
    parziali = conteggio[conteggio != 12]
    if not parziali.empty:
        print(f"Attenzione: mesi mancanti negli anni {dict(parziali)} - "
              f"il totale annuo e' parziale.")
    return per_mese.groupby("anno").sum()


def forma_mensile(provincia: str, ateco: str | None, classe: str,
                  anni: tuple[int, ...] = (2024, 2025)) -> pd.DataFrame:
    """Quota di ciascun mese sul totale annuo, per anno. Somma 1 per riga.

    E' la metrica di testa della validazione non domestica: e' l'unica che vede
    la chiusura estiva di una scuola o l'agosto piatto di un ufficio. I profili
    GSE non possono fornirla, perche' sono normalizzati DENTRO ciascun mese.
    """
    d = _seleziona(provincia, ateco, classe, anni)
    tabella = d.pivot_table(index="anno", columns="mese", values="kwh", aggfunc="mean")
    return tabella.div(tabella.sum(axis=1), axis=0)


def rumore_fonte(provincia: str, ateco: str | None, classe: str,
                 anni: tuple[int, int] = (2024, 2025)) -> dict:
    """Quanto cambia il riferimento da un anno all'altro: la soglia di validita'.

    A comportamento della popolazione presumibilmente stabile, lo scarto fra due
    anni consecutivi della stessa fonte misura il rumore irriducibile del
    riferimento. Uno scarto RAMP-ARERA dello stesso ordine significa che il
    livello generato e' indistinguibile dal riferimento.

    Raises:
        SystemExit: se i due anni non sono entrambi presenti nei file. Meglio
            fermarsi che restituire un numero calcolato su un anno solo, che
            sarebbe zero per costruzione e verrebbe scambiato per una soglia
            severissima. Ad oggi sono stati scaricati i soli dati 2025.
    """
    if len(anni) != 2:
        sys.exit("rumore_fonte confronta esattamente due anni.")
    disponibili = anni_disponibili(provincia)
    mancanti = [a for a in anni if a not in disponibili]
    if mancanti:
        sys.exit(
            f"Anni non disponibili nei file scaricati: {mancanti} "
            f"(presenti: {disponibili}).\n"
            f"Il rumore di fonte sul LIVELLO richiede due annualita' ARERA: "
            f"scaricare l'anno mancante dal portale ARERA, oppure usare il "
            f"rumore di fonte sulla FORMA, che riferimento_gse_nd.py calcola "
            f"gia' fra i profili GSE 2024 e 2025."
        )
    a, b = anni

    liv = livello_annuo(provincia, ateco, classe, anni)
    mens = forma_mensile(provincia, ateco, classe, anni)
    return {
        "scarto_livello_pct": float((liv[b] - liv[a]) / liv[a] * 100),
        "l1_mensile": float((mens.loc[a] - mens.loc[b]).abs().sum()),
    }


# ---------------------------------------------------------------------------
# Ispezione della cartella
# ---------------------------------------------------------------------------

def ispeziona() -> None:
    """Stampa cosa c'e' davvero nei file, prima di fidarsi del parser.

    Serve a chi riscarica i dati: se ARERA cambia nomi di colonna, etichette di
    classe o profondita' ATECO, questo comando lo rende visibile subito invece
    di lasciarlo scoprire da un filtro che restituisce zero righe.
    """
    sorgenti = file_sorgenti()
    print(f"\nISPEZIONE DEI FILE ARERA NON DOMESTICI\nradice: {radice()}\n")
    print(f"{'file':48} {'righe':>9}  {'anni':8} {'classe tariffaria'}")
    print("-" * 110)
    per_anno: dict[int, dict] = {}
    for nome, percorso in sorgenti.items():
        d = pd.read_csv(percorso, sep=";", encoding="utf-8-sig", dtype=str)
        d = _normalizza(d)
        classi = sorted(d["classe"].unique())
        anni = sorted(d["anno"].unique())
        print(f"{percorso.name:48} {len(d):>9,}  {str(anni):8} {' | '.join(classi)}")
        for anno in anni:
            parte = d[d["anno"] == anno]
            voce = per_anno.setdefault(anno, {"righe": 0, "province": set(),
                                              "mesi": set(), "ateco": set(),
                                              "vuote": 0, "colonne": list(d.columns)})
            voce["righe"] += len(parte)
            voce["province"] |= set(parte["provincia"])
            voce["mesi"] |= set(parte["mese"])
            voce["ateco"] |= set(parte["ateco"])
            voce["vuote"] += int(((parte["ateco"] == "")
                                  & (parte["divisione"] == "")).sum())

    # Il riepilogo va tenuto per anno: le due annualita' non hanno ne' le stesse
    # colonne ne' la stessa copertura provinciale, e un riepilogo unico le
    # confonderebbe proprio sul punto che conta.
    for anno in sorted(per_anno):
        v = per_anno[anno]
        print(f"\n--- {anno} ---")
        print(f"  colonne:   {', '.join(v['colonne'])}")
        print(f"  righe:     {v['righe']:,}")
        print(f"  mesi:      {sorted(v['mesi'])}")
        print(f"  province:  {len(v['province'])}"
              + ("" if len(v["province"]) > 20
                 else f"  {sorted(v['province'])}"))
        print(f"  classi ATECO: {len(v['ateco'])}")
        print(f"  righe con ATECO vuoto (aggregato di classe): {v['vuote']:,}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("provincia", nargs="?", default=None,
                        help="nome ARERA della provincia, es. Milano")
    parser.add_argument("--ateco", default=None,
                        help="codice ATECO: divisione (82), gruppo (82.1) o "
                             "classe (82.11). Se assente usa l'aggregato ARERA "
                             "di classe di potenza")
    parser.add_argument("--classe", default=None,
                        help="alias BTA o stringa ARERA; se assente le stampa tutte")
    parser.add_argument("--anni", type=int, nargs="+", default=None,
                        help="anni da includere; se assente usa quelli presenti")
    parser.add_argument("--ispeziona", action="store_true",
                        help="stampa la struttura dei file e termina")
    args = parser.parse_args()

    if args.ispeziona:
        ispeziona()
        return

    if args.provincia is None:
        parser.error("indicare la provincia, oppure usare --ispeziona")

    mensili(args.provincia)   # popola la cache prima di stampare
    anni = tuple(args.anni) if args.anni else tuple(anni_disponibili(args.provincia))
    classi = [risolvi_classe(args.classe)] if args.classe else CLASSI
    etichetta = f"ATECO {args.ateco}" if args.ateco else "aggregato di classe"

    print(f"\nRIFERIMENTO ARERA NON DOMESTICO - {args.provincia}, {etichetta}, "
          f"anni {' e '.join(map(str, anni))}\n")

    print(f"{'classe':30} {'kWh/anno per POD':>18}   quota mensile min -> max")
    print("-" * 92)
    for classe in classi:
        try:
            liv = livello_annuo(args.provincia, args.ateco, classe, anni)
            mens = forma_mensile(args.provincia, args.ateco, classe, anni)
        except SystemExit:
            print(f"{SIGLA[classe]:30} {'(nessun dato)':>18}")
            continue
        media = mens.mean(axis=0)
        print(f"{SIGLA[classe] + ' ' + classe.split(':')[1].strip():30} "
              f"{liv.mean():>18,.0f}   "
              f"mese {int(media.idxmin()):02d} {media.min() * 100:.1f}%  ->  "
              f"mese {int(media.idxmax()):02d} {media.max() * 100:.1f}%")

    if len(anni) < 2:
        print(f"\nUn solo anno disponibile ({anni[0]}): il rumore di fonte sul "
              f"livello non e'\ncalcolabile. Serve una seconda annualita' ARERA. "
              f"Il rumore di fonte sulla\nforma oraria e' invece gia' calcolabile "
              f"fra i profili GSE 2024 e 2025\n(riferimento_gse_nd.py).")
    else:
        print(f"\nRUMORE DELLA FONTE fra {anni[0]} e {anni[-1]} "
              f"- e' la soglia di accettazione sul livello\n")
        print(f"{'classe':30} {'scarto livello':>16} {'L1 forma mensile':>18}")
        print("-" * 92)
        for classe in classi:
            try:
                r = rumore_fonte(args.provincia, args.ateco, classe,
                                 (anni[0], anni[-1]))
            except SystemExit:
                print(f"{SIGLA[classe]:30} {'(nessun dato)':>16}")
                continue
            print(f"{SIGLA[classe]:30} {r['scarto_livello_pct']:>15.1f}% "
                  f"{r['l1_mensile']:>18.4f}")

    print("\nIl dato ARERA non domestico e' mensile: la forma oraria non e'")
    print("validabile su questa fonte. La classe di potenza di un archetipo e'")
    print("un'assunzione dichiarata, non un dato: ARERA non pubblica il numero")
    print("di POD per classe e ATECO.")


if __name__ == "__main__":
    main()
