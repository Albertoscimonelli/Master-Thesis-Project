"""Analisi aggiuntive per il capitolo 7: cinque letture dei risultati che l'analisi completa non fa.

Legge gli stessi file versionati di aggrega_repliche.py (export e tabelle di ogni replica r01-r20 in
outputs/repliche/unito/rNN/, piu' aggregato/tau.csv e aggregato/pareto.csv) e non ricalcola nessuna
ripartizione: rilegge quelle di MAIN2. Nasce dalla rilettura critica del capitolo 7 del 6 novembre
2026 (docs/analisi_finale/PROMPT_capitolo_7.md).

  1. Incentivo e proprieta' dell'impianto. Sui profili NETTI il carico residuo del proprietario e'
     quasi nullo nelle ore di eccedenza, quindi la sua virtuosita' misurata crolla
     (compute_incentive_strength.m lo dichiara). Si misura quanto: virtuosita' netta e lorda di
     prosumer e consumatori, quota di comunita' in cui OGNI prosumer e' meno virtuoso di OGNI
     consumatore, tau-b fra forza incentivante e quota dell'incentivo ai consumatori, tau-b fra
     Fairness Index e allineamento lordo (da aggregato/tau.csv).
     A parita' di impianto: pendenza della quota sulla virtuosita' netta DENTRO i consumatori e
     DENTRO i prosumer (gruppi di almeno 4 membri), relativa a quella della Similarity-Utilization.
  2. Distanza fra le ripartizioni. Per ogni comunita' e coppia di metodi la distanza di variazione
     totale  TV = 1/2 sum_i |q_ai - q_bi|, con q le quote normalizzate: la frazione di v(N) da
     spostare per passare da un metodo all'altro. Matrice mediana, gruppi di metodi (legame medio),
     Pearson Key contro Tri-level EP, comunita' in cui il livello di poverta' energetica del
     Tri-level EP e' attivo (InclusioneLIHC definita), pari merito dei due sulla forza incentivante.
  3. Stabilita'. Margine del Variance Least Core = suo eccesso massimo in % di v(N), cioe' il valore
     del least core (Maschler, Peleg e Shapley 1979): quanto puo' essere lontana dal bordo del
     nucleo la ripartizione piu' stabile. Quota nel nucleo ed eccesso mediano per metodo e gruppo di
     comunita'; Shapley nel nucleo per taglia e fascia.
  4. Comunita' miste. Quota dell'incentivo ai membri non domestici (PA, imprese) per metodo; le
     stesse famiglie nel livello base e nelle varianti con PA o imprese: chi guadagna e quanto;
     comunita' con un solo prosumer e quote nulle.
  5. VAN senza incentivo. Il VAN di MAIN2 e' lineare nella quota (stesso fattore di annualita' per
     tutti i membri, verificato qui): VAN0 = VAN - fattore * quota e' il VAN dell'impianto senza
     incentivo; l'incentivo di pareggio e' -VAN0 / fattore.

Uscite:
  outputs/repliche/unito/aggregato/aggiuntive/*.csv   i numeri in chiaro, e sintesi_aggiuntive.md
  outputs/tesi_finale/numeri_aggiuntivi.tex           macro LaTeX (\\input accanto a numeri_tesi)
  outputs/tesi_finale/numeri_aggiuntivi.csv           le stesse macro con valore e descrizione
  outputs/tesi_finale/tabelle/{incentive_ownership, incentive_within_groups, allocation_distance,
                               stability_by_group, mixed_communities}.tex e .csv

Controlli di integrita' (si ferma con codice 1): 20 repliche, 5900 comunita', 10 metodi in ogni
comunita', IS della Similarity-Utilization = 1, fattore di annualita' unico, nessuna macro con lo
stesso nome di una di numeri_tesi.tex.

Uso:  python -I CER_repliche/analisi_aggiuntive.py [--radice outputs/repliche] [--out outputs/tesi_finale]
"""
from __future__ import annotations

import argparse
import itertools
import re
import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
import aggrega_repliche as ar  # noqa: E402
import stile_tesi as st  # noqa: E402
import tesi_finale as tf  # noqa: E402  (solo nome_macro e tex)

ROOT = Path(__file__).resolve().parent.parent
SU, PK, TLE, SH, VLC = "Similarity-Utilization", "Pearson Key", "Tri-level EP", "Shapley", "Variance Least Core"
ES, PTC, RM1, CT, WS = ("Equal Split", "Proportional to Consumption", "Remuneration Model 1", "Cascading Tree",
                        "Weighted Solidarity")
SIGLA = {SH: "S", VLC: "VLC", ES: "ES", PTC: "PtC", PK: "PK", SU: "SU", RM1: "RM1", CT: "CT", WS: "WS", TLE: "TlE"}
GRUPPI = ["households only", "with public buildings", "with firms"]
INSIEME_PARETO_LORDO = "Equita(Gini) + Incentivo(coseno lordo) + Sostenibilita(VAN_min)"
ERRORI: list[str] = []
MACRO: dict[str, tuple[str, str]] = {}          # nome -> (valore, descrizione)


def controlla(cond, msg):
    if not bool(cond):
        ERRORI.append(msg)


def macro(valore, descrizione, *nome):
    MACRO[tf.nome_macro(*nome)] = (str(valore), descrizione)


def f(x, d=2):
    if x is None or pd.isna(x):
        return "n.d."
    x = float(x)
    return f"{0.0 if abs(x) < 0.5 * 10 ** -d else x:.{d}f}"     # niente "-0.00"


