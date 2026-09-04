"""Numeri ISTAT e HETUS che giustificano le migrazioni del catalogo italiano.

Ogni migrazione di build_italian_db.py cita nella propria descrizione un valore
statistico: la quota di piani cottura a gas, l'ora della cena, il tasso di
possesso dell'asciugatrice. Questo modulo li RICALCOLA dalle fonti originali,
invece di lasciarli come numeri copiati a mano.

PERCHE'. I numeri di CONTESTO_VALIDAZIONE_ARERA.md vengono da script mai
committati e oggi non sono piu' ricostruibili. Una citazione che non si puo'
rigenerare non e' una citazione, e' un ricordo. `scheda_citazioni()` stampa
tutti i valori usati nelle migrazioni: rieseguendola si devono ritrovare gli
stessi numeri scritti nelle descrizioni. Se non coincidono, o e' cambiata la
fonte o e' sbagliata la migrazione, e in entrambi i casi va saputo.

QUATTRO FONTI, RUOLI DIVERSI:

  ISTAT Consumi energetici 2021   dotazione, vettori energetici, ore d'uso
    (Tavole_Appendice.xlsx)       -> D01 piano cottura, D02 frigo, D03 luci,
                                     HT01 raffrescamento, Fase 1 riscaldamento
  ISTAT Dotazioni energetiche 2024 diffusione del raffrescamento
  ISTAT AVQ 2024 (microdati)      orari reali: uscita di casa, pranzo, TV
    45.005 record, 736 variabili  -> V02, L07
  ETHOS.ActivityAssure (HETUS)    forma infragiornaliera delle attivita'
    IT e DE, stessa segmentazione -> L08, L09, L10 e controllo negativo su DE

Le prime tre sono Lombardia; ActivityAssure e' nazionale.

ATTENZIONE ALLA CIRCOLARITA'. Queste fonti sono INPUT del modello. La
validazione si fa contro ARERA (riferimento_arera.py), che misura kWh al
contatore: grandezza diversa, campione diverso, anno diverso. Calibrare e
validare sulla stessa fonte non sarebbe validazione.

Uso:
    python riferimento_istat.py                 # stampa la scheda completa
    python riferimento_istat.py --tavola 19     # una singola tavola ISTAT
"""

from __future__ import annotations

import argparse
import html
import re
import sys
from pathlib import Path

import numpy as np
import pandas as pd

from riferimento_arera import radice

# Un profilo ActivityAssure ha 144 passi da 10 minuti che partono dalle 04:00,
# non dalla mezzanotte. Ignorarlo sposta ogni orario di quattro ore.
PASSI_GIORNO = 144
MINUTI_PASSO = 10
ORA_INIZIO = 4

# COEFIN, il coefficiente di riporto all'universo, e' un intero con quattro
# decimali impliciti ("separatore decimale virtuale" nel tracciato ISTAT).
# Senza la divisione la popolazione risulta diecimila volte troppo grande.
DECIMALI_COEFIN = 10_000

LOMBARDIA_AVQ = "030"


# ---------------------------------------------------------------------------
# Tavole aggregate ISTAT
# ---------------------------------------------------------------------------

def _percorso(nome: str) -> Path:
    trovati = sorted(radice().glob(f"**/{nome}"))
    if not trovati:
        sys.exit(f"File ISTAT non trovato: {nome}\n  cercato sotto {radice()}")
    return trovati[0]


def _intestazione(grezzo: pd.DataFrame, prima_riga_dati: int) -> list[str]:
    """Ricompone i nomi di colonna dalle righe di intestazione sovrapposte.

    Le tavole ISTAT hanno intestazioni su due o tre righe con celle unite: la
    riga superiore porta il gruppo ("Piano cottura"), quella sotto la voce
    ("Energia elettrica"). Le celle unite lasciano buchi che vanno riempiti
    orizzontalmente, altrimenti meta' delle colonne resta senza gruppo.
    """
    righe = []
    for i in range(1, prima_riga_dati):
        riga = grezzo.iloc[i].astype(str).replace("nan", "")
        # Il riempimento orizzontale parte dalla colonna 1: la colonna 0 porta
        # l'etichetta di riga (o il titolo di sezione, come nella Tavola 15) e
        # propagarla incollerebbe quel testo al nome di ogni altra colonna.
        testa, resto = riga.iloc[:1], riga.iloc[1:]
        resto = resto.replace("", pd.NA).ffill().fillna("")
        riga = pd.concat([testa, resto])
        righe.append([str(v).replace("\n", " ").strip() for v in riga])
    nomi = []
    for col in range(grezzo.shape[1]):
        parti = [r[col] for r in righe if r[col]]
        # Evita "Totale / Totale" quando gruppo e voce coincidono.
        univoche = list(dict.fromkeys(parti))
        nomi.append(" / ".join(univoche) if univoche else f"col{col}")
    return nomi


