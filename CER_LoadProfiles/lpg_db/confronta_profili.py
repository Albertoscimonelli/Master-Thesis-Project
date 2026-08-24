"""Confronta due set di profili di carico con la metrica 'Profildifferenz'.

La metrica e' definita da Pflugradt nella tesi che descrive LoadProfileGenerator
(sezione sulla valutazione delle modifiche al modello):

  1. per ogni profilo si calcolano 9 curve medie giornaliere, una per ogni
     combinazione di tipo di giorno (lun-ven, sabato, domenica) e stagione
     (estate, inverno, autunno/primavera);
  2. per ogni passo temporale si fa la differenza fra le curve omologhe dei
     due profili;
  3. le differenze si elevano al quadrato e si sommano.

Il risultato non ha unita' di misura sensata: e' un valore di confronto. Le
soglie di riferimento dell'autore:

  ~12.960           uno spostamento uniforme di 1 kW su tutto il profilo
  10.000 - 30.000   rumore del generatore casuale (stessa configurazione
                    ricalcolata due volte)
  oltre 50.000      differenza reale nel profilo di carico

UNITA'. Il valore 12.960 e' esattamente 9 curve x 1440 minuti x 1, quindi il
contributo di uno scarto di 1 kW e' 1: la metrica si calcola sulle potenze
espresse in kW, non in Watt. Usare i Watt gonfia il risultato di 10^6.

DUE APPROSSIMAZIONI rispetto al calcolo originale, entrambe da tenere presenti
nel leggere il risultato:

  1. L'autore lavora su curve a 1 minuto; qui i profili sono orari. Ogni
     valore orario viene contato 60 volte (MINUTI_PER_ORA) per riportarlo alla
     stessa scala, ma la media oraria appiattisce le differenze infraorarie:
     il valore ottenuto e' quindi una STIMA PER DIFETTO.
  2. Le soglie dell'autore sono calibrate su un intero insediamento. Su poche
     utenze vanno usate come ordine di grandezza, non come test formale.

PERCHE' NON SI USA L'AUTOCONSUMO. La stessa tesi mostra che la quota di
autoconsumo e' una cattiva metrica per giudicare modifiche come le nostre:
anche profili molto diversi variano solo fra il 21% e il 39%, e siccome le
variazioni serali e notturne non vengono catturate affatto, grandi cambiamenti
del profilo si traducono in 1-2 punti percentuali. L'energia condivisa resta il
risultato di interesse della CER, ma non lo strumento per misurare se una
calibrazione ha funzionato.

Uso:
    python confronta_profili.py baseline.csv italiano.csv

I CSV sono quelli prodotti da generate_load_profiles.py (indice temporale
nella prima colonna, una colonna per utenza in kWh/h).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pandas as pd

# Con profili orari ogni valore vale 60 passi da 1 minuto. Il fattore riporta
# la somma sulla stessa scala delle soglie dell'autore, che sono calcolate a
# risoluzione 1 minuto.
MINUTI_PER_ORA = 60

STAGIONI = {
    12: "inverno", 1: "inverno", 2: "inverno",
    6: "estate", 7: "estate", 8: "estate",
    3: "mezza", 4: "mezza", 5: "mezza",
    9: "mezza", 10: "mezza", 11: "mezza",
}

SOGLIA_RUMORE = 30_000
SOGLIA_DIFFERENZA = 50_000


def tipo_giorno(giorno: int) -> str:
    """Mappa il giorno della settimana (0=lunedi) nei tre tipi dell'autore."""
    if giorno == 5:
        return "sabato"
    if giorno == 6:
        return "domenica"
    return "lun-ven"


def curve_medie(serie: pd.Series) -> dict[tuple[str, str], pd.Series]:
    """Calcola le 9 curve medie giornaliere di un profilo.

    Args:
        serie: Serie con DatetimeIndex e valori di potenza media in Watt.

    Returns:
        Dizionario {(stagione, tipo_giorno): curva media indicizzata per ora}.
    """
    df = pd.DataFrame({"valore": serie})
    df["stagione"] = [STAGIONI[t.month] for t in df.index]
    df["giorno"] = [tipo_giorno(t.weekday()) for t in df.index]
    df["ora"] = [t.hour for t in df.index]

    curve = {}
    for (stagione, giorno), gruppo in df.groupby(["stagione", "giorno"]):
        curve[(stagione, giorno)] = gruppo.groupby("ora")["valore"].mean()
    return curve


def profildifferenz(a: pd.Series, b: pd.Series) -> float:
    """Somma dei quadrati delle differenze fra le 9 curve medie di due profili.

    Args:
        a: Profilo di riferimento, in Watt medi.
        b: Profilo da confrontare, in Watt medi.

    Returns:
        Il valore di confronto, riportato alla scala 1 minuto.
    """
    curve_a = curve_medie(a)
    curve_b = curve_medie(b)

    totale = 0.0
    for chiave in sorted(set(curve_a) | set(curve_b)):
        ca = curve_a.get(chiave)
        cb = curve_b.get(chiave)
        if ca is None or cb is None:
            continue
        differenze = (ca - cb).dropna()
        totale += float((differenze**2).sum()) * MINUTI_PER_ORA
    return totale