def p(x, d=0):
    return "n.d." if x is None or pd.isna(x) else f"{100 * float(x):.{d}f}"


def tau_b(a, b) -> float:
    """tau-b di Kendall fra due vettori (pochi elementi: qui i 10 metodi di una comunita')."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    i, j = np.triu_indices(len(a), 1)
    da, db = np.sign(a[i] - a[j]), np.sign(b[i] - b[j])
    n1, n2 = (da != 0).sum(), (db != 0).sum()
    return float((da * db).sum() / np.sqrt(n1 * n2)) if n1 and n2 else np.nan


# ---------------------------------------------------------------------------- dati
def carica(cart: Path) -> dict:
    tabs = {r: t for r, t in ar.repliche(cart).items() if r >= 1}
    D = {"tabs": tabs}
    for k, nome in [("com", "comunita.csv"), ("T", "tfair_lungo.csv"), ("qm", "quote_membri.csv"),
                    ("vi", "virtuosita.csv")]:
        df = ar.leggi_export(cart, tabs, nome)
        D[k] = df[df.Replica >= 1].copy()
    com = D["com"]
    for k in ("T", "qm", "vi"):
        D[k] = ar.con_fascia(D[k], com)
    D["com"] = ar.con_fascia(com, com)
    q = D["qm"]
    q["q"] = q.Quota_EUR / q.groupby(["Replica", "Composizione", "Scheda", "Metodo"]).Quota_EUR.transform("sum")
    q["Domestico"] = q.Membro.str.startswith("household")
    return D


def integrita(D):
    com, T = D["com"], D["T"]
    controlla(com.Replica.nunique() == 20, f"repliche attese 20, trovate {com.Replica.nunique()}")
    controlla(len(com) == 5900, f"comunita' attese 5900, trovate {len(com)}")
    nm = T.groupby(["Replica", "Composizione", "Scheda"]).Metodo.nunique()
    controlla((nm == 10).all(), f"comunita' con un numero di metodi diverso da 10: {int((nm != 10).sum())}")
    controlla(set(T.Metodo) == set(st.METODI), f"metodi inattesi: {sorted(set(T.Metodo) ^ set(st.METODI))}")
    su = T[T.Metodo == SU].ForzaIncentivante
    controlla(np.allclose(su, 1, atol=1e-6), "IS della Similarity-Utilization diverso da 1")


# ---------------------------------------------------------------------------- 1. incentivo e proprieta'
def incentivo_proprieta(D, agg: Path):
    vi, T, qm = D["vi"], D["T"], D["qm"]
    d = vi[vi.Composizione == "PA0"]
    fasce = ["1", "2", "3"]
    v = d.groupby(["Fascia", "Prosumer"])[["VirtuositaNetta", "VirtuositaLorda"]].median().unstack("Prosumer")
    d13 = d[d.Fascia.isin(fasce)]
    pool = d13.groupby("Prosumer")[["VirtuositaNetta", "VirtuositaLorda"]].median()
    netP, netC = v[("VirtuositaNetta", 1)].reindex(fasce), v[("VirtuositaNetta", 0)].reindex(fasce)
    macro(f(netP.min()), "virtuosita' netta mediana dei prosumer, minimo sulle fasce 1-3 (domestico)", "VirtNetProsumerMin")
    macro(f(netP.max()), "virtuosita' netta mediana dei prosumer, massimo sulle fasce 1-3", "VirtNetProsumerMax")
    macro(f(netC.min()), "virtuosita' netta mediana dei consumatori, minimo sulle fasce 1-3", "VirtNetConsumerMin")
    macro(f(netC.max()), "virtuosita' netta mediana dei consumatori, massimo sulle fasce 1-3", "VirtNetConsumerMax")
    macro(f(pool.loc[1, "VirtuositaLorda"]), "virtuosita' lorda mediana dei prosumer, fasce 1-3", "VirtGrossProsumer")
    macro(f(pool.loc[0, "VirtuositaLorda"]), "virtuosita' lorda mediana dei consumatori, fasce 1-3", "VirtGrossConsumer")

    def separa(s, col):
        return s[s.Prosumer == 1][col].max() < s[s.Prosumer == 0][col].min()
    g = d13.groupby(["Replica", "Scheda"])
    sep = pd.DataFrame({"netta": g.apply(lambda s: separa(s, "VirtuositaNetta"), include_groups=False),
                        "lorda": g.apply(lambda s: separa(s, "VirtuositaLorda"), include_groups=False)})
    macro(p(sep.netta.mean()), "% comunita' domestiche fasce 1-3 in cui ogni prosumer e' meno virtuoso (netto) di ogni consumatore", "PctSeparationNet")
    macro(p(sep.lorda.mean()), "stessa quota sui profili lordi", "PctSeparationGross")
    macro(len(sep), "comunita' domestiche delle fasce 1-3", "NumHouseholdCommunitiesBandsOneThree")

    # tau fra forza incentivante e quota ai consumatori, comunita' per comunita'
    q = qm[(qm.Composizione == "PA0") & qm.Fascia.isin(fasce)]
    qc = (q.assign(QC=q.Quota_EUR * (1 - q.Prosumer)).groupby(["Replica", "Scheda", "Metodo"])
          .agg(QC=("QC", "sum"), Tot=("Quota_EUR", "sum")).reset_index())
    qc["QuotaConsumatori"] = qc.QC / qc.Tot
    x = T[T.Composizione == "PA0"].merge(qc, on=["Replica", "Scheda", "Metodo"])
    tt = x.groupby(["Replica", "Scheda", "Fascia"]).apply(lambda s: pd.Series({
        "tau_IS": tau_b(s.ForzaIncentivante, s.QuotaConsumatori),
        "tau_AllNetto": tau_b(s.AllineamentoVirtu, s.QuotaConsumatori),
        "tau_AllLordo": tau_b(s.AllineamentoVirtu_lordo, s.QuotaConsumatori)}), include_groups=False).reset_index()
    tt.to_csv(agg / "tau_incentivo_quota_consumatori.csv", index=False)
    taus = tt.groupby("Fascia").tau_IS.median()
    for fa in fasce:
        macro(f(taus[fa]), f"tau-b fra forza incentivante e quota ai consumatori, fascia {fa} (mediana)",
              "TauISConsumerShareBand", int(fa))

    # tau fra Fairness Index e allineamento lordo, dall'aggregato
    ta = pd.read_csv(agg.parent / "tau.csv")
    def tau_agg(a, b):
        s = ta[((ta.IndicatoreA == a) & (ta.IndicatoreB == b)) | ((ta.IndicatoreA == b) & (ta.IndicatoreB == a))]
        return s.set_index(s.Fascia.astype(int).astype(str))
    fil = tau_agg("FairnessIndex", "AllineamentoVirtu_lordo")
    fis = tau_agg("FairnessIndex", "ForzaIncentivante")
    for fa in ["1", "2", "3", "4"]:
        macro(f(fil.loc[fa, "mediana"]), f"tau-b Fairness Index - allineamento lordo, fascia {fa} (mediana sulle repliche)",
              "Tau", "FairnessIndex", "AllineamentoVirtu_lordo", "Band", int(fa))

    righe = []
    for fa in ["1", "2", "3", "4"]:
        righe.append({"Band": fa,
                      "Net virtuosity, prosumers": f(v.loc[fa, ("VirtuositaNetta", 1)]),
                      "Net virtuosity, consumers": f(v.loc[fa, ("VirtuositaNetta", 0)]) if fa != "4" else "--",
                      "Gross virtuosity, prosumers": f(v.loc[fa, ("VirtuositaLorda", 1)]),
                      "Gross virtuosity, consumers": f(v.loc[fa, ("VirtuositaLorda", 0)]) if fa != "4" else "--",
                      "$\\tau_b$(IS, consumers' share)": f(taus.get(fa)) if fa != "4" else "--",
                      "$\\tau_b$(FI, IS)": f(fis.loc[fa, "mediana"]),
                      "$\\tau_b$(FI, gross alignment)": f(fil.loc[fa, "mediana"])})
    tf.tex(pd.DataFrame(righe), D["out"] / "tabelle" / "incentive_ownership", "lrrrrrrr")


def entro_gruppo(D, agg: Path):
    """Pendenza della quota sulla virtuosita' netta dentro i consumatori e dentro i prosumer."""
    q = D["qm"][D["qm"].Composizione == "PA0"].merge(
        D["vi"][D["vi"].Composizione == "PA0"][["Replica", "Scheda", "Membro", "VirtuositaNetta"]],
        on=["Replica", "Scheda", "Membro"])
    righe = []
    for (r, s, fa, pr), g in q.groupby(["Replica", "Scheda", "Fascia", "Prosumer"]):
        w = g.pivot_table(index="Membro", columns="Metodo", values="q")
        if len(w) < 4:
            continue
        b = g.drop_duplicates("Membro").set_index("Membro").VirtuositaNetta.reindex(w.index)
        bc = b - b.mean()
        if (bc ** 2).sum() < 1e-12:
            continue
        rif = ((w[SU] - w[SU].mean()) * bc).sum() / (bc ** 2).sum()
        for m in w.columns:
            sl = ((w[m] - w[m].mean()) * bc).sum() / (bc ** 2).sum()
            cor = np.corrcoef(w[m], b)[0, 1] if w[m].std() > 0 else np.nan
            righe.append((r, s, fa, pr, m, sl / rif if abs(rif) > 1e-12 else np.nan, cor))
    R = pd.DataFrame(righe, columns=["Replica", "Scheda", "Fascia", "Prosumer", "Metodo", "PendenzaRel", "Correlazione"])
    S = (R.groupby(["Prosumer", "Fascia", "Metodo"])
         .agg(PendenzaRel=("PendenzaRel", "median"), Correlazione=("Correlazione", "median"),
              Comunita=("Scheda", "size")).reset_index())
    S.to_csv(agg / "entro_gruppo.csv", index=False)
    c = S[S.Prosumer == 0]
    for m, nome in [(SH, "Shapley"), (VLC, "VLC"), (PK, "Pearson"), (TLE, "TriLevel")]:
        s = c[c.Metodo == m]
        macro(f(s.PendenzaRel.min()), f"pendenza relativa a SU fra i consumatori, {m}, minimo sulle fasce 1-3", "SlopeConsumers", nome, "Min")
        macro(f(s.PendenzaRel.max()), f"pendenza relativa a SU fra i consumatori, {m}, massimo sulle fasce 1-3", "SlopeConsumers", nome, "Max")
    four = c[c.Metodo.isin([SH, VLC, PK, TLE])].Correlazione
    macro(f(four.min()), "correlazione quota-virtuosita' fra i consumatori: minimo su Shapley, VLC, PK, TlE e fasce 1-3", "CorrConsumersMin")
    macro(f(four.max()), "lo stesso, massimo", "CorrConsumersMax")
    pr = S[S.Prosumer == 1].set_index(["Metodo", "Fascia"]).Correlazione
    for m, nome in [(SH, "Shapley"), (VLC, "VLC")]:
        for fa in ["1", "3"]:
            macro(f(pr[(m, fa)]), f"correlazione quota-virtuosita' fra i prosumer, {m}, fascia {fa}", "CorrProsumers", nome, "Band", int(fa))
    macro(int(c[(c.Metodo == SU)].Comunita.min()), "comunita' minime usate per fascia fra i consumatori (gruppi >= 4)", "NumCommunitiesWithinConsumersMin")

    w = S.pivot_table(index="Metodo", columns=["Prosumer", "Fascia"], values=["PendenzaRel", "Correlazione"])
    righe = []
    for m in st.ordina_metodi(w.index):
        righe.append([st.nome_metodo(m)] + [f(w.loc[m, ("PendenzaRel", 0, fa)]) for fa in ["1", "2", "3"]]
                     + [f(w.loc[m, ("Correlazione", 1, fa)]) for fa in ["1", "3"]])
    tf.tex(pd.DataFrame(righe, columns=["Mechanism", "Consumers, slope B1", "B2", "B3",
                                        "Prosumers, correlation B1", "B3"]),
           D["out"] / "tabelle" / "incentive_within_groups", "lrrrrr")