def _tavola(percorso: Path, foglio: str, etichetta: str) -> pd.DataFrame:
    """Estrae le righe di una tavola ISTAT che portano una data etichetta.

    Alcune tavole (es. la 15) ripetono l'elenco delle regioni una volta per
    sezione, quindi la stessa etichetta compare piu' volte: si restituiscono
    tutte le occorrenze e sta al chiamante scegliere.
    """
    grezzo = pd.read_excel(percorso, sheet_name=foglio, header=None)
    prima_colonna = grezzo.iloc[:, 0].astype(str).str.strip()

    corrispondenze = prima_colonna[prima_colonna == etichetta].index.tolist()
    if not corrispondenze:
        disponibili = [v for v in prima_colonna.unique()[:40] if v not in ("nan", "")]
        sys.exit(f"Etichetta '{etichetta}' assente nel foglio {foglio}.\n"
                 f"  presenti: {disponibili}")

    # La prima riga di dati e' la prima con un'etichetta e un numero accanto.
    prima_riga_dati = min(corrispondenze)
    for i in range(len(grezzo)):
        if prima_colonna[i] in ("nan", ""):
            continue
        if pd.to_numeric(grezzo.iloc[i, 1:], errors="coerce").notna().any():
            prima_riga_dati = i
            break

    nomi = _intestazione(grezzo, prima_riga_dati)
    estratto = grezzo.loc[corrispondenze].copy()
    estratto.columns = nomi
    estratto = estratto.set_index(estratto.columns[0])
    # Le tavole hanno colonne separatrici vuote fra un gruppo e l'altro: le
    # elimina, altrimenti compaiono come voci senza valore.
    return estratto.dropna(axis=1, how="all")


def consumi_2021(foglio: str, regione: str = "Lombardia") -> pd.DataFrame:
    """Una tavola di ISTAT *Consumi energetici delle famiglie - Anno 2021*.

    Fogli utili: '15' ore di condizionamento, '16' lampadine, '18'
    elettrodomestici, '19' piano cottura e forno, '7' ore di riscaldamento.
    """
    return _tavola(_percorso("Tavole_Appendice.xlsx"), foglio, regione)


def dotazioni_2024(foglio: str, regione: str = "Lombardia") -> pd.DataFrame:
    """Una tavola di ISTAT *Dotazioni energetiche delle famiglie - Anno 2024*.

    Foglio '3': famiglie dotate di sistemi di raffrescamento, per regione.
    """
    return _tavola(_percorso("HOUSEHOLD-ENERGY-EQUIPMENT.xlsx"), foglio, regione)


# ---------------------------------------------------------------------------
# Microdati AVQ 2024
# ---------------------------------------------------------------------------

_avq_cache: pd.DataFrame | None = None


def _tracciato_avq() -> dict[str, int]:
    """Mappa acronimo -> numero d'ordine, letta dal tracciato record.

    Serve per risalire al file di classificazione di ciascuna variabile
    (var<N>.html). Si ricava dal tracciato invece di essere scritta a mano,
    cosi' resta valida se ISTAT rinumera le variabili in un'edizione futura.
    """
    percorso = _percorso("AVQ_Tracciato_2024.html")
    testo = html.unescape(re.sub(r"<[^>]+>", "|", percorso.read_text(encoding="latin-1")))
    testo = re.sub(r"\|{2,}", "|", testo).replace("\xa0", " ").replace("\n", " ")
    mappa = {}
    for m in re.finditer(r"\|\s*(\d{1,3})\s*\|\s*\d+\s*\|\s*([A-Za-z0-9_]+)\s*\|", testo):
        mappa.setdefault(m.group(2), int(m.group(1)))
    return mappa


