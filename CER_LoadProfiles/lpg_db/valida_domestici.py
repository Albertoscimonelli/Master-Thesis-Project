"""Valida i profili domestici generati da LPG contro il dato ARERA.

Confronta forma oraria, forma mensile, livello e fasce di ciascuna famiglia
generata con la curva ARERA della sua classe di potenza, nella provincia della
CER. La soglia di accettazione non e' un numero scelto a tavolino: e' il rumore
della fonte stessa fra due anni consecutivi, calcolato da
riferimento_arera.rumore_fonte().

SI NORMALIZZA PRIMA DI CONFRONTARE. Ogni curva viene riportata a somma unitaria,
cosi' la FORMA si valida separatamente dal LIVELLO. Sono due errori diversi:
consumare troppo e consumare nel momento sbagliato. Un confronto su curve non
normalizzate li mescola in un unico numero che non dice quale dei due sia il
problema. E' il passaggio che si sbaglia piu' facilmente.

CHE COSA SI CORREGGE SE NON COMBACIA. Il catalogo, non l'output. Un fattore
correttivo applicato alle curve sistemerebbe la somma rendendo i profili
individuali meno plausibili, e la ripartizione dell'energia condivisa nella CER
vive esattamente sulle forme individuali: Shapley, Nucleolo e VLC si
distinguono da una ripartizione volumetrica solo se i membri consumano in
momenti diversi.

RAPPORTO CON confronta_profili.py. Quello implementa la Profildifferenz di
Pflugradt e serve ai confronti A/B fra due generazioni: dice se una modifica ha
avuto effetto. Questo dice se il risultato assomiglia alla realta' italiana.
Domande diverse, metriche diverse; qui si riusano le sue funzioni di
caricamento e di lettura delle curve.

TRE LIMITI DA DICHIARARE IN TESI:

  1. Le curve orarie ARERA coprono i soli clienti trattati orari.
  2. La classe di potenza di ciascuna famiglia e' un'assunzione, non un dato:
     ARERA non pubblica il numero di clienti per classe e provincia. Per questo
     il rapporto riporta anche la classe adiacente.
  3. ARERA non documenta come classifichi i giorni festivi infrasettimanali.
     Qui vengono esclusi dai feriali (--includi-festivi per non farlo): sono
     una dozzina di giorni su circa 250, quindi l'effetto e' piccolo, ma la
     scelta va resa esplicita.

Uso:
    python valida_domestici.py ../outputs/csv/profili_tutti.csv
    python valida_domestici.py profili.csv --provincia Milano --colonne household_1:1.5-3
"""

from __future__ import annotations

import argparse
import datetime as dt
import sys
from pathlib import Path

import pandas as pd

from confronta_profili import STAGIONI, carica, curve_medie
import riferimento_arera as ra

# Corrispondenza fra i tipi di giorno di confronta_profili e quelli ARERA.
GIORNI = {"lun-ven": "Giorno feriale", "sabato": "Sabato", "domenica": "Domenica"}

# I mesi che compongono ciascuna stagione, con la convenzione di STAGIONI.
MESI_STAGIONE: dict[str, list[str]] = {}
for _mese, _stagione in STAGIONI.items():
    MESI_STAGIONE.setdefault(_stagione, []).append(f"{_mese:02d}")

# Festivita' nazionali a data fissa. Il Lunedi dell'Angelo si calcola a parte;
# i patroni locali non sono nazionali e restano fuori.
FESTIVI_FISSI = {
    (1, 1), (1, 6), (4, 25), (5, 1), (6, 2),
    (8, 15), (11, 1), (12, 8), (12, 25), (12, 26),
}

# Assegnazione predefinita famiglia -> classe di potenza, per numero di
# componenti (confine a 3). E' un'assunzione dichiarata, non un dato: si
# riporta sempre anche la classe adiacente.
CLASSI_PREDEFINITE = {
    "household_1": "1.5-3",
    "household_2": "1.5-3",
    "household_3": "3-4.5",
    "household_4": "3-4.5",
}

