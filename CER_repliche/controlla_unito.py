"""Controlli della lettura unita (passo 2 del piano, docs/analisi_finale/).

Per ogni replica di outputs/repliche/unito/rNN/:
  - 295 comunita' (o il numero di --comunita), 16 livelli di composizione;
  - nell'analisi fra comunita' (punteggi_orientati.csv) ci sono i 10 metodi della versione B:
    niente Nucleolo e niente "Adaptive Sampling Shapley";
  - l'eccesso massimo c'e' in tutte le comunita', anche a 20-25 membri;
  - stesse comunita' e stessi metodi in tutte le repliche.
Su r00, se c'e' la prova del 28 ottobre (outputs/repliche/prova_regola_shapley/tables, locale):
  le celle dei vincitori sugli indicatori che non riguardano la stabilita' devono coincidere e il
  tau medio per fascia delle coppie senza indicatori di stabilita' deve restare entro 1e-6. La
  stabilita' a 20-25 membri e' nuova, quindi le parti che la usano possono cambiare.

Esce con codice 1 se un controllo fallisce. Scrive il registro in unito/controlli.txt.
Uso:  python -I CER_repliche/controlla_unito.py [--radice outputs/repliche] [--comunita 295]
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
from stile_tesi import METODI, un_solo_shapley  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
STABILITA = {"EccessoMax_EUR", "CoalizioniInstabili"}


def controlla_replica(d: Path, attese: int, err: list, log: list):
    nome = d.name
    com = pd.read_csv(d / "export" / "comunita.csv")
    po = pd.read_csv(d / "export" / "punteggi_orientati.csv")
    tf = pd.read_csv(d / "export" / "tfair_lungo.csv")
    if len(com) != attese:
        err.append(f"{nome}: {len(com)} comunita' invece di {attese}")
    if com.Composizione.nunique() != 16:
        err.append(f"{nome}: {com.Composizione.nunique()} livelli di composizione invece di 16")
    metodi = set(po.Metodo)
    if metodi != set(METODI):
        err.append(f"{nome}: metodi dell'analisi {sorted(metodi)}, attesi {sorted(METODI)}")
    tf = un_solo_shapley(tf, ("Composizione", "Scheda"))
    vuoti = tf[tf.EccessoMax_EUR.isna()]
    if len(vuoti):
        err.append(f"{nome}: eccesso massimo mancante in {vuoti.Scheda.nunique()} comunita' "
                   f"(taglie {sorted(int(x) for x in vuoti.Membri.unique())})")
    log.append(f"{nome}: {len(com)} comunita', {com.Composizione.nunique()} livelli, "
               f"{len(metodi)} metodi, taglie {sorted(int(x) for x in com.Membri.unique())}")
    return set(zip(com.Composizione, com.Scheda)), metodi


def regressione_r00(nuovo: Path, prova: Path, err: list, log: list):
    def vinc(t):
        parti = [pd.read_csv(p).assign(Livello=p.parent.parent.name if p.parent.parent != t else "PA0")
                 for p in [t / "confronto/griglia_vincitori.csv"] + list(t.glob("*/confronto/griglia_vincitori.csv"))]
        v = pd.concat(parti)
        v = v[~v.Indicatore.isin(STABILITA)]
        v["Primi"] = v.PrimiAPari.fillna(v.Vincitore).map(lambda s: " = ".join(sorted(str(s).split(" = "))))
        return v.set_index(["Livello", "Indicatore", "Membri", "Fascia"]).Primi
    a, b = vinc(prova), vinc(nuovo)
    comuni = a.index.intersection(b.index)
    diverse = (a[comuni] != b[comuni]).sum()
    log.append(f"r00 contro prova_regola_shapley: {len(comuni)} celle senza stabilita', {diverse} diverse")
    if diverse or len(comuni) == 0:
        err.append(f"r00: {diverse} celle dei vincitori (indicatori non di stabilita') diverse dalla prova del 28/10")
    ta = pd.read_csv(prova / "sintesi/tau_per_fascia.csv")
    tb = pd.read_csv(nuovo / "sintesi/tau_per_fascia.csv")
    k = ["IndicatoreA", "IndicatoreB", "Fascia"]
    m = ta.merge(tb, on=k, suffixes=("_a", "_b"))
    m = m[~m.IndicatoreA.isin(STABILITA) & ~m.IndicatoreB.isin(STABILITA)]
    scarto = (m.TauMedio_a - m.TauMedio_b).abs().max()
    log.append(f"r00: tau medio per fascia senza stabilita', scarto massimo {scarto:.2e} su {len(m)} righe")
    if not (scarto <= 1e-6):
        err.append(f"r00: tau medio per fascia diverso dalla prova del 28/10 (scarto {scarto:.2e})")


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--radice", default=str(ROOT / "outputs" / "repliche"))
    ap.add_argument("--comunita", type=int, default=295)
    a = ap.parse_args(argv)
    cart = Path(a.radice) / "unito"
    err, log = [], []
    insiemi = {}
    for d in sorted(cart.glob("r[0-9][0-9]")):
        if (d / "export" / "comunita.csv").exists():
            insiemi[d.name] = controlla_replica(d, a.comunita, err, log)
    if not insiemi:
        err.append(f"nessuna replica unita in {cart}")
    else:
        ref = next(iter(insiemi.values()))
        for n, (c, m) in insiemi.items():
            if c != ref[0] or m != ref[1]:
                err.append(f"{n}: comunita' o metodi diversi dalle altre repliche")
    prova = Path(a.radice) / "prova_regola_shapley" / "tables"
    if (cart / "r00" / "tables").is_dir() and prova.is_dir():
        regressione_r00(cart / "r00" / "tables", prova, err, log)
    else:
        log.append("regressione su r00 saltata: manca r00 unito o la prova del 28/10 (tabelle locali)")
    testo = "\n".join(log + [""] + (["ERRORI:"] + err if err else ["Tutti i controlli passati."]))
    (cart / "controlli.txt").write_text(testo + "\n", encoding="utf-8")
    print(testo)
    return 1 if err else 0


if __name__ == "__main__":
    raise SystemExit(main())