# ---------------------------------------------------------------------------- 2. distanze
def distanze(D, agg: Path):
    q, T = D["qm"], D["T"]
    W = q.pivot_table(index=["Gruppo", "Replica", "Composizione", "Scheda", "Membro"], columns="Metodo", values="q")
    metodi = st.ordina_metodi(W.columns)
    parti = []
    for a, b in itertools.combinations(metodi, 2):
        tv = (W[a] - W[b]).abs().groupby(level=["Gruppo", "Replica", "Composizione", "Scheda"]).sum() / 2
        parti.append(pd.DataFrame({"A": a, "B": b, "TV": tv}).reset_index())
    TV = pd.concat(parti, ignore_index=True)
    # mtime fisso: senza, gzip scrive l'ora nell'intestazione e il file cambia a ogni esecuzione
    TV.to_csv(agg / "distanze_per_comunita.csv.gz", index=False, compression={"method": "gzip", "mtime": 0})

    def matrice(d):
        m = d.groupby(["A", "B"]).TV.median()
        F = pd.DataFrame(0.0, index=metodi, columns=metodi)
        for (a, b), x in m.items():
            F.loc[a, b] = F.loc[b, a] = x
        return F
    mats = {g: matrice(TV[TV.Gruppo == g]) for g in GRUPPI}
    mats["tutte"] = matrice(TV)
    pd.concat({g: m for g, m in mats.items()}, names=["Gruppo", "Metodo"]).to_csv(agg / "distanze_mediane.csv")

    def legame_medio(F):
        cl = {SIGLA[m]: [m] for m in F.index}
        passi = []
        while len(cl) > 1:
            best = None
            for x, y in itertools.combinations(list(cl), 2):
                dd = np.mean([F.loc[u, v] for u in cl[x] for v in cl[y]])
                if best is None or dd < best[0]:
                    best = (dd, x, y)
            dd, x, y = best
            passi.append((dd, x, y))
            cl[f"{x}+{y}"] = cl.pop(x) + cl.pop(y)
        return passi
    pd.DataFrame([(g, i + 1, dd, x, y) for g, F in mats.items() for i, (dd, x, y) in enumerate(legame_medio(F))],
                 columns=["Gruppo", "Passo", "Distanza", "A", "B"]).to_csv(agg / "gruppi_di_metodi.csv", index=False)

    def coppia(a, b, d=TV):
        return d[((d.A == a) & (d.B == b)) | ((d.A == b) & (d.B == a))].TV
    dom = TV[TV.Gruppo == "households only"]
    pt = coppia(PK, TLE)
    macro(p(coppia(PK, TLE, dom).median(), 1), "distanza TV mediana PK - TlE, % di v(N), domestico", "TVPKTLEHouseholds")
    macro(p(coppia(PK, TLE, dom).quantile(0.9), 1), "lo stesso, 90 percentile", "TVPKTLEHouseholdsPNinety")
    macro(p(pt.median(), 1), "distanza TV mediana PK - TlE, tutte le comunita'", "TVPKTLEAll")
    macro(p((pt < 0.05).mean()), "% comunita' con distanza PK - TlE sotto il 5% di v(N)", "PctTVPKTLEBelowFive")
    macro(p(pt.max(), 1), "distanza PK - TlE massima", "TVPKTLEMax")
    macro(p(coppia(SH, VLC).median(), 1), "distanza TV mediana Shapley - VLC, tutte le comunita'", "TVShapleyVLCAll")
    macro(p(coppia(PK, PTC, dom).median(), 1), "distanza TV mediana PK - Prop. to Consumption, domestico", "TVPKPtCHouseholds")
    macro(p(coppia(PK, SU, dom).median(), 1), "distanza TV mediana PK - SU, domestico", "TVPKSUHouseholds")
    macro(p(coppia(PK, SU).median(), 1), "distanza TV mediana PK - SU, tutte le comunita'", "TVPKSUAll")
    macro(p(coppia(CT, ES, dom).median(), 1), "distanza TV mediana Cascading Tree - Equal Split, domestico", "TVCTESHouseholds")

    # livello di poverta' energetica attivo: InclusioneLIHC definita
    att = T[T.InclusioneLIHC.notna()].drop_duplicates(["Replica", "Composizione", "Scheda"])
    macro(len(att), "comunita' con almeno un membro vulnerabile (livello EP del Tri-level attivo)", "NumCommunitiesEPActive")
    macro(" and ".join(str(int(x)) for x in sorted(att.Membri.unique())), "taglie di quelle comunita'", "EPActiveSizes")
    macro(att.Replica.nunique(), "repliche in cui compaiono", "NumReplicasEPActive")
    k = pd.MultiIndex.from_frame(att[["Replica", "Composizione", "Scheda"]])
    ptc = TV[(TV.A.isin([PK, TLE])) & (TV.B.isin([PK, TLE]))].set_index(["Replica", "Composizione", "Scheda"]).TV
    macro(p(ptc[ptc.index.isin(k)].median(), 1), "distanza PK - TlE mediana dove il livello EP e' attivo", "TVPKTLEEPActive")

    # pari merito sulla forza incentivante (livello base)
    V = ar.leggi(D["tabs"], "confronto/griglia_vincitori.csv", per_livello=True)
    V = V[(V.Replica >= 1) & (V.Livello == "PA0") & (V.Indicatore == "ForzaIncentivante")]
    V = V.assign(Primi=ar.insieme_vincitori(V)).dropna(subset=["Primi"])
    pk, tl = V.Primi.str.contains(PK, regex=False), V.Primi.str.contains(TLE, regex=False)
    macro(p((pk & tl)[pk | tl].mean()), "% celle in cui PK e TlE sono entrambi primi sulla forza incentivante, fra quelle in cui uno dei due lo e'", "PctISTiesPKTLE")

    F = mats["households only"]
    righe = []
    for i, a in enumerate(metodi):
        righe.append([st.nome_metodo(a)] + [p(F.loc[a, b], 1) if j < i else "" for j, b in enumerate(metodi[:-1])])
    tf.tex(pd.DataFrame(righe[1:], columns=["Mechanism"] + [SIGLA[m] for m in metodi[:-1]]),
           D["out"] / "tabelle" / "allocation_distance", "l" + "r" * (len(metodi) - 1))