ADIACENTI = {
    "0-1.5": "1.5-3",
    "1.5-3": "3-4.5",
    "3-4.5": "4.5-6",
    "4.5-6": ">6",
    ">6": "4.5-6",
}


def _pasqua(anno: int) -> dt.date:
    """Domenica di Pasqua secondo l'algoritmo gregoriano anonimo."""
    a, b, c = anno % 19, anno // 100, anno % 100
    d, e = b // 4, b % 4
    f, g = (b + 8) // 25, (b - (b + 8) // 25 + 1) // 3
    h = (19 * a + b - d - g + 15) % 30
    i, k = c // 4, c % 4
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) // 451
    mese = (h + l - 7 * m + 114) // 31
    giorno = ((h + l - 7 * m + 114) % 31) + 1
    return dt.date(anno, mese, giorno)


def festivi(anno: int) -> set[dt.date]:
    """Giorni festivi nazionali italiani di un anno, Lunedi dell'Angelo incluso."""
    giorni = {dt.date(anno, m, g) for m, g in FESTIVI_FISSI}
    giorni.add(_pasqua(anno) + dt.timedelta(days=1))
    return giorni


def _senza_festivi(serie: pd.Series) -> pd.Series:
    """Toglie i festivi nazionali, che non sono giorni feriali."""
    esclusi = set()
    for anno in serie.index.year.unique():
        esclusi |= festivi(int(anno))
    return serie[~pd.Series(serie.index.date, index=serie.index).isin(esclusi)]


def _fascia(istante: pd.Timestamp, giorni_festivi: set[dt.date]) -> str:
    """Fascia ARERA di un'ora: F1 lun-ven 08-19, F2 lun-ven 07-08 e 19-23 piu'
    sabato 07-23, F3 tutto il resto, domeniche e festivi nazionali inclusi."""
    if istante.date() in giorni_festivi or istante.weekday() == 6:
        return "f3"
    ora = istante.hour
    if istante.weekday() == 5:
        return "f2" if 7 <= ora < 23 else "f3"
    if 8 <= ora < 19:
        return "f1"
    if ora == 7 or 19 <= ora < 23:
        return "f2"
    return "f3"


def fasce_profilo(serie: pd.Series) -> pd.Series:
    """Ripartizione F1/F2/F3 in percentuale di un profilo orario."""
    esclusi = set()
    for anno in serie.index.year.unique():
        esclusi |= festivi(int(anno))
    etichette = [_fascia(t, esclusi) for t in serie.index]
    quote = serie.groupby(etichette).sum()
    return quote / quote.sum() * 100


def curva_arera(provincia: str, classe: str, residenza: str, anni: tuple[int, ...],
                giorno_arera: str, stagione: str | None = None) -> pd.Series:
    """Curva oraria ARERA normalizzata, mediata sugli anni richiesti.

    Args:
        stagione: None per la curva annuale; altrimenti 'inverno', 'estate' o
            'mezza', ottenuta mediando i mesi che la compongono.

    Nota: i mesi di una stagione vengono mediati senza pesarli per il numero di
    giorni. Le curve mensili di una stessa stagione hanno forma molto simile e
    la normalizzazione successiva assorbe quasi tutto lo scarto, ma
    l'approssimazione va ricordata.
    """
    classe = ra.risolvi_classe(classe)
    d = ra.orari(provincia, anni, verboso=False)
    d = d[(d["classe"] == classe) & (d["residenza"] == residenza)
          & (d["giorno"] == giorno_arera)]
    periodi = ["anno"] if stagione is None else MESI_STAGIONE[stagione]
    d = d[d["periodo"].astype(str).isin(periodi)]
    if d.empty:
        return pd.Series(dtype=float)
    curva = d.groupby("ora")["kwh"].mean()
    return curva / curva.sum()


