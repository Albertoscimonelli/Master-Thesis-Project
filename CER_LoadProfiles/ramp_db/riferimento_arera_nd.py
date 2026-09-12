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

TRE LIMITI DA DICHIARARE IN TESI:

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

# Nomi di colonna dei CSV ARERA non domestici -> chiavi interne.
RINOMINA = {
    "anno": "anno",
    "mese": "mese",
    "regione": "regione",
    "provincia": "provincia",
    "tariffa potenza kw": "classe",
    "divisione ateco": "divisione",
    "gruppo ateco": "gruppo",
    "classe ateco": "ateco",
    "prelievo medio mensile": "kwh",
}

COLONNE_USATE = [
    "Anno", "Mese", "Regione", "Provincia", "Tariffa potenza kW",
    "Divisione ATECO", "Gruppo ATECO", "Classe ATECO", "Prelievo medio mensile",
]


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
    return {p.name: p for p in trovati}


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


def _normalizza(df: pd.DataFrame) -> pd.DataFrame:
    """Uniforma i nomi di colonna, ripulisce i valori testuali, estrae i codici.

    I valori testuali dei file ARERA hanno spazi in coda in modo non uniforme:
    senza lo strip un filtro su una provincia o su una classe restituisce zero
    righe in silenzio. E' la stessa trappola gia' nota sui file domestici.
    """
    df = df.copy()
    df.columns = [RINOMINA.get(c.strip().lower(), c.strip().lower())
                  for c in df.columns]
    for col in ("regione", "provincia", "classe"):
        df[col] = df[col].astype(str).str.strip()
    for col in ("divisione", "gruppo", "ateco"):
        df[col] = [_codice(v) for v in df[col]]
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
    manifesto = destinazione.with_suffix(".json")
    if not (destinazione.exists() and manifesto.exists()):
        return False
    atteso = json.loads(manifesto.read_text(encoding="utf-8"))
    if set(atteso) != set(sorgenti):
        return False
    return all(atteso[nome] == impronta(percorso)
               for nome, percorso in sorgenti.items())


def _scrivi_cache(destinazione: Path, df: pd.DataFrame,
                  sorgenti: dict[str, Path]) -> None:
    destinazione.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(destinazione, index=False)
    destinazione.with_suffix(".json").write_text(
        json.dumps({n: impronta(p) for n, p in sorgenti.items()}, indent=2),
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
        for nome, percorso in sorgenti.items():
            if verboso:
                print(f"    {nome}")
            d = pd.read_csv(percorso, sep=";", decimal=",", encoding="utf-8-sig",
                            usecols=COLONNE_USATE)
            d = _normalizza(d)
            d = d[d["provincia"] == provincia]
            if d.empty:
                sys.exit(f"Provincia '{provincia}' assente in {nome}.")
            righe.append(d[["anno", "mese", "classe", "divisione", "gruppo",
                            "ateco", "kwh"]])
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
                  anni: tuple[int, ...] = (2025,)) -> pd.Series:
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
                  anni: tuple[int, ...] = (2025,)) -> pd.DataFrame:
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
    print(f"{'file':34} {'righe':>9}  {'classe tariffaria'}")
    print("-" * 92)
    for nome, percorso in sorgenti.items():
        d = pd.read_csv(percorso, sep=";", decimal=",", encoding="utf-8-sig",
                        usecols=COLONNE_USATE)
        d = _normalizza(d)
        classi = sorted(d["classe"].unique())
        print(f"{nome:34} {len(d):>9,}  {' | '.join(classi)}")

    # L'ultimo file letto basta a descrivere la struttura: le colonne sono le
    # stesse in tutti e sette.
    print(f"\ncolonne: {', '.join(d.columns)}")
    print(f"anni:      {sorted(d['anno'].unique())}")
    print(f"mesi:      {sorted(d['mese'].unique())}")
    print(f"regioni:   {d['regione'].nunique()}")
    print(f"province:  {d['provincia'].nunique()}")
    print(f"divisioni ATECO: {d['divisione'].nunique()}   "
          f"gruppi: {d['gruppo'].nunique()}   classi: {d['ateco'].nunique()}")
    vuote = int(((d['ateco'] == '') & (d['divisione'] == '')).sum())
    print(f"righe con ATECO vuoto (aggregato di classe): {vuote:,}")


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

    print("\nIl dato ARERA non domestico e' mensile: la forma oraria non e'")
    print("validabile su questa fonte. La classe di potenza di un archetipo e'")
    print("un'assunzione dichiarata, non un dato: ARERA non pubblica il numero")
    print("di POD per classe e ATECO.")


if __name__ == "__main__":
    main()