# ---------------------------------------------------------------------------- 3. stabilita'
def stabilita(D, agg: Path):
    T = D["T"].copy()
    T["Nucleo"] = T.EccessoMax_EUR <= 1e-6
    v = T[T.Metodo == VLC]
    controlla(v.Nucleo.all(), "il Variance Least Core e' fuori dal nucleo in qualche comunita'")
    vd = v[v.Gruppo == "households only"]
    taglia = vd.groupby("Membri").agg(Margine_pct=("EccessoMax_pct_vN", "median"), Margine_EUR=("EccessoMax_EUR", "median"))
    taglia.to_csv(agg / "margine_vlc_per_taglia.csv")
    vd.pivot_table(index="Fascia", columns="Membri", values="EccessoMax_pct_vN", aggfunc="median").to_csv(
        agg / "margine_vlc_taglia_fascia.csv")
    n0, n1 = taglia.index.min(), taglia.index.max()
    macro(f(taglia.loc[n0, "Margine_pct"], 1), f"margine VLC (eccesso massimo, % di v(N)), mediana a {n0} membri, domestico", "VLCMarginSmallest")
    macro(f(taglia.loc[n1, "Margine_pct"], 2), f"lo stesso a {n1} membri", "VLCMarginLargest")
    macro(f(taglia.loc[n0, "Margine_EUR"], 0), f"margine VLC in EUR/anno, mediana a {n0} membri, domestico", "VLCMarginEURSmallest")
    macro(f(taglia.loc[n1, "Margine_EUR"], 1), f"lo stesso a {n1} membri", "VLCMarginEURLargest")
    macro(p((v.EccessoMax_pct_vN > -1).mean()), "% comunita' (tutte) con margine VLC sotto l'1% di v(N)", "PctVLCMarginBelowOne")
    macro(p((vd.EccessoMax_pct_vN > -1).mean()), "lo stesso, domestico", "PctVLCMarginBelowOneHouseholds")
    macro(p((v.EccessoMax_pct_vN > -5).mean()), "% comunita' con margine VLC sotto il 5% di v(N) (soglia di rilevanza)", "PctVLCMarginBelowFive")
    if 20 in taglia.index:
        macro(f(taglia.loc[20, "Margine_pct"], 2), "margine VLC, mediana a 20 membri, domestico (% di v(N))", "VLCMarginTwenty")
    # errore dell'AS nella stessa unita' del margine: distanza L1 dallo Shapley esatto in % di v(N)
    f1 = pd.read_csv(agg.parent / "fase1.csv")
    l1 = f1[f1.Misura == "L1_su_vN_pct"]
    controlla(len(l1), "fase1.csv senza la misura L1_su_vN_pct")
    macro(f(l1.mediana.max(), 1), "distanza L1 fra AS e Shapley esatto in % di v(N): massimo delle mediane per taglia (5-18 membri)", "ASLOneVNMax")

    sh = T[(T.Metodo == SH) & (T.Gruppo == "households only")]
    m = sh.pivot_table(index="Fascia", columns="Membri", values="Nucleo", aggfunc="mean")
    m.to_csv(agg / "shapley_nel_nucleo_taglia_fascia.csv")
    for n in m.columns:
        macro(p(m.loc["4", n]), f"% comunita' domestiche di fascia 4 con lo Shapley nel nucleo, {n} membri", "ShapleyCoreBandFourSize", int(n))
    macro(p(m.loc["1", n0]), f"lo stesso in fascia 1 a {n0} membri", "ShapleyCoreBandOneSmallest")
    macro(p(m.loc[["2", "3"]].values.max()), "massimo nelle fasce 2-3, su tutte le taglie", "ShapleyCoreBandsTwoThreeMax")

    gr = T.groupby(["Metodo", "Gruppo"]).agg(Eccesso=("EccessoMax_pct_vN", "median"), Nucleo=("Nucleo", "mean")).reset_index()
    gr.to_csv(agg / "stabilita_per_gruppo.csv", index=False)
    G = gr.set_index(["Metodo", "Gruppo"])
    for g, nome in zip(GRUPPI, ["Households", "Public", "Firms"]):
        macro(p(G.loc[(SH, g), "Nucleo"], 1), f"% comunita' con lo Shapley nel nucleo, {g}", "ShapleyCore", nome)
        macro(f(G.loc[(ES, g), "Eccesso"], 1), f"eccesso massimo mediano dell'Equal Split, % di v(N), {g}", "ExcessES", nome)
        macro(f(G.loc[(WS, g), "Eccesso"], 1), f"eccesso massimo mediano del Weighted Solidarity, % di v(N), {g}", "ExcessWS", nome)
        piu = G.xs(g, level="Gruppo").Eccesso.idxmax()
        macro(st.nome_metodo(piu), f"metodo con l'eccesso mediano piu' alto, {g}", "MostUnstable", nome)
    c = D["com"]
    macro(p((c.Gruppo == "with firms").mean()), "% delle 5900 comunita' con imprese", "PctCommunitiesWithFirms")

    righe = []
    for mt in st.ordina_metodi(gr.Metodo.unique()):
        righe.append([st.nome_metodo(mt)] + [f(G.loc[(mt, g), "Eccesso"], 1) for g in GRUPPI]
                     + [p(G.loc[(mt, g), "Nucleo"], 1) for g in GRUPPI])
    tf.tex(pd.DataFrame(righe, columns=["Mechanism", "Excess, households (%)", "Excess, with PA (%)",
                                        "Excess, with firms (%)", "In core, households (%)",
                                        "In core, with PA (%)", "In core, with firms (%)"]),
           D["out"] / "tabelle" / "stability_by_group", "lrrrrrr")