def tvd(a: pd.Series, b: pd.Series) -> float:
    """Total Variation Distance fra due distribuzioni sulle 24 ore.

    Vale 0 per curve identiche e 1 per curve che non si sovrappongono mai.
    Si assume che entrambe siano gia' normalizzate a somma unitaria.
    """
    comuni = a.index.intersection(b.index)
    if len(comuni) == 0:
        return float("nan")
    return float((a[comuni] - b[comuni]).abs().sum()) / 2


def valida_colonna(serie: pd.Series, provincia: str, classe: str,
                   residenza: str, anni: tuple[int, ...],
                   escludi_festivi: bool = True) -> dict:
    """Confronta un profilo con la curva ARERA della sua classe.

    Returns:
        {'tvd': {giorno: valore}, 'tvd_stagione': {(stagione, giorno): valore},
         'kwh': float, 'fasce': Series}
    """
    feriali_puliti = _senza_festivi(serie) if escludi_festivi else serie
    curve = curve_medie(feriali_puliti)

    risultato = {"kwh": float(serie.sum()), "fasce": fasce_profilo(serie)}

    # Forma annuale, un valore per tipo di giorno: e' la metrica principale.
    per_giorno = {}
    for interno, arera in GIORNI.items():
        pezzi = [c for (stag, gio), c in curve.items() if gio == interno]
        if not pezzi:
            continue
        media = pd.concat(pezzi, axis=1).mean(axis=1)
        media = media / media.sum()
        riferimento = curva_arera(provincia, classe, residenza, anni, arera)
        if not riferimento.empty:
            per_giorno[arera] = tvd(media, riferimento)
    risultato["tvd"] = per_giorno

    # Forma per stagione: dice se il modello sbaglia solo in una parte dell'anno.
    per_stagione = {}
    for (stagione, interno), curva in curve.items():
        riferimento = curva_arera(provincia, classe, residenza, anni,
                                  GIORNI[interno], stagione)
        if riferimento.empty:
            continue
        per_stagione[(stagione, GIORNI[interno])] = tvd(curva / curva.sum(),
                                                        riferimento)
    risultato["tvd_stagione"] = per_stagione
    return risultato


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("profili", type=Path, help="CSV prodotto dalla pipeline")
    parser.add_argument("--provincia", default="Milano")
    parser.add_argument("--residenza", default="Residente")
    parser.add_argument("--anni", type=int, nargs="+", default=[2024, 2025])
    parser.add_argument("--colonne", nargs="*", default=None,
                        help="coppie colonna:classe, es. household_1:1.5-3")
    parser.add_argument("--includi-festivi", action="store_true",
                        help="non escludere i festivi nazionali dai feriali")
    args = parser.parse_args()

    if not args.profili.exists():
        sys.exit(f"File non trovato: {args.profili}")

    anni = tuple(args.anni)
    df = carica(args.profili)

    if args.colonne:
        assegnazione = {}
        for voce in args.colonne:
            if ":" not in voce:
                sys.exit(f"Formato atteso colonna:classe, ricevuto '{voce}'")
            colonna, classe = voce.split(":", 1)
            assegnazione[colonna] = classe
    else:
        assegnazione = {c: k for c, k in CLASSI_PREDEFINITE.items()
                        if c in df.columns or f"{c}_kWh" in df.columns}

    if not assegnazione:
        sys.exit("Nessuna colonna domestica riconosciuta. Usare --colonne.")

    ra.orari(args.provincia, anni)   # popola la cache prima di stampare

    print(f"\nVALIDAZIONE DOMESTICI - {args.profili.name}")
    print(f"riferimento ARERA {args.provincia}, {args.residenza}, "
          f"anni {' e '.join(map(str, anni))}\n")

    print(f"{'colonna':22} {'classe':10} {'kWh/anno':>10} {'atteso':>10} "
          f"{'scarto':>8}   {'TVD fer.':>9} {'sab.':>7} {'dom.':>7}")
    print("-" * 96)

    aggregato = None
    for colonna, classe in assegnazione.items():
        nome = colonna if colonna in df.columns else f"{colonna}_kWh"
        if nome not in df.columns:
            print(f"{colonna:22} colonna assente nel file, saltata")
            continue
        serie = df[nome]
        aggregato = serie if aggregato is None else aggregato + serie

        esito = valida_colonna(serie, args.provincia, classe, args.residenza,
                               anni, not args.includi_festivi)
        atteso = ra.livello_annuo(args.provincia, classe, args.residenza,
                                  anni).mean()
        t = esito["tvd"]
        print(f"{colonna:22} {classe:10} {esito['kwh']:>10,.0f} {atteso:>10,.0f} "
              f"{esito['kwh'] / atteso:>7.2f}x   "
              f"{t.get('Giorno feriale', float('nan')):>9.3f} "
              f"{t.get('Sabato', float('nan')):>7.3f} "
              f"{t.get('Domenica', float('nan')):>7.3f}")

    print("-" * 96)
    print("\nSOGLIA DI ACCETTAZIONE - rumore della fonte fra i due anni ARERA")
    print(f"{'classe':10} {'TVD fer.':>9} {'sab.':>7} {'dom.':>7} "
          f"{'L1 mens.':>9} {'livello':>8}")
    for classe in sorted(set(assegnazione.values())):
        r = ra.rumore_fonte(args.provincia, classe, args.residenza, anni)
        t = r["tvd_orario"]
        print(f"{classe:10} {t.get('Giorno feriale', float('nan')):>9.4f} "
              f"{t.get('Sabato', float('nan')):>7.4f} "
              f"{t.get('Domenica', float('nan')):>7.4f} "
              f"{r['l1_mensile']:>9.4f} {r['scarto_livello_pct']:>7.1f}%")

    if aggregato is not None:
        print("\nFASCE ORARIE (% del consumo annuo)")
        quote = fasce_profilo(aggregato)
        print(f"  aggregato dei domestici   "
              f"F1 {quote.get('f1', 0):5.2f}  F2 {quote.get('f2', 0):5.2f}  "
              f"F3 {quote.get('f3', 0):5.2f}")
        for classe in sorted(set(assegnazione.values())):
            fa = ra.fasce(args.provincia, classe, args.residenza, anni).mean()
            print(f"  ARERA classe {classe:12} "
                  f"F1 {fa['f1']:5.2f}  F2 {fa['f2']:5.2f}  F3 {fa['f3']:5.2f}")

        print("\nFORMA ORARIA FERIALE, % del giorno (aggregato contro ARERA)")
        feriali = _senza_festivi(aggregato)
        feriali = feriali[feriali.index.weekday < 5]
        curva = feriali.groupby(feriali.index.hour).mean()
        curva = curva / curva.sum() * 100
        classe_riferimento = sorted(set(assegnazione.values()))[0]
        rif = curva_arera(args.provincia, classe_riferimento, args.residenza,
                          anni, "Giorno feriale") * 100
        print("  ora  " + "".join(f"{h:5d}" for h in range(24)))
        print("  LPG  " + "".join(f"{v:5.2f}" for v in curva))
        print(f"  {classe_riferimento:5}" + "".join(f"{v:5.2f}" for v in rif))
        print(f"  picco LPG ore {int(curva.idxmax()):02d}, "
              f"picco ARERA ore {int(rif.idxmax()):02d}")

    print("\nLe curve ARERA orarie coprono i soli clienti trattati orari; la classe")
    print("di potenza di ciascuna famiglia e' un'assunzione dichiarata, non un dato.")
    print("Se la forma non combacia si corregge il catalogo, mai l'output.")


if __name__ == "__main__":
    main()
