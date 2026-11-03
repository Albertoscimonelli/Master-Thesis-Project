"""Repliche dei partecipanti: le stesse schede, con famiglie estratte dentro la cella ISTAT.

PERCHE'. Le schede da 5 a 25 membri dichiarano in [MEMBRI].archetipo la composizione
ISTAT della comunita' (componenti x condizione occupazionale, allocazione a resto
maggiore: outputs/tables/composizione_cer_scalata.md). Il profilo di household_k pero'
e' la k-esima famiglia di 100_utenti.csv, che e' ordinato per cella: fino a 25 membri le
famiglie simulate sono tutte persone sole (0 membri su 5 con la cella dichiarata, 3 su 25).
Ogni replica tiene la composizione dichiarata e mette in ogni posto una famiglia del pool
da cento della cella giusta, estratta a caso.

REGOLE
  - Per ogni replica e per ogni cella, una permutazione casuale delle famiglie del pool
    (seed = SEED_BASE, replica, indice della cella). La CER da N membri prende, cella per
    cella e nell'ordine dei membri, le prime famiglie della permutazione. Quindi:
      * stesse famiglie in tutte le fasce di penetrazione e in tutti i livelli PA/ND di una
        taglia (i confronti lungo gli assi restano a parita' di persone, come prima);
      * taglie annidate: le famiglie della CER da 5 sono anche in quella da 8, e cosi' via
        (le composizioni ISTAT sono annidate cella per cella, il generatore lo controlla).
  - archetipo, n_comp, n_perc e scala_equiv della famiglia estratta vengono dalla scheda da
    100 membri, l'unica in cui archetipo e profilo coincidono. Reddito e gas li ricalcola
    arricchisci_schede.py, che li lega al nome del posto (household_k): il fattore di
    perturbazione del reddito resta del posto, la base Istat segue l'archetipo estratto.
  - FV: la taglia dell'impianto segue il numero di componenti (3,4 / 4,2 / 5,9 kWp, come
    nelle schede). Se la famiglia estratta cambia classe, cambiano kWp, export PVsyst, costo
    e quota di investimento del proprietario, e la potenza nel [RIEPILOGO].
  - Le varianti PA e ND si ricavano dalle schede della replica con le funzioni di
    genera_varianti_PA.py e genera_varianti_IND.py, che qui si importano e non si toccano:
    stessa regola (per ogni PA o impresa esce l'ultimo prosumer domestico).
  - Replica 0 = IDENTITA': stesse famiglie e stessi profili delle schede originali. E' il
    controllo del meccanismo: schede e profili delle varianti devono coincidere con gli
    originali (a meno di percorsi e intestazione), e MAIN2 deve dare gli stessi numeri.

STRUTTURA (una cartella per replica, non versionata: si rigenera dal seed)
  CER_repliche/rNN/CER_configuration/CER_*.txt, scenario_economico.txt, profili/N_utenti.csv
  CER_repliche/rNN/CER_configuration_PA/PAk/, profili/PAk/
  CER_repliche/rNN/CER_configuration_IND/NDk[_PAp]/, profili/NDk[_PAp]/
  CER_repliche/rNN/estrazione.csv     posto -> famiglia del pool, per taglia
MAIN2 la legge con MAIN2_RADICE=CER_repliche/rNN.

Uso (dalla radice del progetto):
    python -I CER_repliche/genera_repliche.py --repliche 0                       # identita'
    python -I CER_repliche/genera_repliche.py --repliche 1-20 --max-membri 15
    python -I CER_repliche/genera_repliche.py --repliche 1-20 --min-membri 18 --max-membri 25
"""
from __future__ import annotations

import argparse
import csv
import filecmp
import importlib.util
import math
import os
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
QUI = ROOT / "CER_repliche"
BASE = ROOT / "CER_configuration"
ORIG_PA = ROOT / "CER_configuration_PA"
ORIG_IND = ROOT / "CER_configuration_IND"
POOL_CSV = ROOT / "CER_LoadProfiles/outputs/csv_lombardia100/100_utenti.csv"
POOL_DETT = ROOT / "CER_LoadProfiles/outputs/csv_lombardia100/profili_famiglie_dettaglio.csv"
SCHEDA_100 = BASE / "CER_0_100_0.txt"
SEED_BASE = 20261029
TAGLIA_MAX = 25            # oltre, MAIN2 non gira (VLC); le schede da 50-100 restano fuori

