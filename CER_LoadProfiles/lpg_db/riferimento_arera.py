"""Curve di riferimento ARERA per la validazione dei profili domestici.

Costruisce, a partire dai file grezzi scaricati dal portale ARERA *Analisi dei
consumi dei clienti domestici*, le curve contro cui si valida l'output di LPG:

  - forma oraria     24 valori per tipo di giorno, per mese e per anno intero;
  - livello          consumo medio annuo in kWh, per classe di potenza;
  - fasce            ripartizione F1 / F2 / F3 dichiarata da ARERA;
  - rumore di fonte  quanto cambiano le curve reali da un anno all'altro.

PERCHE' DAI FILE GREZZI. Le curve usate nelle sessioni precedenti venivano da
estratti CSV costruiti a mano, che non esistono piu'. Un riferimento di
validazione che dipende da un file intermedio non ricostruibile non e'
riproducibile, quindi non e' un riferimento. Qui si parte sempre dagli xlsx
originali e si tiene traccia della loro impronta.

IL RUMORE DI FONTE E' LA SOGLIA. Non esiste una soglia di validazione
oggettiva: dire "TVD < 0,05 quindi validato" sarebbe arbitrario. Si usa invece
la variabilita' della fonte stessa fra due anni consecutivi, a comportamento
della popolazione presumibilmente stabile. Se lo scarto LPG-ARERA e' dello
stesso ordine, la forma generata e' indistinguibile dal rumore del riferimento.
E' una scelta metodologica di questo lavoro, non uno standard di letteratura, e
va dichiarata come tale.

DUE AVVERTENZE SUL DATO ARERA, da riportare in tesi:

  1. I dati ORARI riguardano i soli clienti "trattati orari", cioe' quelli con
     misuratore telegestito effettivamente letto ora per ora. E' un
     sottoinsieme della popolazione domestica, di cui non abbiamo modo di
     verificare la rappresentativita'.
  2. Nessun file ARERA contiene il NUMERO di clienti per classe di potenza e
     provincia. Non e' quindi possibile costruire una media pesata fra classi,
     ne' verificare a quale classe appartenga davvero una data utenza: la
     classe di confronto resta un'assunzione dichiarata.

Uso:
    python riferimento_arera.py Milano
    python riferimento_arera.py Milano --classe 1.5-3 --anni 2024 2025
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from pathlib import Path

import pandas as pd

# Radice dei dati esterni. Sovrascrivibile con la variabile d'ambiente
# CER_DATI_ESTERNI, cosi' lo script resta valido se la cartella viene spostata.
RADICE_PREDEFINITA = Path.home() / "Downloads" / "File Utili per profili"

QUI = Path(__file__).resolve().parent
CACHE = QUI / "dati" / "riferimento_arera"

# Le classi di potenza come ARERA le scrive nei file. Sono la chiave canonica:
# gli alias servono solo a rendere leggibile la riga di comando.
CLASSI = [
    "0<potenza_impegnata<=1.5",
    "1.5<potenza_impegnata<=3",
    "3<potenza_impegnata<=4.5",
    "4.5<potenza_impegnata<=6",
    "potenza_impegnata>6",
]

ALIAS_CLASSI = {
    "0-1.5": CLASSI[0], "0_a_1_5": CLASSI[0],
    "1.5-3": CLASSI[1], "1_5_a_3": CLASSI[1],
    "3-4.5": CLASSI[2], "3_a_4_5": CLASSI[2],
    "4.5-6": CLASSI[3], "4_5_a_6": CLASSI[3],
    ">6": CLASSI[4], "potenza6": CLASSI[4],
}

# Frammento che compare nel nome del file orario, per ciascuna classe.
FRAMMENTO_FILE = {
    CLASSI[0]: "0_a_1_5",
    CLASSI[1]: "1_5_a_3",
    CLASSI[2]: "3_a_4_5",
    CLASSI[3]: "4_5_a_6",
    CLASSI[4]: "potenza6",
}

GIORNI = ["Giorno feriale", "Sabato", "Domenica"]

# I due tracciati ARERA usano nomi di colonna diversi per gli stessi campi
# ("Tipo mercato" nell'orario, "Tipo Mercato " nel mensile) e alcuni hanno
# spazi in coda. Si normalizza tutto su queste chiavi.
RINOMINA = {
    "anno mese": "periodo",
    "provincia": "provincia",
    "tipo mercato": "mercato",
    "classe_potenza": "classe",
    "classe potenza": "classe",
    "residenza": "residenza",
    "working day": "giorno",
    "orario": "ora",
    "prelievo medio orario provinciale (kwh)": "kwh",
    "medio consumo mensile": "kwh",
    "f1(%)": "f1",
    "f2(%)": "f2",
    "f3(%)": "f3",
}


def radice() -> Path:
    """Cartella che contiene i file ARERA scaricati."""
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


def _normalizza(df: pd.DataFrame) -> pd.DataFrame:
    """Uniforma i nomi di colonna e ripulisce i valori testuali.

    I file ARERA hanno spazi in coda ai nomi di colonna e ai valori, in modo
    non uniforme fra tracciato orario e mensile. Senza questa normalizzazione
    un filtro su 'Residente' fallisce silenziosamente restituendo zero righe.
    """
    df = df.copy()
    df.columns = [RINOMINA.get(c.strip().lower(), c.strip().lower())
                  for c in df.columns]
    for col in df.columns:
        if df[col].dtype == object:
            df[col] = df[col].astype(str).str.strip()
    return df


def _periodo(valore: str) -> str:
    """Riduce il campo 'Anno Mese' a 'anno' oppure al numero del mese.

    Il campo contiene sia le 12 righe mensili (come data) sia una riga di
    sintesi annuale (come stringa di quattro cifre). Confonderle raddoppia
    silenziosamente i totali: e' l'errore piu' facile su questi file.
    """
    testo = str(valore).strip()
    if len(testo) == 4 and testo.isdigit():
        return "anno"
    return f"{pd.to_datetime(testo).month:02d}"


def _trova(schema: str) -> Path:
    """Individua un file ARERA per frammento di nome, ovunque sia nella radice.

    La cartella dei dati e' stata riorganizzata piu' volte e i file stanno in
    sottocartelle 'Parte I ... Parte VI' con annidamenti diversi fra un anno e
    l'altro. Cercare per nome invece che per percorso rende lo script immune.
    """
    trovati = sorted(radice().glob(f"**/{schema}"))
    if not trovati:
        sys.exit(f"File ARERA non trovato: {schema}\n  cercato sotto {radice()}")
    return trovati[0]


def _file_orario(anno: int, classe: str) -> Path:
    """Percorso del file orario 'tutti i mercati' per anno e classe.

    Si usano sempre i file TOT (Tipo mercato = 'Tutti') e mai i 'mkt', che
    scompongono per tipo di mercato: la scomposizione non serve alla
    validazione e moltiplicherebbe le righe.
    """
    frammento = FRAMMENTO_FILE[classe]
    # Il file della classe oltre 6 kW ha un trattino prima di TOT, gli altri no.
    for schema in (
        f"dati prelievo orario per provincia{frammento} anno {anno}TOT.xlsx",
        f"dati prelievo orario per provincia {frammento} anno {anno}-TOT.xlsx",
        f"dati prelievo orario per provincia{frammento} anno {anno}-TOT.xlsx",
    ):
        trovati = sorted(radice().glob(f"**/{schema}"))
        if trovati:
            return trovati[0]
    sys.exit(
        f"File orario non trovato per anno {anno}, classe {classe} "
        f"(frammento '{frammento}') sotto {radice()}"
    )


def _file_mensile(anno: int) -> Path:
    return _trova(f"Dati prelievo clienti domestici Provinciale {anno}.xlsx")


# ---------------------------------------------------------------------------
# Estrazione con cache
#
# Ogni xlsx orario pesa 30-45 MB e richiede circa 40 secondi. Una costruzione a
# freddo di due anni per tutte le classi sono circa 7 minuti; dopo, la cache
# rende l'accesso immediato. La cache e' legata all'impronta dei sorgenti,
# quindi un file riscaricato la invalida da solo.
# ---------------------------------------------------------------------------

def _cache_valida(destinazione: Path, sorgenti: dict[str, Path]) -> bool:
    manifesto = destinazione.with_suffix(".json")
    if not (destinazione.exists() and manifesto.exists()):
        return False
    atteso = json.loads(manifesto.read_text(encoding="utf-8"))
    return all(
        atteso.get(nome) == impronta(percorso)
        for nome, percorso in sorgenti.items()
    )


def _scrivi_cache(destinazione: Path, df: pd.DataFrame,
                  sorgenti: dict[str, Path]) -> None:
    destinazione.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(destinazione, index=False)
    destinazione.with_suffix(".json").write_text(
        json.dumps({n: impronta(p) for n, p in sorgenti.items()}, indent=2),
        encoding="utf-8",
    )


_memoria: dict[tuple, pd.DataFrame] = {}


def orari(provincia: str, anni: tuple[int, ...] = (2024, 2025),
          verboso: bool = True) -> pd.DataFrame:
    """Tutte le curve orarie ARERA di una provincia, in forma lunga.

    Args:
        provincia: nome come compare nei file ARERA, es. "Milano".
        anni: anni da includere.
        verboso: stampa l'avanzamento della lettura a cache fredda.

    Returns:
        DataFrame con colonne anno, classe, residenza, periodo, giorno, ora, kwh.
        'periodo' vale 'anno' oppure il mese a due cifre; 'ora' va da 0 a 23.

    Nota: il risultato resta in memoria per la durata del processo. La cache su
    disco evita di rileggere gli xlsx, ma un chiamante che interroga il
    riferimento migliaia di volte (curva_numerosita.py estrae 400 sottoinsiemi
    per ciascuna dimensione) rileggerebbe comunque il CSV a ogni giro.
    """
    chiave = (provincia, anni)
    if chiave in _memoria:
        return _memoria[chiave]

    pezzi = []
    for anno in anni:
        destinazione = CACHE / f"orari_{provincia}_{anno}.csv"
        sorgenti = {FRAMMENTO_FILE[c]: _file_orario(anno, c) for c in CLASSI}
        if _cache_valida(destinazione, sorgenti):
            pezzi.append(pd.read_csv(destinazione, dtype={"periodo": str}))
            continue
        if verboso:
            print(f"  lettura dei file orari {anno} (a cache fredda richiede "
                  f"qualche minuto)...")
        righe = []
        for classe in CLASSI:
            percorso = sorgenti[FRAMMENTO_FILE[classe]]
            if verboso:
                print(f"    {percorso.name}")
            d = _normalizza(pd.read_excel(percorso))
            d = d[d["provincia"] == provincia]
            if d.empty:
                sys.exit(f"Provincia '{provincia}' assente in {percorso.name}.")
            d["periodo"] = [_periodo(v) for v in d["periodo"]]
            d["ora"] = d["ora"].str.replace("Ora", "").astype(int) - 1
            d["classe"] = classe
            righe.append(d[["classe", "residenza", "periodo", "giorno",
                            "ora", "kwh"]])
        d = pd.concat(righe, ignore_index=True)
        d["anno"] = anno
        _scrivi_cache(destinazione, d, sorgenti)
        pezzi.append(d)
    risultato = pd.concat(pezzi, ignore_index=True)
    _memoria[chiave] = risultato
    return risultato


def mensili(provincia: str, anni: tuple[int, ...] = (2024, 2025),
            verboso: bool = True) -> pd.DataFrame:
    """Consumo medio mensile e fasce ARERA di una provincia, in forma lunga.

    Returns:
        DataFrame con colonne anno, classe, residenza, mercato, periodo,
        kwh, f1, f2, f3.
    """
    pezzi = []
    for anno in anni:
        destinazione = CACHE / f"mensili_{provincia}_{anno}.csv"
        sorgenti = {"mensile": _file_mensile(anno)}
        if _cache_valida(destinazione, sorgenti):
            pezzi.append(pd.read_csv(destinazione, dtype={"periodo": str}))
            continue
        if verboso:
            print(f"  lettura del file mensile {anno}: {sorgenti['mensile'].name}")
        d = _normalizza(pd.read_excel(sorgenti["mensile"]))
        d = d[d["provincia"] == provincia]
        if d.empty:
            sys.exit(f"Provincia '{provincia}' assente nel mensile {anno}.")
        d["periodo"] = [_periodo(v) for v in d["periodo"]]
        d = d[["classe", "residenza", "mercato", "periodo", "kwh", "f1", "f2", "f3"]]
        d["anno"] = anno
        _scrivi_cache(destinazione, d, sorgenti)
        pezzi.append(d)
    return pd.concat(pezzi, ignore_index=True)


# ---------------------------------------------------------------------------
# Interfaccia di alto livello
# ---------------------------------------------------------------------------

def risolvi_classe(nome: str) -> str:
    """Accetta sia la stringa ARERA completa sia un alias breve."""
    if nome in CLASSI:
        return nome
    if nome in ALIAS_CLASSI:
        return ALIAS_CLASSI[nome]
    sys.exit(
        f"Classe di potenza non riconosciuta: '{nome}'.\n"
        f"Alias ammessi: {', '.join(sorted(ALIAS_CLASSI))}"
    )


def curve_orarie(provincia: str, classe: str, residenza: str = "Residente",
                 anni: tuple[int, ...] = (2024, 2025),
                 periodo: str = "anno") -> pd.DataFrame:
    """Curve orarie normalizzate a somma unitaria, una riga per anno e giorno.

    La normalizzazione e' il punto: si valida la FORMA separatamente dal
    livello. Confrontare curve non normalizzate mescola due errori diversi
    (quanto si consuma e quando) in un unico numero che non dice quale dei due
    e' sbagliato.

    Args:
        periodo: 'anno' per la curva annuale, oppure il mese a due cifre.

    Returns:
        DataFrame indicizzato da (anno, giorno), 24 colonne 0..23, somma 1.
    """
    classe = risolvi_classe(classe)
    d = orari(provincia, anni)
    d = d[(d["classe"] == classe) & (d["residenza"] == residenza)
          & (d["periodo"].astype(str) == periodo)]
    if d.empty:
        sys.exit(f"Nessun dato orario per {provincia} / {classe} / "
                 f"{residenza} / periodo {periodo}.")
    tabella = d.pivot_table(index=["anno", "giorno"], columns="ora", values="kwh")
    return tabella.div(tabella.sum(axis=1), axis=0)


def livello_annuo(provincia: str, classe: str, residenza: str = "Residente",
                  anni: tuple[int, ...] = (2024, 2025),
                  mercato: str = "Tutti") -> pd.Series:
    """Consumo medio annuo in kWh, per anno.

    Si somma il dettaglio mensile invece di leggere la riga annuale del file:
    i due valori coincidono, ma la somma rende esplicito che mancano dei mesi
    se il file fosse parziale.
    """
    classe = risolvi_classe(classe)
    d = mensili(provincia, anni)
    d = d[(d["classe"] == classe) & (d["residenza"] == residenza)
          & (d["mercato"] == mercato) & (d["periodo"] != "anno")]
    conteggio = d.groupby("anno")["periodo"].nunique()
    parziali = conteggio[conteggio != 12]
    if not parziali.empty:
        print(f"Attenzione: mesi mancanti per {classe} negli anni "
              f"{dict(parziali)} - il totale annuo e' parziale.")
    return d.groupby("anno")["kwh"].sum()


def forma_mensile(provincia: str, classe: str, residenza: str = "Residente",
                  anni: tuple[int, ...] = (2024, 2025),
                  mercato: str = "Tutti") -> pd.DataFrame:
    """Quota di ciascun mese sul totale annuo, per anno. Somma 1 per riga."""
    classe = risolvi_classe(classe)
    d = mensili(provincia, anni)
    d = d[(d["classe"] == classe) & (d["residenza"] == residenza)
          & (d["mercato"] == mercato) & (d["periodo"] != "anno")]
    tabella = d.pivot_table(index="anno", columns="periodo", values="kwh")
    return tabella.div(tabella.sum(axis=1), axis=0)


def fasce(provincia: str, classe: str, residenza: str = "Residente",
          anni: tuple[int, ...] = (2024, 2025),
          mercato: str = "Tutti") -> pd.DataFrame:
    """Ripartizione F1 / F2 / F3 dichiarata da ARERA, media sui mesi, per anno.

    Sono le quote che ARERA stessa pubblica, non un ricalcolo dalle curve
    orarie: usarle evita di dover replicare il calendario delle festivita' e
    la definizione esatta delle fasce.
    """
    classe = risolvi_classe(classe)
    d = mensili(provincia, anni)
    d = d[(d["classe"] == classe) & (d["residenza"] == residenza)
          & (d["mercato"] == mercato) & (d["periodo"] != "anno")]
    return d.groupby("anno")[["f1", "f2", "f3"]].mean() * 100


def rumore_fonte(provincia: str, classe: str, residenza: str = "Residente",
                 anni: tuple[int, int] = (2024, 2025)) -> dict:
    """Quanto cambia il riferimento da un anno all'altro: la soglia di validita'.

    A comportamento della popolazione presumibilmente stabile, lo scarto fra
    due anni consecutivi della stessa fonte misura il rumore irriducibile del
    riferimento. Uno scarto LPG-ARERA dello stesso ordine significa che la
    forma generata e' indistinguibile dal riferimento; uno scarto molto
    maggiore e' un difetto del modello, non del dato.

    Returns:
        {'tvd_orario': {giorno: valore}, 'l1_mensile': float,
         'scarto_livello_pct': float, 'scarto_fasce_punti': {fascia: valore}}
    """
    if len(anni) != 2:
        sys.exit("rumore_fonte confronta esattamente due anni.")
    a, b = anni

    curve = curve_orarie(provincia, classe, residenza, anni)
    tvd = {}
    for giorno in GIORNI:
        if (a, giorno) in curve.index and (b, giorno) in curve.index:
            diff = (curve.loc[(a, giorno)] - curve.loc[(b, giorno)]).abs().sum()
            tvd[giorno] = float(diff) / 2

    mens = forma_mensile(provincia, classe, residenza, anni)
    l1 = float((mens.loc[a] - mens.loc[b]).abs().sum())

    liv = livello_annuo(provincia, classe, residenza, anni)
    scarto_livello = float((liv[b] - liv[a]) / liv[a] * 100)

    fa = fasce(provincia, classe, residenza, anni)
    scarto_fasce = {c: float(fa.loc[b, c] - fa.loc[a, c]) for c in ("f1", "f2", "f3")}

    return {
        "tvd_orario": tvd,
        "l1_mensile": l1,
        "scarto_livello_pct": scarto_livello,
        "scarto_fasce_punti": scarto_fasce,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("provincia", help="nome ARERA della provincia, es. Milano")
    parser.add_argument("--classe", default=None,
                        help="alias o stringa ARERA; se assente le stampa tutte")
    parser.add_argument("--residenza", default="Residente")
    parser.add_argument("--anni", type=int, nargs="+", default=[2024, 2025])
    args = parser.parse_args()

    anni = tuple(args.anni)
    classi = [risolvi_classe(args.classe)] if args.classe else CLASSI

    # Si popola la cache prima di stampare, altrimenti i messaggi di
    # avanzamento della lettura si infilano in mezzo alle tabelle.
    mensili(args.provincia, anni)
    orari(args.provincia, anni)

    print(f"\nRIFERIMENTO ARERA - {args.provincia}, {args.residenza}, "
          f"anni {' e '.join(map(str, anni))}\n")

    print(f"{'classe':28} " + " ".join(f"{a:>10}" for a in anni) + "   fasce F1/F2/F3")
    print("-" * 78)
    for classe in classi:
        liv = livello_annuo(args.provincia, classe, args.residenza, anni)
        fa = fasce(args.provincia, classe, args.residenza, anni)
        ultimo = fa.loc[anni[-1]]
        print(f"{classe:28} "
              + " ".join(f"{liv.get(a, float('nan')):>10,.0f}" for a in anni)
              + f"   {ultimo['f1']:.1f} / {ultimo['f2']:.1f} / {ultimo['f3']:.1f}")

    if len(anni) != 2:
        return

    print(f"\nRUMORE DELLA FONTE fra {anni[0]} e {anni[1]} "
          f"- e' la soglia di accettazione\n")
    print(f"{'classe':28} {'TVD feriale':>12} {'TVD sabato':>11} "
          f"{'TVD domenica':>13} {'L1 mensile':>11} {'livello':>9}")
    print("-" * 88)
    for classe in classi:
        r = rumore_fonte(args.provincia, classe, args.residenza, anni)
        t = r["tvd_orario"]
        print(f"{classe:28} {t.get('Giorno feriale', float('nan')):>12.4f} "
              f"{t.get('Sabato', float('nan')):>11.4f} "
              f"{t.get('Domenica', float('nan')):>13.4f} "
              f"{r['l1_mensile']:>11.4f} {r['scarto_livello_pct']:>8.1f}%")

    print("\nLe curve orarie ARERA coprono i soli clienti trattati orari: la")
    print("rappresentativita' rispetto all'intera popolazione domestica non e'")
    print("verificabile con i dati pubblicati, e va dichiarata come limite.")


if __name__ == "__main__":
    main()
