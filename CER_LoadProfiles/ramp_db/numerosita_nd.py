"""Separa l'errore di numerosita' del campione dall'errore di modello.

IL PROBLEMA. La validazione confronta un archetipo con un riferimento che e' la
media di una popolazione: i profili standard GSE valgono per l'intera categoria
"altri usi". Mediare molti profili individuali attenua i picchi - se un ufficio
accende il clima alle 9:00 e un altro alle 10:00, la media mostra un rialzo
largo e basso, non due picchi stretti - e una sola istanza non puo' riprodurre
quella smussatura, per ragioni statistiche e non di modello.

Una parte dello scarto misurato da valida_non_domestici.py e' quindi
NUMEROSITA' DEL CAMPIONE, e non e' correggibile toccando l'archetipo.
Inseguirla vuol dire tarare una istanza su un bersaglio che una istanza non
puo' raggiungere.

IL METODO, lo stesso di lpg_db/curva_numerosita.py. Con venti istanze generate
si calcola la distanza dal riferimento per sottoinsiemi casuali di dimensione
crescente. La distanza attesa fra la media di N profili e la media di
popolazione decresce come 1/sqrt(N), quindi:

    TVD(N) = a + b / sqrt(N)

Il termine b/sqrt(N) e' l'errore di campionamento, che svanisce al crescere di
N. Il termine **a** e' l'errore irriducibile: quanto l'archetipo resta distante
dal riferimento anche con un campione infinito. E' quello, e solo quello, che
si puo' attribuire al modello.

COME SI LEGGE. Si confronta "a" con la TVD misurata su UNA istanza, che e'
quella che valida_non_domestici.py riporta. Se a e' molto minore, gran parte
dello scarto era numerosita' e l'archetipo e' migliore di quanto sembrasse. Se
a le e' vicino, la numerosita' non c'entrava e il difetto e' del modello.

PERCHE' QUI LA CURVA E' MEGLIO POSTA CHE SUL LATO DOMESTICO. La prima
avvertenza del gemello domestico - le venti famiglie non sono indipendenti,
perche' condividono i time limit del catalogo e provengono da soli quattro
archetipi - QUI NON SI APPLICA: num_users: 20 produce venti istanze dello
STESSO archetipo, che differiscono solo per il seed. E' esattamente l'ipotesi
che la forma 1/sqrt(N) presuppone.

Restano due avvertenze:

  1. Con venti istanze e sottoinsiemi fino a venti, il punto a N=20 ha una sola
     combinazione possibile e quindi varianza nulla: e' il valore piu' preciso
     ma anche quello che ancora il fit.
  2. Il riferimento GSE e' UNO SOLO per tutta la categoria "altri usi" e ignora
     il giorno della settimana. L'errore irriducibile "a" contiene quindi anche
     la distanza fra l'archetipo specifico e quella media di categoria, che non
     e' un difetto dell'archetipo. Va detto accanto al numero.

N=1 SI MISURA MA NON ENTRA NEL FIT. Serve come termine di paragone - e' la
grandezza che il validatore riporta - ma la forma 1/sqrt(N) e' meno affidabile
proprio nel punto piu' estremo, e lasciarla dentro spingerebbe l'intercetta.

Uso:
    python numerosita_nd.py ../outputs/csv_nd20/profili_nd20.csv
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "lpg_db"))
from confronta_profili import carica  # noqa: E402
from valida_domestici import tvd  # noqa: E402

from valida_non_domestici import GIORNI, curva_gse, curva_oraria  # noqa: E402

# Numero di sottoinsiemi casuali estratti per ciascuna dimensione, lo stesso
# del gemello domestico: con venti istanze le combinazioni possibili sono molte
# (184.756 per N=10), quindi si campiona invece di enumerare.
ESTRAZIONI = 400

# Seed fisso: il risultato deve essere riproducibile come tutto il resto della
# pipeline.
SEME = 42

# Il punto a N=1 si misura ma non entra nel fit (vedi docstring).
DIMENSIONI = (1, 2, 4, 6, 8, 10, 12, 16, 20)


def archetipi(df: pd.DataFrame) -> dict[str, list[str]]:
    """Raggruppa le colonne per archetipo, togliendo indice e suffisso _kWh."""
    gruppi: dict[str, list[str]] = {}
    for colonna in df.columns:
        nome = re.sub(r"_\d+(_kWh)?$", "", colonna)
        if nome != colonna:
            gruppi.setdefault(nome, []).append(colonna)
    return gruppi


def curva_numerosita(df: pd.DataFrame, colonne: list[str], anno: int) -> pd.DataFrame:
    """TVD dal riferimento GSE per sottoinsiemi di dimensione crescente."""
    rng = np.random.default_rng(SEME)
    riferimento = curva_gse(anno, GIORNI["lun-ven"])

    righe = []
    for n in [d for d in DIMENSIONI if d <= len(colonne)]:
        if n == len(colonne):
            prove = 1          # un solo sottoinsieme possibile
        else:
            prove = ESTRAZIONI
        valori = []
        for _ in range(prove):
            scelte = list(rng.choice(colonne, size=n, replace=False))
            aggregato = df[scelte].sum(axis=1)
            valori.append(tvd(curva_oraria(aggregato, GIORNI["lun-ven"]),
                              riferimento))
        righe.append({
            "N": n,
            "estrazioni": prove,
            "TVD medio": float(np.mean(valori)),
            "TVD min": float(np.min(valori)),
            "TVD max": float(np.max(valori)),
            "dev.std": float(np.std(valori)),
        })
    return pd.DataFrame(righe).set_index("N")


def estrapola(tabella: pd.DataFrame) -> dict:
    """Adatta TVD(N) = a + b/sqrt(N) e restituisce l'errore irriducibile a.

    Il punto a N=1 viene escluso: e' il piu' estremo, e' quello in cui la forma
    funzionale e' meno affidabile, e lasciarlo dentro spingerebbe l'intercetta
    verso l'alto facendo sembrare l'archetipo peggiore di quanto sia.
    """
    usabili = tabella[tabella.index > 1]
    if len(usabili) < 3:
        sys.exit("Servono almeno tre dimensioni oltre N=1 per adattare la curva.")
    n = usabili.index.to_numpy(dtype=float)
    y = usabili["TVD medio"].to_numpy()
    x = 1.0 / np.sqrt(n)
    b, a = np.polyfit(x, y, 1)
    residuo = y - (a + b * x)
    return {"a": float(a), "b": float(b),
            "residuo_max": float(np.max(np.abs(residuo)))}


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("profili", type=Path,
                        help="CSV generato con simulation_config.nd20.yaml")
    parser.add_argument("--anno", type=int, default=2025,
                        help="annualita' dei profili standard GSE di riferimento")
    args = parser.parse_args()

    if not args.profili.exists():
        sys.exit(f"File non trovato: {args.profili}")

    df = carica(args.profili)
    gruppi = archetipi(df)
    if not gruppi:
        sys.exit("Nessun archetipo riconosciuto: attese colonne tipo 'office_1'.")

    print(f"\nCURVA DI NUMEROSITA' - {args.profili.name}")
    print(f"riferimento: profili standard GSE {args.anno}, categoria altri usi\n")

    for nome, colonne in sorted(gruppi.items()):
        tabella = curva_numerosita(df, sorted(colonne), args.anno)
        fit = estrapola(tabella)
        osservato = float(tabella.loc[1, "TVD medio"]) if 1 in tabella.index else float("nan")

        print(f"{nome}  ({len(colonne)} istanze)")
        print(f"  {'N':>3} {'estrazioni':>11} {'TVD medio':>10} {'min':>8} "
              f"{'max':>8} {'dev.std':>8}")
        for n, riga in tabella.iterrows():
            print(f"  {n:>3} {int(riga['estrazioni']):>11} {riga['TVD medio']:>10.4f} "
                  f"{riga['TVD min']:>8.4f} {riga['TVD max']:>8.4f} "
                  f"{riga['dev.std']:>8.4f}")
        print(f"  fit TVD(N) = a + b/sqrt(N):  a = {fit['a']:.4f}   "
              f"b = {fit['b']:.4f}   residuo max {fit['residuo_max']:.4f}")
        quota = (1 - fit["a"] / osservato) * 100 if osservato > 0 else float("nan")
        print(f"  errore di MODELLO a = {fit['a']:.4f} contro {osservato:.4f} "
              f"misurato su una sola istanza:")
        print(f"  la numerosita' del campione spiega il {quota:.0f}% dello scarto "
              f"osservato.\n")

    print("Due cose da tenere presenti leggendo questi numeri:")
    print("  - il riferimento GSE e' uno solo per tutta la categoria 'altri usi'")
    print("    e ignora il giorno della settimana, quindi l'errore irriducibile")
    print("    'a' contiene anche la distanza fra l'archetipo e quella media di")
    print("    categoria, che non e' un difetto dell'archetipo;")
    print("  - il punto a N=20 ha una sola combinazione possibile, quindi")
    print("    varianza nulla: e' il piu' preciso ma e' anche quello che ancora")
    print("    il fit.")


if __name__ == "__main__":
    main()