# Classi di impianto per numero di componenti, come nelle schede (README §9): si
# controllano contro gli impianti di tutte le schede originali prima di usarle.
CLASSI_FV = {1: ("3.4", "PROVA_CER_1_Project_1_2_componenti.CSV", "7000"),
             2: ("3.4", "PROVA_CER_1_Project_1_2_componenti.CSV", "7000"),
             3: ("4.2", "PROVA_CER_1_Project_3_4_componenti.CSV", "7400"),
             4: ("4.2", "PROVA_CER_1_Project_3_4_componenti.CSV", "7400"),
             5: ("5.9", "PROVA_CER_1_Project_5_componenti.CSV", "9100"),
             6: ("5.9", "PROVA_CER_1_Project_5_componenti.CSV", "9100")}
CHIAVI_FILE = re.compile(r"^(prezzi_zonali|cartella_pv|scenario_economico|profili_carico)(\s*=\s*)(.*)$")


def carica_modulo(nome, percorso):
    spec = importlib.util.spec_from_file_location(nome, percorso)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)          # i blocchi __main__ non partono
    return mod


gpa = carica_modulo("genera_varianti_PA", ROOT / "CER_configuration_PA/genera_varianti_PA.py")
gind = carica_modulo("genera_varianti_IND", ROOT / "CER_configuration_IND/genera_varianti_IND.py")
arr = carica_modulo("arricchisci_schede", ROOT / "CER_LoadProfiles/arricchisci_schede.py")


# ---------------------------------------------------------------------------- schede
def leggi(p: Path) -> str:
    return p.read_text(encoding="utf-8").replace("\r\n", "\n")


def scrivi(p: Path, testo: str):
    """Scrive, ma non sovrascrive mai con un contenuto diverso: una replica generata a
    blocchi (5-15 membri prima, 18-25 poi) deve restare la stessa, e un file gia' letto da
    MAIN2 non deve cambiare sotto i suoi risultati. Se differisce, ci si ferma."""
    if p.exists():
        if p.read_text(encoding="utf-8") != testo:
            raise SystemExit(f"{p}: esiste gia' con un contenuto diverso. La replica non si "
                             "rigenera uguale: cancellare la cartella a mano se e' voluto.")
        return
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(testo, encoding="utf-8", newline="\n")


def sezione(righe, nome):
    """indici [inizio, fine) delle righe dentro la sezione [nome]"""
    i0 = next(i for i, r in enumerate(righe) if r.strip() == f"[{nome}]")
    i1 = next((i for i in range(i0 + 1, len(righe)) if righe[i].strip().startswith("[")), len(righe))
    return i0 + 1, i1


def tabella(righe, i0, i1):
    """(indice riga intestazione, intestazione, [(indice riga, dict)]) di una sezione"""
    dati = [(i, righe[i]) for i in range(i0, i1)
            if righe[i].strip() and not righe[i].lstrip().startswith("#") and "|" in righe[i]]
    ih, h = dati[0]
    head = [c.strip() for c in h.split("|")]
    return ih, head, [(i, dict(zip(head, [c.strip() for c in r.split("|")]))) for i, r in dati[1:]]


def membri(p: Path):
    righe = leggi(p).split("\n")
    _, head, rows = tabella(righe, *sezione(righe, "MEMBRI"))
    return head, [d for _, d in rows]


def impianti(p: Path):
    righe = leggi(p).split("\n")
    _, head, rows = tabella(righe, *sezione(righe, "IMPIANTI"))
    return head, [d for _, d in rows]


def taglia(p: Path) -> int:
    return sum(map(int, re.match(r"CER_(\d+)_(\d+)_(\d+)\.txt$", p.name).groups()))


def normalizza(testo: str) -> list[str]:
    """per i confronti con gli originali: via intestazione della replica e valori [FILE];
    le righe di tabella si confrontano cella per cella (l'allineamento delle colonne
    dipende da quale script ha scritto per ultimo, i valori no)"""
    out = []
    for r in testo.replace("\r\n", "\n").split("\n"):
        if r.startswith("# REPLICA"):
            continue
        m = CHIAVI_FILE.match(r)
        if m:
            out.append(f"{m.group(1)} = <percorso>")
        elif "|" in r and not r.lstrip().startswith("#"):
            out.append("|".join(c.strip() for c in r.split("|")))
        else:
            out.append(r.rstrip())
    return out


