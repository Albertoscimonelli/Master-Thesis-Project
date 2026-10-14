"""Confronto per chiave di due cartelle tables_main2.
Uso: python -I confronta_csv.py <prima> <dopo> <token che autorizza il cambiamento>...
Una riga puo' cambiare solo se contiene uno dei token (es. VAN_min_EUR)."""
import sys
from pathlib import Path
import pandas as pd

prima, dopo, tokens = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3:]
violazioni = 0
for f in sorted(prima.rglob("*.csv")):
    rel = f.relative_to(prima)
    g = dopo / rel
    if not g.exists():
        print(f"MANCA        {rel}")
        violazioni += 1
        continue
    if f.read_bytes() == g.read_bytes():
        print(f"IDENTICO     {rel}")
        continue
    a, b = pd.read_csv(f, dtype=str), pd.read_csv(g, dtype=str)
    if list(a.columns) != list(b.columns):
        print(f"COLONNE      {rel}: {list(a.columns)} -> {list(b.columns)}")
        violazioni += 1
        continue
    autorizzata = lambda d: d.apply(lambda r: any(t in " ".join(r.astype(str)) for t in tokens), axis=1)
    a_fix, b_fix = a[~autorizzata(a)], b[~autorizzata(b)]
    sa = set(map(tuple, a_fix.fillna("").values))
    sb = set(map(tuple, b_fix.fillna("").values))
    solo_a, solo_b = sa - sb, sb - sa
    n_aut = int(autorizzata(a).sum())
    if solo_a or solo_b:
        violazioni += 1
        print(f"VIOLAZIONE   {rel}: {len(solo_a)} righe sparite, {len(solo_b)} nuove fuori dai token")
        for r in list(solo_a)[:3]:
            print("     -", r)
        for r in list(solo_b)[:3]:
            print("     +", r)
    else:
        print(f"OK (atteso)  {rel}: cambiano solo righe con {tokens} ({n_aut} righe autorizzate; "
              f"righe {len(a)} -> {len(b)})")
print(f"\nVIOLAZIONI: {violazioni}")
