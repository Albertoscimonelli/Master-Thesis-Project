"""Copia le tabelle di MAIN2 che servono all'analisi in rNN/tabelle/, che si versiona.

Le tabelle complete della lettura unita (outputs/repliche/unito/rNN/tables/, circa 19 MB a
replica) restano sul PC del run. L'analisi fra repliche ne usa una parte (circa 4 MB a replica,
elenco in aggrega_repliche.TABELLE_ANALISI): copiata in rNN/tabelle/ e committata, permette di
rifare aggrega_repliche.py, le figure e i rapporti su qualunque PC, senza MATLAB.

Uso:  python -I CER_repliche/salva_tabelle_analisi.py [--radice outputs/repliche] [--blocco unito]
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from aggrega_repliche import LIVELLO, ROOT, TABELLE_ANALISI  # noqa: E402


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--radice", default=str(ROOT / "outputs" / "repliche"))
    ap.add_argument("--blocco", default="unito")
    a = ap.parse_args(argv)
    fatte = 0
    for d in sorted((Path(a.radice) / a.blocco).glob("r[0-9][0-9]")):
        src = d / "tables"
        if not (src / "sintesi").is_dir():
            continue
        dest = d / "tabelle"
        if dest.exists():
            shutil.rmtree(dest)
        livelli = [src] + [x for x in sorted(src.iterdir()) if x.is_dir() and LIVELLO.match(x.name)]
        n = 0
        for lv in livelli:
            for rel in TABELLE_ANALISI["livello"]:
                f = lv / rel
                if f.exists():
                    out = dest / f.relative_to(src)
                    out.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(f, out)
                    n += 1
        for rel in TABELLE_ANALISI["radice"]:
            if (src / rel).exists():
                (dest / rel).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src / rel, dest / rel)
                n += 1
        fatte += 1
        print(f"{d.name}: {n} tabelle in {dest}")
    if not fatte:
        print("nessuna tables/ da copiare (gia' copiate o non su questo PC): uso tabelle/ se c'e'")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
