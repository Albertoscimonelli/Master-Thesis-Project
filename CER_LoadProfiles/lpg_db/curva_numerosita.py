"""Separa l'errore di numerosita' del campione dall'errore del modello.

IL PROBLEMA. La validazione confronta l'aggregato delle famiglie generate da
LPG con la curva ARERA di Milano, che e' la media di decine di migliaia di
clienti. Mediare tanti profili individuali attenua fortemente i picchi: se una
famiglia accende il forno alle 20:00 e un'altra alle 21:00, la media mostra un
rialzo largo e basso, non due picchi stretti. L'aggregato di quattro famiglie
non puo' riprodurre quella smussatura, per ragioni statistiche e non di
modello.

Una parte dello scarto fra LPG e ARERA e' quindi NUMEROSITA' DEL CAMPIONE, e
non e' correggibile toccando il catalogo. Inseguirla con le migrazioni
significa tarare quattro famiglie su un bersaglio che quattro famiglie non
possono raggiungere.

IL METODO. Con 20 famiglie generate si calcola la distanza dalla curva ARERA
per sottoinsiemi casuali di dimensione crescente. La distanza attesa fra la
media di N profili e la media di popolazione decresce come 1/sqrt(N), quindi:

    TVD(N) = a + b / sqrt(N)

Il termine b/sqrt(N) e' l'errore di campionamento, che svanisce al crescere di
N. Il termine **a** e' l'errore irriducibile, cioe' quanto il modello resta
distante da ARERA anche con un campione infinito: e' quello, e solo quello, che
si puo' attribuire al catalogo.

COME SI LEGGE IL RISULTATO. Se a e' molto minore del TVD misurato su quattro
famiglie, gran parte dello scarto era numerosita' e il catalogo e' migliore di
quanto sembrasse. Se a e' vicino al TVD osservato, la numerosita' non
c'entrava e il difetto e' del modello.

AVVERTENZE.

  1. La forma funzionale 1/sqrt(N) vale per medie di variabili indipendenti.
     Le venti famiglie qui non lo sono del tutto: condividono i time limit, che
     sono oggetti globali del catalogo, e provengono da soli quattro archetipi.
     L'estrapolazione va quindi letta come stima, non come misura.
  2. Con 20 famiglie e sottoinsiemi fino a 20, il punto a N=20 ha una sola
     combinazione possibile e quindi varianza nulla: e' il valore piu' preciso
     ma anche quello che ancora il fit.
  3. Il confronto usa un riferimento ARERA composito, pesato secondo
     l'assegnazione di classe di potenza delle famiglie. Quell'assegnazione e'
     un'assunzione dichiarata, non un dato.

Uso:
    python curva_numerosita.py ../outputs/csv_campione20/profili_tutti.csv
"""

from __future__ import annotations

import argparse
import itertools
import sys
from pathlib import Path

import numpy as np
import pandas as pd

from confronta_profili import carica
from valida_domestici import CLASSI_PREDEFINITE, _senza_festivi, curva_arera, tvd
import riferimento_arera as ra

# Numero di sottoinsiemi casuali estratti per ciascuna dimensione. Con 20
# famiglie le combinazioni possibili sono molte (184.756 per N=10), quindi si
# campiona invece di enumerare.
ESTRAZIONI = 400

# Seed fisso: il risultato deve essere riproducibile come tutto il resto della
# pipeline.
SEED = 20260902


def classe_di(colonna: str, assegnazione: dict[str, str]) -> str:
    """Classe di potenza di una colonna household_N del campione allargato.

    Le venti famiglie sono cinque copie di ciascuno dei quattro archetipi, in
    ordine: household_1..5 il primo archetipo, 6..10 il secondo, e cosi' via.
    La classe segue quella dell'archetipo corrispondente nella configurazione
    principale.
    """
    indice = int(colonna.replace("household_", "").replace("_kWh", ""))
    archetipo = (indice - 1) // 5  # 0..3
    return list(assegnazione.values())[archetipo]