# ---------------------------------------------------------------------------- pool
def carica_pool():
    with open(POOL_DETT, encoding="utf-8") as f:
        head = next(csv.reader(f))
    pod = [c for c in head if c.endswith("_POD_kWh")]
    assert len(pod) == 100, "il pool deve avere cento famiglie"
    cella = [re.match(r"L100_(\d[a-z])_", c).group(1) for c in pod]
    codice = [re.match(r"L100_\d[a-z]_([A-Z]+\d+)", c).group(1) for c in pod]

    righe = list(csv.reader(open(POOL_CSV, encoding="utf-8"), delimiter=";"))
    assert righe[0] == ["timestamp"] + [f"household_{k}_kWh" for k in range(1, 101)], POOL_CSV
    ts = [r[0] for r in righe[1:]]
    assert len(ts) == 8760
    prof = [[r[k] for r in righe[1:]] for k in range(1, 101)]      # stringhe come nel file

    _, rows = membri(SCHEDA_100)
    assert [d["nome_csv"] for d in rows] == [f"household_{k}_kWh" for k in range(1, 101)]
    attr = [{c: d[c] for c in ("archetipo", "n_comp", "n_perc", "scala_equiv")} for d in rows]
    for k in range(100):
        assert attr[k]["archetipo"].split("_", 1)[0] == codice[k], \
            f"scheda da 100: household_{k + 1} non e' l'archetipo del pool ({codice[k]})"
    cella_di = {}
    for c, s in zip(codice, cella):
        assert cella_di.setdefault(c, s) == s, f"{c} in due celle"
    return dict(cella=cella, codice=codice, ts=ts, prof=prof, attr=attr, cella_di=cella_di)


def controlla_classi_fv():
    for p in BASE.glob("CER_*.txt"):
        M = {d["nome_csv"]: d for d in membri(p)[1]}
        for q in impianti(p)[1]:
            o = M[q["proprietario"]]
            kwp, fil, capex = CLASSI_FV[int(o["n_comp"])]
            assert (q["kWp"], q["file_produzione"], q["capex_EUR"], o["quota_inv_EUR"]) == \
                (kwp, fil, capex, capex), f"{p.name}/{q['id']}: impianto fuori dalle classi FV"


# ---------------------------------------------------------------------------- estrazione
def estrai(pool, r: int, schede_per_taglia):
    """{taglia: [indice del pool per ogni posto]}; r = 0 -> identita'"""
    if r == 0:
        return {n: list(range(n)) for n in schede_per_taglia}
    celle = sorted(set(pool["cella"]))
    perm = {}
    for ci, c in enumerate(celle):
        idx = [k for k in range(100) if pool["cella"][k] == c]
        rng = np.random.default_rng(np.random.SeedSequence([SEED_BASE, r, ci]))
        perm[c] = [idx[j] for j in rng.permutation(len(idx))]
    out = {}
    for n, schede in schede_per_taglia.items():
        archi = [tuple(d["archetipo"] for d in membri(p)[1]) for p in schede]
        assert len(set(archi)) == 1, f"taglia {n}: le fasce dichiarano archetipi diversi"
        conta, posti = Counter(), []
        for a in archi[0]:
            c = pool["cella_di"][a.split("_", 1)[0]]
            assert conta[c] < len(perm[c]), f"taglia {n}: la cella {c} ha troppe poche famiglie"
            posti.append(perm[c][conta[c]])
            conta[c] += 1
        out[n] = posti
    # annidamento delle taglie, cella per cella
    tg = sorted(out)
    for a, b in zip(tg, tg[1:]):
        assert set(out[a]) <= set(out[b]), f"replica {r}: le famiglie della taglia {a} non sono in {b}"
    return out