# ---------------------------------------------------------------------------- 4. comunita' miste
def miste(D, agg: Path):
    q, T = D["qm"], D["T"]
    g = q[q.Gruppo != "households only"]
    per = (g.assign(QND=g.Quota_EUR * ~g.Domestico, ND=~g.Domestico)
           .groupby(["Gruppo", "Replica", "Composizione", "Scheda", "Metodo"])
           .agg(QND=("QND", "sum"), Tot=("Quota_EUR", "sum"), ND=("ND", "sum"), N=("ND", "size")).reset_index())
    per["Quota"] = per.QND / per.Tot
    per["QuotaNumerica"] = per.ND / per.N
    s = per.groupby(["Gruppo", "Metodo"]).agg(Quota=("Quota", "median"), QuotaNumerica=("QuotaNumerica", "median"))
    per.groupby(["Composizione", "Metodo"]).Quota.median().unstack().to_csv(agg / "quota_non_domestici_per_livello.csv")

    h = q[q.Domestico][["Replica", "Composizione", "Scheda", "Metodo", "Membro", "Prosumer", "Quota_EUR"]]
    base = h[h.Composizione == "PA0"].drop(columns="Composizione").rename(columns={"Quota_EUR": "Q0", "Prosumer": "P0"})
    x = h[h.Composizione != "PA0"].merge(base, on=["Replica", "Scheda", "Metodo", "Membro"])
    controlla((x.Prosumer == x.P0).all(), "una famiglia cambia stato prosumer fra livello base e variante")
    x["Delta"] = x.Quota_EUR - x.Q0
    x["Gruppo"] = st.gruppo_comunita(x.Composizione)
    gu = x.groupby(["Gruppo", "Metodo"]).agg(Guadagnano=("Delta", lambda d: (d > 0).mean()), Delta=("Delta", "median"))
    lv = x.groupby(["Composizione", "Metodo"]).agg(Guadagnano=("Delta", lambda d: (d > 0).mean()), Delta=("Delta", "median"))
    lv.reset_index().to_csv(agg / "famiglie_guadagno_per_livello.csv", index=False)
    s.join(gu).reset_index().to_csv(agg / "comunita_miste.csv", index=False)

    for gg, nome in [("with public buildings", "Public"), ("with firms", "Firms")]:
        macro(p(s.loc[(gg, ES), "QuotaNumerica"]), f"quota numerica mediana dei membri non domestici, {gg}", "NumericalShareNonDom", nome)
        for m, nm in [(SU, "SU"), (SH, "Shapley"), (VLC, "VLC"), (PK, "PK"), (PTC, "PtC"), (RM1, "RMOne"), (WS, "WS")]:
            macro(p(s.loc[(gg, m), "Quota"]), f"quota mediana dell'incentivo ai membri non domestici, {m}, {gg}", "ShareNonDom", nm, nome)
        for m, nm in [(SH, "Shapley"), (ES, "ES"), (RM1, "RMOne")]:
            macro(p(gu.loc[(gg, m), "Guadagnano"]), f"% famiglie che guadagnano quando entrano PA o imprese, {m}, {gg}", "HouseholdsGainPct", nm, nome)
            macro(f(gu.loc[(gg, m), "Delta"], 0), f"guadagno mediano per famiglia (EUR/anno), {m}, {gg}", "HouseholdsGainEUR", nm, nome)
    piccoli = [c for c in lv.index.get_level_values(0).unique() if not re.search(r"PA[23]", c)]
    r = lv.xs(RM1, level="Metodo").loc[piccoli]
    macro(p(r.Guadagnano.min()), "Remuneration Model 1: % minima di famiglie che guadagnano, livelli senza PA2/PA3", "RMOneGainPctMin")
    macro(p(r.Guadagnano.max()), "lo stesso, massima", "RMOneGainPctMax")
    macro(f(r.Delta.min(), 0), "Remuneration Model 1: guadagno mediano minimo (EUR/anno), livelli senza PA2/PA3", "RMOneGainEURMin")
    macro(f(r.Delta.max(), 0), "lo stesso, massimo", "RMOneGainEURMax")
    macro(", ".join(piccoli), "livelli senza PA2/PA3", "LevelsWithoutLargePublic")

    # un solo prosumer: quote nulle
    z = T[T.QuoteNulle > 0]
    comz = z.drop_duplicates(["Replica", "Composizione", "Scheda"])
    macro(len(comz), "comunita' in cui almeno un metodo lascia un membro a quota zero", "NumCommunitiesZeroShare")
    macro(", ".join(st.nome_metodo(m) for m in st.ordina_metodi(z.Metodo.unique())), "metodi che lo fanno", "ZeroShareMethods")
    macro(" and ".join(str(int(n)) for n in sorted(comz.Membri.unique())), "taglie", "ZeroShareSizes")
    k = comz[["Replica", "Composizione", "Scheda"]]
    qq = q.merge(k, on=["Replica", "Composizione", "Scheda"])
    np_ = qq[qq.Metodo == ES].groupby(["Replica", "Composizione", "Scheda"]).Prosumer.sum()
    controlla((np_ == 1).all(), "le comunita' con quote nulle non hanno tutte un solo prosumer")
    zero = qq[(qq.Prosumer == 1) & qq.Metodo.isin(z.Metodo.unique())].Quota_EUR
    controlla((zero.abs() < 1e-9).all(), "nelle comunita' con quote nulle non e' il prosumer a prendere zero")
    shq = qq[(qq.Metodo == SH) & (qq.Prosumer == 1)].q
    macro(p(shq.median()), "quota mediana di v(N) data dallo Shapley all'unico prosumer in quelle comunita'", "ShapleyShareSingleProsumer")

    righe = []
    for m in st.ordina_metodi(s.index.get_level_values(1).unique()):
        righe.append([st.nome_metodo(m), p(s.loc[("with public buildings", m), "Quota"]), p(s.loc[("with firms", m), "Quota"]),
                      p(gu.loc[("with public buildings", m), "Guadagnano"]), p(gu.loc[("with firms", m), "Guadagnano"]),
                      f(gu.loc[("with public buildings", m), "Delta"], 0), f(gu.loc[("with firms", m), "Delta"], 0)])
    tf.tex(pd.DataFrame(righe, columns=["Mechanism", "To PA/firms, with PA (%)", "To PA/firms, with firms (%)",
                                        "Households gaining, with PA (%)", "Households gaining, with firms (%)",
                                        "Median gain, with PA (EUR/yr)", "Median gain, with firms (EUR/yr)"]),
           D["out"] / "tabelle" / "mixed_communities", "lrrrrrr")


