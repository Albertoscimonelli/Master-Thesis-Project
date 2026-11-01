"""Tabelle ed export di tutte le repliche in una cartella sola, per grafici_metodi.py (passo 5).

grafici_metodi.py descrive UN run: una comunita' e' una scheda. Per descrivere tutte le comunita'
di tutte le repliche senza toccarne il codice, qui si mettono insieme le tabelle che legge
(sintesi/rimpianto_per_comunita.csv, sintesi/quote_prosumer.csv, sintesi/tau_per_cella.csv di
ogni livello, confronto_PA/pa_effetti.csv) e i 5 CSV di export/, con la replica nel nome della
scheda ("r07:CER_0_20_0"). Cosi' ogni comunita' di ogni replica e' un punto delle figure, la
fascia si calcola come sempre (le schede di repliche diverse hanno la stessa penetrazione) e
le distribuzioni descrivono configurazioni E partecipanti. Solo le repliche >= 1; i metodi
seguono la versione B (stile_tesi.un_solo_shapley).

Uso:  python -I CER_repliche/unisci_per_figure.py [--radice outputs/repliche] [--blocco unito]
      -> <radice>/<blocco>/insieme/{tables,export}
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
from stile_tesi import un_solo_shapley  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
TABELLE = ["sintesi/rimpianto_per_comunita.csv", "sintesi/quote_prosumer.csv", "sintesi/tau_per_cella.csv"]
EXPORT = ["comunita.csv", "tfair_lungo.csv", "punteggi_orientati.csv", "quote_membri.csv", "virtuosita.csv"]


def con_replica(d: pd.DataFrame, r: int) -> pd.DataFrame:
    d = d.copy()
    d["Scheda"] = f"r{r:02d}:" + d.Scheda.astype(str)
    return d


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--radice", default=str(ROOT / "outputs" / "repliche"))
    ap.add_argument("--blocco", default="unito")
    a = ap.parse_args(argv)
    cart = Path(a.radice) / a.blocco
    rep = sorted(int(d.name[1:]) for d in cart.glob("r[0-9][0-9]")
                 if (d / "tables").is_dir() and (d / "export").is_dir() and int(d.name[1:]) >= 1)
    if not rep:
        raise SystemExit(f"nessuna replica >= 1 con tables/ ed export/ in {cart}")
    dest = cart / "insieme"
    if dest.exists():
        shutil.rmtree(dest)
    t0 = cart / f"r{rep[0]:02d}" / "tables"
    livelli = [""] + sorted(d.name for d in t0.iterdir() if (d / "sintesi").is_dir())
    for lv in livelli:
        for rel in TABELLE:
            parti = [con_replica(pd.read_csv(p), r) for r in rep
                     if (p := cart / f"r{r:02d}" / "tables" / lv / rel).exists()]
            if parti:
                f = dest / "tables" / lv / rel
                f.parent.mkdir(parents=True, exist_ok=True)
                un_solo_shapley(pd.concat(parti, ignore_index=True), ("Scheda",)).to_csv(f, index=False)
    parti = [con_replica(pd.read_csv(p), r) for r in rep
             if (p := cart / f"r{r:02d}" / "tables" / "confronto_PA" / "pa_effetti.csv").exists()]
    if parti:
        f = dest / "tables" / "confronto_PA" / "pa_effetti.csv"
        f.parent.mkdir(parents=True, exist_ok=True)
        un_solo_shapley(pd.concat(parti, ignore_index=True), ("Livello", "Scheda")).to_csv(f, index=False)
    (dest / "export").mkdir(parents=True)
    for nome in EXPORT:
        d = pd.concat([con_replica(pd.read_csv(cart / f"r{r:02d}" / "export" / nome), r) for r in rep],
                      ignore_index=True)
        d = un_solo_shapley(d, ("Composizione", "Scheda"))
        d.to_csv(dest / "export" / nome, index=False)
    print(f"{len(rep)} repliche, {len(livelli)} livelli in {dest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
