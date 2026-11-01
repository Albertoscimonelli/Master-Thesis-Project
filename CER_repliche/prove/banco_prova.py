"""Banco di prova dell'analisi finale, senza MATLAB e senza aspettare la fine del run.

Costruisce una finta cartella di blocco "unito" con N repliche, nella forma che scrivera'
unisci_repliche.sh, partendo solo da file versionati:
  - export/: i CSV veri delle repliche (fino15 + da18 + da20a25 della stessa replica, dove ci
    sono tutti e tre i blocchi), cosi' le parti che leggono gli export lavorano su dati veri;
  - tables/: le tabelle di MAIN2 del run unito del 28 ottobre (tables_main2_fino25_unito),
    uguali per tutte le repliche, con un rumore piccolo su tau, inversioni e perdite perche'
    le statistiche fra repliche non siano degeneri. Servono a provare il CODICE, non i numeri;
  - workspace.mat: un file vuoto (aggrega_repliche.py ne controlla solo l'esistenza).

Uso:  python -I CER_repliche/prove/banco_prova.py --dest /tmp/banco --repliche 0-6
poi:  python -I CER_repliche/aggrega_repliche.py --blocco unito --radice /tmp/banco --attese 7
"""
from __future__ import annotations

import argparse
import shutil
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
REP = ROOT / "outputs" / "repliche"
TAB = ROOT / "outputs" / "tables_main2_fino25_unito"
EXPORT = ["comunita.csv", "tfair_lungo.csv", "punteggi_orientati.csv", "quote_membri.csv", "virtuosita.csv"]
RUMORE = {  # file -> colonne da perturbare (in [-1, 1] o [0, 1])
    "sintesi/tau_per_fascia.csv": ["TauMedio"],
    "confronto/inversioni_per_sweep.csv": ["QuotaInvertite"],
    "sintesi/perdite_tradeoff.csv": ["PerditaOttimistica_medio"],
    "sintesi/rimpianto_per_comunita.csv": ["Rimpianto"],
}


def intervallo(s: str) -> list[int]:
    a, _, b = s.partition("-")
    return list(range(int(a), int(b or a) + 1))


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", required=True)
    ap.add_argument("--repliche", default="0-6")
    a = ap.parse_args(argv)
    dest = Path(a.dest) / "unito"
    if dest.exists():
        shutil.rmtree(dest)
    for r in intervallo(a.repliche):
        nn = f"r{r:02d}"
        blocchi = [REP / b / nn / "export" for b in ("fino15", "da18", "da20a25")]
        if not all(b.is_dir() for b in blocchi):
            print(f"{nn}: manca un blocco negli export versionati, salto")
            continue
        out = dest / nn
        (out / "export").mkdir(parents=True)
        for f in EXPORT:
            pd.concat([pd.read_csv(b / f) for b in blocchi]).to_csv(out / "export" / f, index=False)
        shutil.copytree(TAB, out / "tables")
        rng = np.random.default_rng(1000 + r)
        for rel, cols in RUMORE.items():
            for p in [out / "tables" / rel] + list((out / "tables").glob(f"*/{rel}")):
                if not p.exists():
                    continue
                d = pd.read_csv(p)
                for c in cols:
                    lo = -1 if c == "TauMedio" else 0
                    d[c] = (d[c] + rng.normal(0, 0.08, len(d))).clip(lo, 1)
                d.to_csv(p, index=False)
        (out / "workspace.mat").write_bytes(b"")
        print(f"{nn}: pronto")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