# ---------------------------------------------------------------------------- scheda base
def scheda_base(src: Path, posti, pool, r: int, dest_dir: Path, ctx):
    """testo della scheda della replica, piu' le righe dell'abbinamento"""
    n = taglia(src)
    righe = leggi(src).split("\n")
    m0, m1 = sezione(righe, "MEMBRI")
    ih, head_m, rows_m = tabella(righe, m0, m1)
    p0, p1 = sezione(righe, "IMPIANTI")
    ihp, head_p, rows_p = tabella(righe, p0, p1)
    assert [d["nome_csv"] for _, d in rows_m] == [f"household_{k}_kWh" for k in range(1, n + 1)]
    abbin, cambi_fv = [], 0

    if r > 0:
        for (i, d), k in zip(rows_m, posti):
            c_dich = pool["cella_di"][d["archetipo"].split("_", 1)[0]]
            assert pool["cella"][k] == c_dich, (src.name, d["nome_csv"])
            abbin.append(dict(posto=d["nome_csv"], archetipo_dichiarato=d["archetipo"], cella=c_dich,
                              famiglia=f"household_{k + 1}_kWh",
                              archetipo_estratto=pool["attr"][k]["archetipo"]))
            d.update(pool["attr"][k])
            righe[i] = " | ".join(d[h] for h in head_m)
        per_nome = {d["nome_csv"]: (i, d) for i, d in rows_m}
        for i, q in rows_p:
            io, o = per_nome[q["proprietario"]]
            kwp, fil, capex = CLASSI_FV[int(o["n_comp"])]
            if (q["kWp"], q["file_produzione"], q["capex_EUR"]) != (kwp, fil, capex):
                q.update(kWp=kwp, file_produzione=fil, capex_EUR=capex)
                o["quota_inv_EUR"] = capex
                righe[i] = " | ".join(q[h] for h in head_p)
                righe[io] = " | ".join(o[h] for h in head_m)
                cambi_fv += 1
        tot = sum(float(q["kWp"]) for _, q in rows_p)
        for j, l in enumerate(righe):
            if re.match(r"^potenza_installata_kWp\s*=", l):
                righe[j] = re.sub(r"=\s*\S+", f"= {tot:.1f}", l, count=1)
        if cambi_fv:      # allinea la tabella impianti, cosi' resta leggibile
            dati = [q for _, q in rows_p]
            nuova = gpa.fmt_table(head_p, dati)
            pos = [ihp] + [i for i, _ in rows_p]
            for j, l in zip(pos, nuova):
                righe[j] = l
    testo = "\n".join(righe)
    nuovo, _ = arr.arricchisci_testo(testo, ctx)        # reddito e gas dall'archetipo
    if r == 0:
        assert normalizza(nuovo) == normalizza(testo), f"{src.name}: arricchisci non e' idempotente"
    righe = nuovo.replace("\r\n", "\n").split("\n")

    for j, l in enumerate(righe):
        m = CHIAVI_FILE.match(l)
        if not m:
            continue
        k_, eq, v = m.groups()
        if k_ == "profili_carico":
            v = f"profili/{n}_utenti.csv"
        elif k_ == "scenario_economico":
            assert "/" not in v, v
        else:
            v = os.path.relpath((BASE / v).resolve(), dest_dir).replace("\\", "/")
        righe[j] = f"{k_}{eq}{v}"
    intest = [f"# REPLICA r{r:02d} - CER_repliche/genera_repliche.py, non modificare a mano: si rigenera."]
    if r == 0:
        intest.append("# REPLICA r00 = IDENTITA': stesse famiglie e stessi profili della scheda originale.")
    else:
        intest += ["# REPLICA: composizione dichiarata invariata; in ogni posto domestico una famiglia del",
                   "# REPLICA: pool da cento della stessa cella ISTAT (componenti x condizione), seed",
                   f"# REPLICA: ({SEED_BASE}, {r}, cella). Abbinamento posto -> famiglia in ../estrazione.csv.",
                   f"# REPLICA: impianti cambiati di classe FV in questa scheda: {cambi_fv}."]
    testo = "\n".join(intest + righe)
    if not testo.endswith("\n"):
        testo += "\n"
    if r == 0:
        assert normalizza(testo) == normalizza(leggi(src)), f"{src.name}: la scheda identita' differisce"
    return testo, abbin, cambi_fv


def scrivi_profili(pool, posti, dest: Path):
    n = len(posti)
    righe = [";".join(["timestamp"] + [f"household_{k}_kWh" for k in range(1, n + 1)])]
    righe += [";".join([pool["ts"][t]] + [pool["prof"][k][t] for k in posti]) for t in range(8760)]
    scrivi(dest, "\n".join(righe) + "\n")