def carica(percorso: Path) -> pd.DataFrame:
    """Carica un CSV di profili di potenza media oraria, in kW.

    I CSV contengono kWh consumati in ciascuna ora, che numericamente sono
    gia' i kW medi di quell'ora. Non si converte in Watt: la metrica va
    calcolata in kW, altrimenti i valori risultano inflazionati di 10^6
    rispetto alle soglie dell'autore.
    """
    df = pd.read_csv(percorso, index_col=0, parse_dates=True)
    if not isinstance(df.index, pd.DatetimeIndex):
        sys.exit(f"{percorso}: la prima colonna non e' un indice temporale.")
    return df


def giudizio(valore: float) -> str:
    """Ordine di grandezza dello scarto, in unita' di 'spostamento da 1 kW'.

    Non si confronta con le soglie dell'autore in modo diretto: quelle sono
    calibrate su un intero insediamento, e su poche utenze darebbero un falso
    'nessuna differenza'. Si riporta invece il valore alla grandezza che
    l'autore usa come riferimento (12.960 = 1 kW su tutta la giornata), che si
    interpreta senza ambiguita' anche con tre famiglie.
    """
    equivalente = valore / 12_960
    if equivalente < 0.01:
        return "trascurabile"
    return f"~ come uno spostamento di {equivalente:.2f} kW su tutta la giornata"


def diagnostica(base: pd.Series, conf: pd.Series) -> list[str]:
    """Due controlli che discriminano anche a risoluzione oraria.

    La Profildifferenz calcolata su dati orari perde gran parte degli
    spostamenti infraorari. Questi due indicatori invece restano visibili e
    dicono direttamente se le correzioni italiane hanno avuto effetto.
    """
    righe = []

    feriali_b = base[base.index.weekday < 5]
    feriali_c = conf[conf.index.weekday < 5]
    curva_b = feriali_b.groupby(feriali_b.index.hour).mean()
    curva_c = feriali_c.groupby(feriali_c.index.hour).mean()

    sera_b, sera_c = curva_b[16:].idxmax(), curva_c[16:].idxmax()
    righe.append(
        f"  picco serale feriale : ore {sera_b:02d} -> ore {sera_c:02d} "
        f"({sera_c - sera_b:+d} h)"
    )
    mattina_b, mattina_c = curva_b[4:11].idxmax(), curva_c[4:11].idxmax()
    righe.append(
        f"  picco mattutino      : ore {mattina_b:02d} -> ore {mattina_c:02d} "
        f"({mattina_c - mattina_b:+d} h)"
    )

    ago_b = base[base.index.month == 8].sum()
    ago_c = conf[conf.index.month == 8].sum()
    if ago_b:
        righe.append(
            f"  consumo di agosto    : {ago_b:,.0f} -> {ago_c:,.0f} kWh "
            f"({(ago_c - ago_b) / ago_b * 100:+.0f} %)"
        )
    return righe


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path, help="CSV di riferimento")
    parser.add_argument("confronto", type=Path, help="CSV da confrontare")
    args = parser.parse_args()

    for percorso in (args.baseline, args.confronto):
        if not percorso.exists():
            sys.exit(f"File non trovato: {percorso}")

    base = carica(args.baseline)
    conf = carica(args.confronto)

    comuni = [c for c in base.columns if c in conf.columns]
    if not comuni:
        sys.exit(
            "Nessuna colonna in comune fra i due file. Assicurati che i due "
            "run usino le stesse famiglie e lo stesso seed."
        )

    mancanti = set(base.columns) ^ set(conf.columns)
    if mancanti:
        print(f"Attenzione: colonne presenti in un solo file: {sorted(mancanti)}\n")

    print(f"{'utenza':<28} {'kWh/anno base':>14} {'kWh/anno conf':>14} "
          f"{'Profildiff.':>14}   giudizio")
    print("-" * 100)

    for col in comuni:
        valore = profildifferenz(base[col], conf[col])
        # I valori sono kW medi orari: la somma e' gia' in kWh/anno.
        kwh_base = base[col].sum()
        kwh_conf = conf[col].sum()
        print(f"{col:<28} {kwh_base:>14,.0f} {kwh_conf:>14,.0f} "
              f"{valore:>14,.0f}   {giudizio(valore)}")

    print("-" * 100)
    totale = profildifferenz(base[comuni].sum(axis=1), conf[comuni].sum(axis=1))
    print(f"{'AGGREGATO CER':<28} {base[comuni].sum().sum():>14,.0f} "
          f"{conf[comuni].sum().sum():>14,.0f} {totale:>14,.0f}   "
          f"{giudizio(totale)}")

    print()
    print("DIAGNOSTICA sull'aggregato (indicatori robusti alla risoluzione oraria)")
    for riga in diagnostica(base[comuni].sum(axis=1), conf[comuni].sum(axis=1)):
        print(riga)

    print()
    print(f"Riferimento (Pflugradt): 12.960 = spostamento uniforme di 1 kW su "
          f"tutta la giornata.")
    print("Le soglie 10.000-30.000 (rumore) e 50.000 (differenza reale) della "
          "tesi sono")
    print("calibrate su un intero insediamento: su poche utenze non si "
          "applicano cosi' come sono.")
    # Il confronto ha senso solo a seed fisso: senza, si misura il generatore
    # casuale invece della modifica al modello.
    print("Il confronto e' valido solo se i due run hanno usato lo stesso seed.")


if __name__ == "__main__":
    main()