def _classificazione(acronimo: str) -> dict[str, str]:
    """Decodifica i codici di una variabile categorica AVQ in etichette."""
    numero = _tracciato_avq().get(acronimo)
    if numero is None:
        return {}
    trovati = sorted(radice().glob(
        f"**/AVQ_Classificazione_2024_var{numero}.html"))
    if not trovati:
        return {}
    testo = html.unescape(re.sub(r"<[^>]+>", "|", trovati[0].read_text(encoding="latin-1")))
    testo = testo.replace("\xa0", " ")
    mappa = {}
    for riga in testo.split("\n"):
        campi = [c.strip() for c in riga.split("|") if c.strip()]
        if len(campi) >= 2 and not campi[0].startswith(("Modalita", "ELENCO")):
            mappa[campi[0]] = campi[1]
    return mappa


def avq(regione: str = LOMBARDIA_AVQ) -> pd.DataFrame:
    """Microdati AVQ 2024 di una regione, con il peso gia' scalato.

    Args:
        regione: codice ISTAT a tre cifre; '030' e' la Lombardia.
                 None per l'intero campione nazionale.
    """
    global _avq_cache
    if _avq_cache is None:
        percorso = _percorso("AVQ_Microdati_2024.txt")
        d = pd.read_csv(percorso, sep="\t", dtype=str, encoding="latin-1")
        d.columns = [c.strip() for c in d.columns]
        for col in d.columns:
            d[col] = d[col].str.strip()
        d = d.assign(peso=pd.to_numeric(d["COEFIN"], errors="coerce") / DECIMALI_COEFIN)
        _avq_cache = d
    d = _avq_cache
    return d if regione is None else d[d["REGMf"] == regione].copy()


def quote_avq(variabile: str, regione: str = LOMBARDIA_AVQ) -> pd.Series:
    """Distribuzione percentuale pesata di una variabile categorica AVQ."""
    d = avq(regione)
    valide = d[d[variabile].ne("") & d[variabile].ne("nan")]
    if valide.empty:
        sys.exit(f"Variabile AVQ '{variabile}' priva di valori validi.")
    quote = valide.groupby(variabile)["peso"].sum()
    quote = quote / quote.sum() * 100
    etichette = _classificazione(variabile)
    quote.index = [etichette.get(k, k) for k in quote.index]
    return quote.sort_values(ascending=False)


def orario_avq(var_ore: str, var_minuti: str, regione: str = LOMBARDIA_AVQ,
               massimo: float = 24.0) -> dict:
    """Statistiche pesate di una variabile AVQ espressa in ore + minuti.

    I percentili si calcolano replicando ogni osservazione in proporzione al
    suo peso: e' approssimato ma sufficiente, e resta trasparente da leggere.
    """
    d = avq(regione)
    ore = pd.to_numeric(d[var_ore], errors="coerce")
    minuti = pd.to_numeric(d[var_minuti], errors="coerce").fillna(0)
    valide = ore.notna() & (ore <= massimo)
    if not valide.any():
        sys.exit(f"Nessun dato valido per {var_ore}/{var_minuti}.")

    valori = (ore[valide] + minuti[valide] / 60.0).to_numpy()
    pesi = d.loc[valide, "peso"].to_numpy()
    ripetizioni = np.maximum(1, np.round(pesi / pesi.mean()).astype(int))
    campione = np.repeat(valori, ripetizioni)

    return {
        "n": int(valide.sum()),
        "media": float(np.average(valori, weights=pesi)),
        "p25": float(np.percentile(campione, 25)),
        "p50": float(np.percentile(campione, 50)),
        "p75": float(np.percentile(campione, 75)),
    }


# ---------------------------------------------------------------------------
# ETHOS.ActivityAssure
# ---------------------------------------------------------------------------

def _ora(passo: int) -> float:
    """Converte l'indice di passo in ora decimale del giorno."""
    return ((ORA_INIZIO * 60 + passo * MINUTI_PASSO) % 1440) / 60.0