def scrivi_profilo_variante(modulo, xlsx, keep, add, ts, series, dest: Path):
    """write_profile del generatore PA o ND, con lo stesso controllo di scrivi()"""
    if not dest.exists():
        modulo.write_profile(xlsx, keep, add, ts, series, dest)
        return
    tmp = dest.with_suffix(".tmp")
    modulo.write_profile(xlsx, keep, add, ts, series, tmp)
    uguale = filecmp.cmp(tmp, dest, shallow=False)
    tmp.unlink()
    if not uguale:
        raise SystemExit(f"{dest}: esiste gia' con un contenuto diverso.")


# ---------------------------------------------------------------------------- varianti
def varianti_pa(radice: Path, schede, ts, series):
    gpa.SRC = radice / "CER_configuration"
    gpa.OUT = radice / "CER_configuration_PA"
    fatte = []
    for p in schede:
        for level in (1, 2, 3):
            try:
                text, (xlsx, keep, add, _) = gpa.build(p, level, ts, series)
            except IndexError:            # meno di k prosumer, come in genera_varianti_PA
                continue
            d = gpa.OUT / f"PA{level}"
            scrivi(d / p.name, text)
            prof = gpa.OUT / f"profili/PA{level}/{p.stem}_PA{level}.csv"
            scrivi_profilo_variante(gpa, xlsx, keep, add, ts, series, prof)
            fatte.append((f"PA{level}", p.name, d / p.name, prof))
    return fatte


def prepara_ind():
    ts, series_pa = gind.gpa.pa_series()
    peak = {k: int(math.ceil(max(v) / 5.0) * 5) for k, v in series_pa.items()}
    series = gind.nd_series(ts)
    for a in gind.ND:
        if a["p_prel"] is None:
            a["p_prel"] = int(math.ceil(max(series[a["nome"]]) / 5.0) * 5)
    pa = []
    for a in gind.gpa.PA:
        b = dict(a)
        b.update(categoria="PA", p_prel=a.get("p_prel") or peak[a["nome"]])
        pa.append(b)
    series.update(series_pa)
    return ts, series, pa


def varianti_ind(radice: Path, schede, ts, series, pa):
    gind.SRC = radice / "CER_configuration"
    gind.OUT = radice / "CER_configuration_IND"
    fatte = []
    for p in schede:
        n, n_pros = gind.n_of(p)
        if n < gind.N_MIN:
            continue
        tetto = (n + 1) // 2 - 1
        for k in gind.ND_LEVELS:
            for q in (0,) + gind.PA_LEVELS:
                label = f"ND{k}" + (f"_PA{q}" if q else "")
                if k + q > tetto or k + q > n_pros:
                    continue
                add = gind.ND[:k] + pa[:q]
                text, xlsx, keep = gind.build(p, label, add, ts)
                d = gind.OUT / label
                scrivi(d / p.name, text)
                prof = gind.OUT / f"profili/{label}/{p.stem}_{label}.csv"
                scrivi_profilo_variante(gind, xlsx, keep, [a["nome"] for a in add], ts, series, prof)
                fatte.append((label, p.name, d / p.name, prof))
    return fatte


