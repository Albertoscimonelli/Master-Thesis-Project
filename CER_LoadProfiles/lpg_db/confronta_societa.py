"""Confronta due societa' generate con composizioni familiari diverse.

Serve a rispondere alla domanda 3 del §12.5 del report: quanto pesa, sui
profili e quindi sui risultati della CER, la scelta fra una composizione
lombarda e una milanese.

Le due configurazioni differiscono SOLO per le venti famiglie: anno, meteo,
quota di raffrescamento, house type di base ed energy intensity sono identici.
Ogni differenza misurata qui e' quindi attribuibile alla composizione.

Metriche riportate, per ciascuna societa' e in confronto:

  livello       kWh/anno dell'aggregato e per famiglia, contro il bersaglio
                ARERA composito pesato sulle classi di potenza presenti
  forma         TVD dell'aggregato contro ARERA, giorno feriale
  fasce         F1/F2/F3, che sono la grandezza che la CER ripartisce
  eterogeneita' distanza media fra le forme delle famiglie: e' la premessa
                della domanda di ricerca, non un dettaglio di validazione
  ore           la giornata feriale media, per vedere DOVE stanno le
                differenze e non solo quanto valgono

Uso:
    python confronta_societa.py \
        ../outputs/csv_lombardia20/profili_tutti.csv ../config/simulation_config.lombardia20.yaml \
        ../outputs/csv_milano20/profili_tutti.csv    ../config/simulation_config.milano20.yaml
"""

from __future__ import annotations

import argparse
import itertools
import sys
from pathlib import Path

import numpy as np
import pandas as pd

from confronta_profili import carica
from valida_domestici import (_senza_festivi, composizione_da_config,
                              curva_arera, fasce_profilo, tvd)
from curva_numerosita import curva_feriale, riferimento_composito
import riferimento_arera as ra


def _colonne(df: pd.DataFrame) -> list[str]:
    return [c for c in df.columns if c.startswith("household_")]


def misura(percorso_csv: Path, percorso_config: Path, provincia: str,
           residenza: str, anni: tuple[int, ...]) -> dict:
    """Tutte le metriche di una societa'."""
    df = carica(percorso_csv)
    comp = composizione_da_config(percorso_config)
    colonne = _colonne(df)

    classi = [comp[c.replace("_kWh", "")]["classe"] for c in colonne]
    aggregato = df[colonne].sum(axis=1)

    rif = riferimento_composito(provincia, classi, residenza, anni,
                                "Giorno feriale")
    curva = curva_feriale(aggregato)

    # Bersaglio di livello: media dei livelli ARERA delle classi presenti.
    atteso = float(np.mean([
        ra.livello_annuo(provincia, cl, residenza, anni).mean() for cl in classi
    ]))
    kwh = float(aggregato.sum())

    curve = {c: curva_feriale(df[c]) for c in colonne}
    distanze = [tvd(curve[a], curve[b])
                for a, b in itertools.combinations(colonne, 2)]

    return {
        "famiglie": len(colonne),
        "kwh_totale": kwh,
        "kwh_per_famiglia": kwh / len(colonne),
        "atteso_per_famiglia": atteso,
        "tvd": tvd(curva, rif),
        "curva": curva,
        "riferimento": rif,
        "fasce": fasce_profilo(aggregato),
        "eterogeneita": float(np.mean(distanze)),
        "eterogeneita_min": float(np.min(distanze)),
        "eterogeneita_max": float(np.max(distanze)),
        "classi": pd.Series(classi).value_counts().to_dict(),
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("csv_a", type=Path)
    parser.add_argument("config_a", type=Path)
    parser.add_argument("csv_b", type=Path)
    parser.add_argument("config_b", type=Path)
    parser.add_argument("--nomi", nargs=2, default=["A", "B"])
    parser.add_argument("--provincia", default="Milano")
    parser.add_argument("--residenza", default="Residente")
    parser.add_argument("--anni", type=int, nargs="+", default=[2024, 2025])
    args = parser.parse_args()

    for p in (args.csv_a, args.config_a, args.csv_b, args.config_b):
        if not p.exists():
            sys.exit(f"File non trovato: {p}")

    anni = tuple(args.anni)
    ra.orari(args.provincia, anni)
    na, nb = args.nomi
    a = misura(args.csv_a, args.config_a, args.provincia, args.residenza, anni)
    b = misura(args.csv_b, args.config_b, args.provincia, args.residenza, anni)

    print(f"\nCONFRONTO FRA SOCIETA' - ARERA {args.provincia}, {args.residenza}, "
          f"anni {' e '.join(map(str, anni))}\n")
    print(f"{'':32} {na:>14} {nb:>14}   differenza")
    print("-" * 78)

    def riga(etichetta, va, vb, fmt="{:.4f}", diff=True):
        d = f"{vb - va:+.4f}" if diff else ""
        print(f"{etichetta:32} {fmt.format(va):>14} {fmt.format(vb):>14}   {d}")

    riga("famiglie", a["famiglie"], b["famiglie"], "{:.0f}", False)
    riga("kWh/anno per famiglia", a["kwh_per_famiglia"], b["kwh_per_famiglia"],
         "{:,.0f}", False)
    riga("bersaglio ARERA per famiglia", a["atteso_per_famiglia"],
         b["atteso_per_famiglia"], "{:,.0f}", False)
    print(f"{'scarto di livello':32} {a['kwh_per_famiglia']/a['atteso_per_famiglia']:>13.2f}x "
          f"{b['kwh_per_famiglia']/b['atteso_per_famiglia']:>13.2f}x")
    print()
    riga("TVD feriale contro ARERA", a["tvd"], b["tvd"])
    riga("eterogeneita' di forma (media)", a["eterogeneita"], b["eterogeneita"])
    riga("  minima fra due famiglie", a["eterogeneita_min"], b["eterogeneita_min"])
    riga("  massima fra due famiglie", a["eterogeneita_max"], b["eterogeneita_max"])
    print()
    for f in ("f1", "f2", "f3"):
        riga(f"fascia {f.upper()} (% annuo)", a["fasce"].get(f, 0),
             b["fasce"].get(f, 0), "{:.2f}")

    print("\nDISTANZA FRA LE DUE SOCIETA'")
    print(f"  TVD fra le due curve feriali: {tvd(a['curva'], b['curva']):.4f}")
    print(f"  (rumore della fonte ARERA fra due anni: "
          f"{ra.rumore_fonte(args.provincia, '1.5-3', args.residenza, anni)['tvd_orario'].get('Giorno feriale', float('nan')):.4f})")

    print("\nGIORNATA FERIALE MEDIA, % del giorno")
    ore = range(24)
    print("  ora   " + " ".join(f"{o:5d}" for o in ore))
    for nome, d in ((na, a["curva"]), (nb, b["curva"]), ("ARERA", a["riferimento"])):
        print(f"  {nome[:5]:5} " + " ".join(f"{d.get(o, 0) * 100:5.2f}" for o in ore))

    print("\n  differenza (B - A), punti percentuali")
    diff = (b["curva"] - a["curva"]) * 100
    print("  " + " ".join(f"{diff.get(o, 0):+5.2f}" for o in ore))


if __name__ == "__main__":
    main()