def profilo_attivita(paese: str, sesso: str, stato: str,
                     giorno: str) -> pd.DataFrame:
    """Probabilita' di ciascuna attivita' lungo il giorno, per una categoria.

    Args:
        paese: 'IT' o 'DE'.
        stato: 'full time', 'part time', 'retired', 'student', 'unemployed'.
        giorno: 'working day' o 'rest day'.

    Returns:
        DataFrame attivita' x 144 passi. Le colonne sommano a 1: in ogni
        istante ciascuna persona sta facendo esattamente una cosa.
    """
    nome = f"prob_{paese}_{sesso}_{stato}_{giorno}.csv"
    trovati = sorted(radice().glob(f"**/probability_profiles/{nome}"))
    if not trovati:
        sys.exit(f"Categoria ActivityAssure assente: {nome}\n"
                 f"  alcune combinazioni non hanno abbastanza diari HETUS "
                 f"(minimo 20) e non vengono pubblicate.")
    return pd.read_csv(trovati[0], index_col=0)


def picco(paese: str, sesso: str, stato: str, giorno: str, attivita: str,
          da: float, a: float) -> tuple[str, float]:
    """Ora e ampiezza del massimo di un'attivita' in una finestra oraria.

    Returns:
        (orario 'HH:MM', probabilita' nel punto di massimo).
    """
    serie = profilo_attivita(paese, sesso, stato, giorno).loc[attivita]
    ore = np.array([_ora(i) for i in range(PASSI_GIORNO)])
    dentro = (ore >= da) & (ore < a)
    valori = np.where(dentro, serie.to_numpy(), -1.0)
    k = int(np.argmax(valori))
    minuti = (ORA_INIZIO * 60 + k * MINUTI_PASSO) % 1440
    return f"{minuti // 60:02d}:{minuti % 60:02d}", float(serie.iloc[k])


def massa(paese: str, sesso: str, stato: str, giorno: str, attivita: str,
          da: float, a: float) -> float:
    """Quota della massa giornaliera di un'attivita' che cade in una finestra."""
    serie = profilo_attivita(paese, sesso, stato, giorno).loc[attivita].to_numpy()
    ore = np.array([_ora(i) for i in range(PASSI_GIORNO)])
    totale = serie.sum()
    if totale == 0:
        return float("nan")
    return float(serie[(ore >= da) & (ore < a)].sum() / totale * 100)


# ---------------------------------------------------------------------------
# La scheda delle citazioni
# ---------------------------------------------------------------------------

def _formatta(valore) -> str:
    """Arrotonda i decimali di macchina delle tavole ISTAT (4,4079999 -> 4,408)."""
    try:
        return f"{float(valore):g}"
    except (TypeError, ValueError):
        return str(valore)