# ---------------------------------------------------------------------------- replica
def genera(r: int, nmin: int, nmax: int, pool, ctx, pa_dati, ind_dati):
    radice = QUI / f"r{r:02d}"
    dest = radice / "CER_configuration"
    scrivi(dest / "scenario_economico.txt", leggi(BASE / "scenario_economico.txt"))

    orig = sorted(p for p in BASE.glob("CER_*.txt") if nmin <= taglia(p) <= min(nmax, TAGLIA_MAX))
    per_taglia = defaultdict(list)
    for p in orig:
        per_taglia[taglia(p)].append(p)
    # l'estrazione si fa su TUTTE le taglie fino a 25, cosi' non dipende da quelle generate
    tutte = defaultdict(list)
    for p in BASE.glob("CER_*.txt"):
        if taglia(p) <= TAGLIA_MAX:
            tutte[taglia(p)].append(p)
    posti = estrai(pool, r, tutte)

    cambi = 0
    for n, schede in sorted(per_taglia.items()):
        scrivi_profili(pool, posti[n], dest / f"profili/{n}_utenti.csv")
        for p in sorted(schede):
            testo, _, c = scheda_base(p, posti[n], pool, r, dest, ctx)
            scrivi(dest / p.name, testo)
            cambi += c
    # abbinamento di tutte le taglie fino a 25, anche quelle non generate in questo giro
    righe_abb = []
    if r > 0:
        for n in sorted(tutte):
            for d, k in zip(membri(sorted(tutte[n])[0])[1], posti[n]):
                righe_abb.append(dict(replica=r, membri=n, posto=d["nome_csv"],
                                      archetipo_dichiarato=d["archetipo"],
                                      cella=pool["cella_di"][d["archetipo"].split("_", 1)[0]],
                                      famiglia=f"household_{k + 1}_kWh",
                                      archetipo_estratto=pool["attr"][k]["archetipo"]))
    if r == 0:     # i profili identita' devono coincidere con N_utenti.xlsx (gia' verificato
        for n in per_taglia:   # al byte sul CSV da 100: qui si controlla la scrittura)
            h, rows = gpa.read_xlsx(dest / f"profili/{n}_utenti.csv")
            h0, rows0 = gpa.read_xlsx(ROOT / f"CER_LoadProfiles/outputs/csv_lombardia100/{n}_utenti.xlsx")
            assert list(h) == list(h0) and all(
                list(a[1:]) == list(b[1:]) for a, b in zip(rows, rows0)), f"profili identita' {n}"

    schede_rep = sorted(q for q in dest.glob("CER_*.txt") if nmin <= taglia(q) <= min(nmax, TAGLIA_MAX))
    fatte = varianti_pa(radice, schede_rep, *pa_dati) + varianti_ind(radice, schede_rep, *ind_dati)

    if r == 0:     # le varianti devono essere quelle originali, profili compresi
        for label, nome, scheda, prof in fatte:
            cart = ORIG_PA if label.startswith("PA") else ORIG_IND
            o = cart / label / nome
            assert normalizza(leggi(scheda)) == normalizza(leggi(o)), f"{label}/{nome} differisce"
            po = cart / "profili" / label / prof.name
            assert filecmp.cmp(prof, po, shallow=False), f"profili {label}/{nome} differiscono"
        attese = {(c.parent.name, c.name) for cart in (ORIG_PA, ORIG_IND)
                  for c in cart.glob("*/CER_*.txt")
                  if c.parent.name != "PA0" and nmin <= taglia(c) <= min(nmax, TAGLIA_MAX)}
        assert attese == {(l, n_) for l, n_, *_ in fatte}, "insieme delle varianti diverso"

    if righe_abb:
        campi = list(righe_abb[0])
        testo = "\n".join([",".join(campi)] + [",".join(str(x[c]) for c in campi) for x in righe_abb])
        p_abb = radice / "estrazione.csv"
        if p_abb.exists() and p_abb.read_text(encoding="utf-8").count("\n") < testo.count("\n") + 1:
            p_abb.unlink()          # versione con le sole taglie generate in un giro precedente
        scrivi(p_abb, testo + "\n")
    n_base = len(schede_rep)
    print(f"r{r:02d}: {n_base} schede base, {len(fatte)} varianti PA/ND, "
          f"{n_base + len(fatte)} in tutto; impianti cambiati di classe FV: {cambi}")
    return n_base + len(fatte)


def intervallo(s: str) -> list[int]:
    out = []
    for parte in s.split(","):
        a, _, b = parte.partition("-")
        out += list(range(int(a), int(b or a) + 1))
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--repliche", required=True, help="per esempio 0, 1-20, 1,3,5")
    ap.add_argument("--min-membri", type=int, default=1)
    ap.add_argument("--max-membri", type=int, default=TAGLIA_MAX)
    a = ap.parse_args(argv)
    controlla_classi_fv()
    pool = carica_pool()
    ctx = arr.contesto()
    ts, series = gpa.pa_series()
    gpa.PEAK = {k: int(math.ceil(max(v) / 5.0) * 5) for k, v in series.items()}
    ind_dati = prepara_ind()
    for r in intervallo(a.repliche):
        genera(r, a.min_membri, a.max_membri, pool, ctx, (ts, series), ind_dati)
    return 0


if __name__ == "__main__":
    sys.exit(main())