# ---------------------------------------------------------------------------- 5. VAN senza incentivo
def van(D, agg: Path):
    q = D["qm"][D["qm"].VAN_EUR.notna()]
    w = q.pivot_table(index=["Replica", "Composizione", "Scheda", "Membro"], columns="Metodo", values=["VAN_EUR", "Quota_EUR"])
    dQ = w["Quota_EUR"][ES] - w["Quota_EUR"][SH]
    k = ((w["VAN_EUR"][ES] - w["VAN_EUR"][SH]) / dQ)[dQ.abs() > 1]
    fattore = float(k.median())
    controlla(k.std() / fattore < 1e-6, f"il VAN non e' lineare nella quota con un fattore unico (std {k.std():.3g})")
    macro(f(fattore), "fattore di annualita' del VAN (EUR di VAN per EUR/anno di incentivo)", "NPVAnnuityFactor")
    d = q[(q.Composizione == "PA0") & (q.Prosumer == 1)].assign(VAN0=lambda x: x.VAN_EUR - fattore * x.Quota_EUR)
    controlla(d.groupby(["Replica", "Scheda", "Membro"]).VAN0.std().max() < 1e-6, "VAN senza incentivo diverso fra metodi")
    v0 = d[d.Metodo == ES]
    neg, pos = v0[v0.VAN0 < 0].VAN0, v0[v0.VAN0 >= 0].VAN0
    macro(p((v0.VAN0 < 0).mean()), "% prosumer domestici con VAN negativo senza incentivo", "PctProsumersNegativeNoIncentive")
    macro(f(neg.median(), 0), "VAN senza incentivo, mediana dei negativi (EUR)", "NPVNoIncentiveNegMedian")
    macro(f(neg.quantile(0.05), 0), "lo stesso, 5 percentile", "NPVNoIncentiveNegPFive")
    macro(f(neg.quantile(0.95), 0), "lo stesso, 95 percentile", "NPVNoIncentiveNegPNinetyFive")
    macro(f(pos.median(), 0), "VAN senza incentivo, mediana dei positivi (EUR)", "NPVNoIncentivePosMedian")
    pareggio = -neg / fattore
    macro(f(pareggio.median(), 0), "incentivo annuo di pareggio, mediana (EUR/anno)", "BreakEvenIncentive")
    macro(f(pareggio.quantile(0.9), 0), "lo stesso, 90 percentile", "BreakEvenIncentivePNinety")
    quota = d.groupby("Metodo").Quota_EUR.median()
    for m, nm in [(ES, "ES"), (PK, "PK"), (SU, "SU"), (TLE, "TlE"), (SH, "Shapley"), (VLC, "VLC")]:
        macro(f(quota[m], 0), f"incentivo annuo mediano di un prosumer domestico, {m} (EUR/anno)", "ProsumerIncentive", nm)
    pd.DataFrame({"VAN0": v0.VAN0.describe(percentiles=[.05, .1, .25, .5, .75, .9, .95])}).to_csv(agg / "van_senza_incentivo.csv")
    quota.rename("IncentivoMedianoProsumer_EUR").to_csv(agg / "incentivo_prosumer_per_metodo.csv")