def riferimento_composito(provincia: str, classi: list[str], residenza: str,
                          anni: tuple[int, ...], giorno: str) -> pd.Series:
    """Curva ARERA media delle classi presenti, pesata sul numero di famiglie.

    Confrontare un aggregato che mescola classi con la curva di una sola classe
    sarebbe mal posto: si costruisce invece la media pesata delle curve delle
    classi effettivamente rappresentate.
    """
    pesi = pd.Series(classi).value_counts(normalize=True)
    composita = None
    for classe, peso in pesi.items():
        curva = curva_arera(provincia, classe, residenza, anni, giorno) * peso
        composita = curva if composita is None else composita + curva
    return composita / composita.sum()


def curva_feriale(serie: pd.Series) -> pd.Series:
    """Giornata feriale media normalizzata a somma unitaria."""
    feriali = _senza_festivi(serie)
    feriali = feriali[feriali.index.weekday < 5]
    curva = feriali.groupby(feriali.index.hour).mean()
    return curva / curva.sum()


def analizza(df: pd.DataFrame, provincia: str, residenza: str,
             anni: tuple[int, ...], giorno: str = "Giorno feriale") -> pd.DataFrame:
    """Distanza da ARERA per sottoinsiemi di dimensione crescente."""
    colonne = [c for c in df.columns if c.startswith("household_")]
    if len(colonne) < 8:
        sys.exit(f"Servono almeno 8 famiglie, trovate {len(colonne)}. "
                 f"Questo script va usato sul campione allargato.")

    classi = {c: classe_di(c, CLASSI_PREDEFINITE) for c in colonne}
    rng = np.random.default_rng(SEED)

    righe = []
    dimensioni = [n for n in (2, 4, 6, 8, 10, 12, 16, 20) if n <= len(colonne)]
    for n in dimensioni:
        possibili = len(list(itertools.combinations(range(len(colonne)), n)))
        prove = min(ESTRAZIONI, possibili)
        valori = []
        for _ in range(prove):
            scelte = list(rng.choice(colonne, size=n, replace=False))
            aggregato = df[scelte].sum(axis=1)
            rif = riferimento_composito(provincia, [classi[c] for c in scelte],
                                        residenza, anni, giorno)
            valori.append(tvd(curva_feriale(aggregato), rif))
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
    """Adatta TVD(N) = a + b/sqrt(N) e restituisce l'errore irriducibile a."""
    n = tabella.index.to_numpy(dtype=float)
    y = tabella["TVD medio"].to_numpy()
    x = 1.0 / np.sqrt(n)
    b, a = np.polyfit(x, y, 1)
    residuo = y - (a + b * x)
    return {"a": float(a), "b": float(b),
            "residuo_max": float(np.max(np.abs(residuo)))}