def scheda_citazioni() -> None:
    """Stampa tutti i valori citati nelle descrizioni delle migrazioni.

    E' il controllo di coerenza fra il catalogo e le sue fonti: i numeri qui
    stampati devono coincidere con quelli scritti nelle migrazioni.
    """
    print("=" * 78)
    print("D01 - piano cottura e forno")
    print("  ISTAT Consumi energetici 2021, Tavola 19, Lombardia")
    print("=" * 78)
    t19 = consumi_2021("19")
    for colonna, valore in t19.iloc[0].items():
        print(f"    {str(colonna)[:60]:60} {_formatta(valore)}")

    print()
    print("=" * 78)
    print("HT01 - raffrescamento: diffusione, ore d'uso, frequenza")
    print("=" * 78)
    print("  ISTAT Dotazioni energetiche 2024, Tavola 3, Lombardia")
    for colonna, valore in dotazioni_2024("3").iloc[0].items():
        print(f"    {str(colonna)[:60]:60} {_formatta(valore)}")
    print("  ISTAT Consumi energetici 2021, Tavola 15, Lombardia (ore/giorno)")
    for colonna, valore in consumi_2021("15").iloc[0].items():
        print(f"    {str(colonna)[:60]:60} {_formatta(valore)}")
    print("  ISTAT Consumi energetici 2021, Tavola 14, Lombardia (frequenza)")
    for colonna, valore in consumi_2021("14").iloc[0].items():
        print(f"    {str(colonna)[:60]:60} {_formatta(valore)}")

    print()
    print("=" * 78)
    print("D02 / D03 / 2.10 - dotazione di elettrodomestici e lampadine")
    print("=" * 78)
    print("  ISTAT Consumi energetici 2021, Tavola 18, Lombardia")
    for colonna, valore in consumi_2021("18").iloc[0].items():
        print(f"    {str(colonna)[:60]:60} {_formatta(valore)}")
    print("  ISTAT Consumi energetici 2021, Tavola 16, Lombardia")
    for colonna, valore in consumi_2021("16").iloc[0].items():
        print(f"    {str(colonna)[:60]:60} {_formatta(valore)}")

    print()
    print("=" * 78)
    print("Fase 1 - ore di riscaldamento (controllo sulla pompa di circolazione)")
    print("  ISTAT Consumi energetici 2021, Tavola 7, Lombardia")
    print("=" * 78)
    for colonna, valore in consumi_2021("7").iloc[0].items():
        print(f"    {str(colonna)[:60]:60} {_formatta(valore)}")

    print()
    print("=" * 78)
    print("V02 - orario di uscita da casa e tempo di spostamento")
    print("  ISTAT AVQ 2024, Lombardia, pesato")
    print("=" * 78)
    uscita = orario_avq("USORA", "USMIN")
    print(f"    uscita da casa    n={uscita['n']:5}  media {uscita['media']:.2f} h  "
          f"p25 {uscita['p25']:.2f}  p50 {uscita['p50']:.2f}  p75 {uscita['p75']:.2f}")
    tragitto = orario_avq("HHSCLA", "MMSCLA")
    print(f"    tempo di tragitto n={tragitto['n']:5}  media {tragitto['media']:.2f} h  "
          f"p50 {tragitto['p50']:.2f} h")

    print()
    print("=" * 78)
    print("L07 - il pranzo. ISTAT AVQ 2024, Lombardia, pesato")
    print("=" * 78)
    for variabile, titolo in (("PASTO", "pasto principale"),
                              ("LPRAN", "dove si pranza nei giorni non festivi")):
        print(f"  {titolo}")
        for etichetta, quota in quote_avq(variabile).items():
            print(f"    {str(etichetta)[:60]:60} {quota:5.1f}%")

    print()
    print("=" * 78)
    print("L08 / L09 / L10 - orari delle attivita'. ETHOS.ActivityAssure, feriale")
    print("=" * 78)
    print(f"    {'categoria':22} {'pranzo IT':>14} {'pranzo DE':>14} "
          f"{'cena IT':>14} {'cena DE':>14}")
    for sesso in ("female", "male"):
        riga = f"    {sesso + ' full time':22}"
        for attivita, da, a in (("eat", 10, 15), ("eat", 16, 23)):
            for paese in ("IT", "DE"):
                ora, valore = picco(paese, sesso, "full time", "working day",
                                    attivita, da, a)
                riga += f" {ora + ' ' + format(valore * 100, '.1f') + '%':>13}"
        print(riga)

    print()
    print("    bucato (laundry), ripartizione della massa giornaliera")
    print(f"    {'categoria':22} {'06-12':>8} {'12-18':>8} {'18-24':>8}")
    for paese in ("IT", "DE"):
        riga = f"    {'donna full time ' + paese:22}"
        for da, a in ((6, 12), (12, 18), (18, 24)):
            riga += f" {massa(paese, 'female', 'full time', 'working day', 'laundry', da, a):7.1f}%"
        print(riga)

    print()
    print("Questi numeri devono coincidere con quelli citati nelle descrizioni")
    print("delle migrazioni in build_italian_db.py. Se divergono, o e' cambiata")
    print("la fonte o la migrazione non dice il vero: in entrambi i casi va saputo.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--tavola", help="numero di foglio di Tavole_Appendice.xlsx")
    parser.add_argument("--regione", default="Lombardia")
    args = parser.parse_args()

    if args.tavola:
        print(consumi_2021(args.tavola, args.regione).T.to_string())
    else:
        scheda_citazioni()


if __name__ == "__main__":
    main()
