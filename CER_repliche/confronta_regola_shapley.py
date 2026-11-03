"""Effetto della regola "Shapley esatto fino a 18 membri, AS oltre" su un run unito.

Confronta due cartelle di tabelle di MAIN2 sulle stesse comunita':
  prima  analisi con i soli metodi comuni a tutte le comunita' (AS ovunque, nessuno Shapley
         esatto), per esempio outputs/tables_main2_fino25_unito
  dopo   la stessa analisi dopo unisci_shapley_as (un solo "Shapley": esatto fino a 18 membri,
         AS oltre), per esempio outputs/repliche/prova_regola_shapley/tables
Nel "prima" l'AS si legge come Shapley, quindi cambia solo chi vince dove l'esatto e l'AS
differiscono.

Riporta: celle in cui cambia l'insieme dei primi a pari merito (griglia_vincitori.csv di tutti
i livelli), scarto del tau medio per fascia, scarti di perdite di trade-off e rimpianto.

Uso:  python -I CER_repliche/confronta_regola_shapley.py <prima> <dopo>
"""
from __future__ import annotations

import sys
from collections import Counter
from pathlib import Path

import pandas as pd

AS, SH = "Adaptive Sampling Shapley", "Shapley"


def primi(s, rinomina):
    return frozenset(SH if (rinomina and x == AS) else x for x in str(s).split(" = "))


def main(prima: Path, dopo: Path) -> None:
    tot, cambi = 0, []
    for f in sorted(prima.rglob("griglia_vincitori.csv")):
        a, b = pd.read_csv(f), pd.read_csv(dopo / f.relative_to(prima))
        m = a.merge(b, on=["Indicatore", "Membri", "Fascia"], suffixes=("_a", "_b"))
        assert len(m) == len(a) == len(b), f
        pa = m["PrimiAPari_a"].map(lambda s: primi(s, True))
        pb = m["PrimiAPari_b"].map(lambda s: primi(s, False))
        tot += len(m)
        livello = f.relative_to(prima).parent.parent.name or "PA0"
        for _, r in m[pa != pb].iterrows():
            cambi.append((livello, r.Indicatore, r.Membri, r.Fascia, r.PrimiAPari_a, r.PrimiAPari_b))
    print(f"Vincitori: cambia l'insieme dei primi in {len(cambi)} celle su {tot} "
          f"({100 * len(cambi) / tot:.1f}%)")
    print("  per indicatore:", dict(Counter(c[1] for c in cambi)))
    print("  per taglia:    ", dict(sorted(Counter(c[2] for c in cambi).items())))
    for c in cambi:
        print("  ", " | ".join(map(str, c)))

    a = pd.read_csv(prima / "sintesi/tau_per_fascia.csv")
    b = pd.read_csv(dopo / "sintesi/tau_per_fascia.csv")
    m = a.merge(b, on=["IndicatoreA", "IndicatoreB", "Fascia"], suffixes=("_a", "_b"))
    d = (m.TauMedio_b - m.TauMedio_a).abs()
    segni = ((m.TauMedio_a > 0) != (m.TauMedio_b > 0)) & \
            (m[["TauMedio_a", "TauMedio_b"]].abs().min(axis=1) > 0.05)
    print(f"\nTau medio per fascia: {len(m)} coppie x fascia, scarto massimo {d.max():.3f}, "
          f"segni cambiati (|tau| > 0,05) {int(segni.sum())}")

    for nome, col in [("sintesi/perdite_tradeoff.csv", "PerditaOttimistica_medio"),
                      ("sintesi/rimpianto_medio.csv", "Rimpianto_medio")]:
        a = pd.read_csv(prima / nome).replace({AS: SH})
        b = pd.read_csv(dopo / nome)
        chiavi = [c for c in a.columns if not pd.api.types.is_numeric_dtype(a[c])]
        m = a.merge(b, on=chiavi, suffixes=("_a", "_b"))
        assert len(m) == len(a) == len(b), nome
        print(f"{nome}: {col} scarto massimo {(m[col + '_b'] - m[col + '_a']).abs().max():.4f}")

    print("\nMetodi nell'analisi (prima):", sorted(pd.read_csv(prima / "sintesi/rimpianto_medio.csv").Metodo.unique()))
    print("Metodi nell'analisi (dopo): ", sorted(pd.read_csv(dopo / "sintesi/rimpianto_medio.csv").Metodo.unique()))


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