# ---------------------------------------------------------------------------- altro
def altro(D, agg: Path):
    pa = pd.read_csv(agg.parent / "pareto.csv")
    s = pa[pa.InsiemeCriteri == INSIEME_PARETO_LORDO]
    controlla(len(s), f"insieme di Pareto '{INSIEME_PARETO_LORDO}' assente da pareto.csv")
    for m, nm in [(ES, "ES"), (RM1, "RMOne")]:
        macro(p(s[s.Metodo == m].mediana.iloc[0]), f"% comunita' in cui {m} non e' dominato con Gini + allineamento lordo + VAN minimo", "ParetoGross", nm)
    altri = s[(s.mediana >= 0.5) & ~s.Metodo.isin([ES, RM1])]
    macro(len(altri), "altri metodi non dominati in almeno meta' delle comunita' in quell'insieme", "ParetoGrossOthers")
    T = D["T"]
    sf = T[(T.Metodo == SU) & (T.AllineamentoVirtu < 0)]
    macro(len(sf), "comunita' in cui il denominatore della forza incentivante e' negativo (segno invertito)", "NumISSignFlips")
    macro(", ".join(sorted(sf.Composizione.unique())), "livelli di quelle comunita'", "ISSignFlipLevels")


# ---------------------------------------------------------------------------- uscite
def scrivi(out: Path, agg: Path):
    esistenti = set(re.findall(r"\\newcommand\{\\(\w+)\}", (out / "numeri_tesi.tex").read_text(encoding="utf-8"))) \
        if (out / "numeri_tesi.tex").exists() else set()
    doppie = sorted(set(MACRO) & esistenti)
    controlla(not doppie, f"macro gia' presenti in numeri_tesi.tex: {doppie}")
    righe = ["% Numeri aggiuntivi del capitolo 7, generati da CER_repliche/analisi_aggiuntive.py: non modificare a mano.",
             "% Uso: \\input{numeri_aggiuntivi} nel preambolo, accanto a \\input{numeri_tesi}.", ""]
    righe += [f"\\newcommand{{\\{k}}}{{{v.replace('_', chr(92) + '_')}}}  % {d}" for k, (v, d) in sorted(MACRO.items())]
    (out / "numeri_aggiuntivi.tex").write_text("\n".join(righe) + "\n", encoding="utf-8")
    pd.DataFrame([(k, v, d) for k, (v, d) in sorted(MACRO.items())], columns=["Macro", "Valore", "Descrizione"]).to_csv(
        out / "numeri_aggiuntivi.csv", index=False)
    L = ["# Analisi aggiuntive per il capitolo 7", "",
         "Generato da `CER_repliche/analisi_aggiuntive.py` sulle repliche r01-r20. Le macro LaTeX sono in "
         "`outputs/tesi_finale/numeri_aggiuntivi.tex`.", "", "| Macro | Valore | Descrizione |", "|---|---|---|"]
    L += [f"| `\\{k}` | {v} | {d} |" for k, (v, d) in sorted(MACRO.items())]
    (agg / "sintesi_aggiuntive.md").write_text("\n".join(L) + "\n", encoding="utf-8")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--radice", default=str(ROOT / "outputs" / "repliche"))
    ap.add_argument("--blocco", default="unito")
    ap.add_argument("--out", default=str(ROOT / "outputs" / "tesi_finale"))
    a = ap.parse_args(argv)
    cart = Path(a.radice) / a.blocco
    out = Path(a.out)
    agg = cart / "aggregato" / "aggiuntive"
    agg.mkdir(parents=True, exist_ok=True)
    (out / "tabelle").mkdir(parents=True, exist_ok=True)
    D = carica(cart)
    D["out"] = out
    integrita(D)
    for passo in (incentivo_proprieta, entro_gruppo, distanze, stabilita, miste, van, altro):
        passo(D, agg)
        print(f"  fatto: {passo.__name__}")
    scrivi(out, agg)
    print(f"{len(MACRO)} macro in {out / 'numeri_aggiuntivi.tex'}; CSV in {agg}")
    if ERRORI:
        print("\nCONTROLLI DI INTEGRITA' FALLITI:\n- " + "\n- ".join(ERRORI))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