def varianza_entro_archetipo(df: pd.DataFrame) -> pd.DataFrame:
    """Quanto differiscono fra loro i cloni di uno stesso archetipo.

    E' il controllo che decide se l'analisi di numerosita' abbia senso. Le
    cinque copie di un archetipo hanno semi diversi ma la stessa composizione
    familiare: se producono curve orarie sovrapponibili, venti famiglie sono in
    realta' quattro profili ripetuti cinque volte, non smussano nulla, e il
    fit a + b/sqrt(N) va letto al contrario.

    Il totale annuo non basta a rispondere: il seme puo' spostare QUANDO
    accadono le cose lasciando invariato QUANTO, ed e' proprio lo spostamento
    che smussa i picchi. Si confrontano quindi le curve orarie normalizzate.

    Returns:
        Una riga per archetipo con la distanza media e massima fra le coppie di
        cloni, piu' lo scarto sul totale annuo per confronto.
    """
    colonne = [c for c in df.columns if c.startswith("household_")]
    etichette = list(CLASSI_PREDEFINITE)
    righe = []
    for k in range(0, len(colonne), 5):
        gruppo = colonne[k:k + 5]
        if len(gruppo) < 2:
            continue
        curve = {c: curva_feriale(df[c]) for c in gruppo}
        distanze = [tvd(curve[a], curve[b])
                    for a, b in itertools.combinations(gruppo, 2)]
        totali = np.array([df[c].sum() for c in gruppo])
        nome = etichette[k // 5] if k // 5 < len(etichette) else f"archetipo {k//5+1}"
        righe.append({
            "archetipo": nome,
            "cloni": len(gruppo),
            "TVD medio fra cloni": float(np.mean(distanze)),
            "TVD max fra cloni": float(np.max(distanze)),
            "scarto totale annuo %": float((totali.max() - totali.min())
                                           / totali.mean() * 100),
        })
    return pd.DataFrame(righe).set_index("archetipo")


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("profili", type=Path, help="CSV del campione allargato")
    parser.add_argument("--provincia", default="Milano")
    parser.add_argument("--residenza", default="Residente")
    parser.add_argument("--anni", type=int, nargs="+", default=[2024, 2025])
    args = parser.parse_args()

    if not args.profili.exists():
        sys.exit(f"File non trovato: {args.profili}")

    anni = tuple(args.anni)
    df = carica(args.profili)
    ra.orari(args.provincia, anni)   # popola la cache prima di stampare

    # Prima di tutto: il campione e' davvero un campione? Se i cloni di uno
    # stesso archetipo sono sovrapponibili, l'analisi che segue non misura la
    # numerosita' ma la ripetizione, e va letta al contrario.
    varianza = varianza_entro_archetipo(df)
    print("\nVARIANZA ENTRO ARCHETIPO - il campione e' davvero un campione?\n")
    print(varianza.round(4).to_string())
    tvd_cloni = varianza["TVD medio fra cloni"].mean()
    rumore = ra.rumore_fonte(args.provincia, "1.5-3", args.residenza,
                             anni)["tvd_orario"].get("Giorno feriale", float("nan"))
    print(f"\n  Distanza media fra cloni dello stesso archetipo: {tvd_cloni:.4f}")
    print(f"  Rumore della fonte ARERA fra due anni:            {rumore:.4f}")
    if tvd_cloni < rumore * 2:
        print("\n  ATTENZIONE: i cloni sono quasi indistinguibili fra loro. Venti")
        print("  famiglie sono in realta' quattro profili ripetuti cinque volte:")
        print("  non aggiungono varianza e non smussano i picchi. Il fit che segue")
        print("  restituira' un b vicino a zero e un a vicino al TVD osservato,")
        print("  ma cio' NON significa che lo scarto sia tutto di modello:")
        print("  significa che questo campione non puo' rispondere alla domanda.")
        print("  Servirebbe varianza vera, cioe' composizioni familiari diverse")
        print("  (ByPersons o ByTemplateName) invece di semi diversi.")

    tabella = analizza(df, args.provincia, args.residenza, anni)

    print(f"\nERRORE DI NUMEROSITA' CONTRO ERRORE DI MODELLO")
    print(f"{args.profili.name} - ARERA {args.provincia}, {args.residenza}, "
          f"anni {' e '.join(map(str, anni))}, giorno feriale\n")
    print(tabella.round(4).to_string())

    fit = estrapola(tabella)
    print(f"\nEstrapolazione  TVD(N) = a + b/sqrt(N)")
    print(f"  a (errore irriducibile, modello) = {fit['a']:.4f}")
    print(f"  b (errore di campionamento)      = {fit['b']:.4f}")
    print(f"  residuo massimo del fit          = {fit['residuo_max']:.4f}")

    a_quattro = tabella.loc[4, "TVD medio"] if 4 in tabella.index else float("nan")
    if not np.isnan(a_quattro) and a_quattro > 0:
        quota = fit["a"] / a_quattro * 100
        print(f"\n  Con quattro famiglie il TVD medio vale {a_quattro:.4f}.")
        print(f"  La parte attribuibile al MODELLO e' {quota:.0f}% di quel valore;")
        print(f"  il resto e' numerosita' del campione e non si corregge")
        print(f"  toccando il catalogo.")

    print(f"\n  Rumore della fonte (ARERA 2024 contro 2025), come riferimento:")
    for classe in sorted(set(CLASSI_PREDEFINITE.values())):
        r = ra.rumore_fonte(args.provincia, classe, args.residenza, anni)
        print(f"    classe {classe:8s} TVD feriale "
              f"{r['tvd_orario'].get('Giorno feriale', float('nan')):.4f}")

    print("\nLa forma 1/sqrt(N) vale per medie di variabili indipendenti. Le")
    print("famiglie qui condividono i time limit del catalogo e provengono da")
    print("quattro soli archetipi: l'estrapolazione e' una stima, non una misura.")


if __name__ == "__main__":
    main()
