"""Estrae dai risultati finali (13/10/2026) i numeri per l'interfaccia. Uso:
python -I dati_interfaccia.py <root progetto> <file json di uscita>"""
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd

R = Path(sys.argv[1])
T18, T25 = R / "outputs/tables_main2", R / "outputs/tables_main2_griglia25"
E18, E25 = R / "outputs/workspace/export_fino18", R / "outputs/workspace/export_griglia25"
out = {}


def r(x, k=3):
    return None if x is None or (isinstance(x, float) and np.isnan(x)) else round(float(x), k)


# --- comunita' --------------------------------------------------------------
def comunita(E):
    c = pd.read_csv(E / "comunita.csv").sort_values(["Membri", "Penetrazione_pct"])
    c["Fascia"] = c.groupby("Membri")["Penetrazione_pct"].rank(method="first").astype(int)
    return c

c18, c25 = comunita(E18), comunita(E25)
fascia = {**dict(zip(c25.Scheda, c25.Fascia))}
out["comunita"] = [dict(scheda=s, n=int(n), fascia=int(f), pen=r(p, 1), np=int(npr), vN=r(v, 1),
                        cont=r(100 * q, 1), inc=r(100 * qi, 1))
                   for s, n, f, p, npr, v, q, qi in zip(c25.Scheda, c25.Membri, c25.Fascia, c25.Penetrazione_pct,
                                                        c25.NProsumer, c25.vN_EUR, c25.QuotaContendibile,
                                                        c25.QuotaIncentivata)]

# --- vincitori: presenza fra i primi (pari compresi), fino a 18 -------------
g = pd.read_csv(T18 / "confronto/griglia_vincitori.csv")
ind_vinc = ["Gini", "FairnessIndex", "EccessoMax_EUR", "InclusioneLIHC", "ForzaIncentivante", "VAN_min_EUR"]
metodi = ["Shapley", "Nucleolo", "Variance Least Core", "Equal Split", "Proportional to Consumption",
          "Remuneration Model 1", "Cascading Tree", "Weighted Solidarity", "Pearson Key",
          "Similarity-Utilization", "Tri-level EP"]
pres = {}
for ind in ind_vinc:
    gi = g[g.Indicatore == ind]
    tot = len(gi.dropna(subset=["PrimiAPari"]))
    row = {}
    for m in metodi:
        k = gi.PrimiAPari.fillna("").apply(lambda s: m in [x.strip() for x in s.split("=")]).sum()
        row[m] = int(k)
    pres[ind] = dict(tot=int(tot), conte=row)
out["vincitori"] = dict(indicatori=ind_vinc, metodi=metodi, presenza=pres)

# --- tau medio fra indicatori, fino a 18 ------------------------------------
a = pd.read_csv(T18 / "confronto/accordo_indicatori.csv")
ind_tau = ["Gini", "VAN_min_EUR", "FairnessIndex", "Sigma", "EccessoMax_EUR", "CoalizioniInstabili",
           "InclusioneLIHC", "ForzaIncentivante", "AllineamentoVirtu", "AllineamentoVirtu_lordo"]
a = a[a.IndicatoreA.isin(ind_tau) & a.IndicatoreB.isin(ind_tau)]
m = a.groupby(["IndicatoreA", "IndicatoreB"]).TauB.mean()
out["tau"] = dict(indicatori=ind_tau,
                  matrice=[[1.0 if x == y else r(m.get((x, y), np.nan), 2) for y in ind_tau] for x in ind_tau])

# --- inversioni per sweep: due run + sensibilita' ----------------------------
def sweep(T):
    p = pd.read_csv(T / "confronto/inversioni_per_sweep.csv")
    return [dict(sweep=s, fisso=f, quota=r(100 * q, 1)) for s, f, q in zip(p.Sweep, p.Fisso, p.QuotaInvertite)]
out["inversioni"] = dict(fino18=sweep(T18), griglia25=sweep(T25))
sens = {}
for nome, T in (("fino18", T18), ("griglia25", T25)):
    s = pd.read_csv(T / "sintesi/sensibilita_soglia_sweep.csv")
    sens[nome] = [dict(soglia=r(100 * fe, 0), sweep=sw, fisso=f, quota=r(100 * q, 1))
                  for fe, sw, f, q in zip(s.FracEscursione, s.Sweep, s.Fisso, s.QuotaInvertite)]
    v = pd.read_csv(T / "sintesi/sensibilita_soglia_vincitori.csv")
    sens[nome + "_vincitori"] = v.to_dict(orient="records")
out["sensibilita"] = sens

# --- quote ai prosumer: rapporto per metodo e fascia (fasce 1-3) ------------
q = pd.read_csv(T18 / "sintesi/quote_prosumer.csv")
q = q[q.Fascia < 4]
qp = q.pivot_table(index="Metodo", columns="Fascia", values="RapportoAllaQuotaDiMembri")
pen_f = q.groupby("Fascia").Penetrazione_pct.mean()
out["prosumer"] = dict(fasce=[int(f) for f in qp.columns], pen=[r(pen_f[f], 0) for f in qp.columns],
                       righe=[dict(metodo=mm, valori=[r(v, 2) for v in qp.loc[mm]]) for mm in metodi])

# --- perdite fra criteri (lettura ottimistica), fino a 18 -------------------
ind_p = ["Gini", "FairnessIndex", "EccessoMax_EUR", "InclusioneLIHC", "ForzaIncentivante", "VAN_min_EUR"]
p = pd.read_csv(T18 / "sintesi/perdite_tradeoff.csv").set_index(["Scelto", "Perde"])
out["perdite"] = dict(indicatori=ind_p,
                      ott=[[None if x == y else r(p.loc[(x, y), "PerditaOttimistica_medio"], 2) for y in ind_p] for x in ind_p],
                      pes=[[None if x == y else r(p.loc[(x, y), "PerditaPessimistica_medio"], 2) for y in ind_p] for x in ind_p],
                      pctvN=[[None if x == y else r(p.loc[(x, y), "Perdita_pct_vN_ott_medio"], 1) for y in ind_p] for x in ind_p])

# --- profilo dei metodi: rimpianto medio ------------------------------------
rm = pd.read_csv(T18 / "sintesi/rimpianto_medio.csv").set_index(["Metodo", "Indicatore"])
out["rimpianto"] = dict(indicatori=ind_p, metodi=metodi,
                        valori=[[r(rm.loc[(mm, i), "Rimpianto_medio"], 2) for i in ind_p] for mm in metodi])

# --- sottoinsieme minimo -----------------------------------------------------
def cluster(T):
    cg = pd.read_csv(T / "sintesi/cluster_gruppi.csv")
    cs = pd.read_csv(T / "sintesi/cluster_sufficienza.csv")
    cp = pd.read_csv(T / "sintesi/cluster_pareto.csv")
    gr = cg[cg.TaglioTau == 0.5]
    suf = cs[cs.TaglioTau == 0.5]
    return dict(gruppi=[dict(rap=rp, ind=i.split("; "), tau=r(t, 2)) for rp, i, t in
                        zip(gr.Rappresentante, gr.Indicatori, gr.TauMedioInterno)],
                conc=[dict(ind=i, rap=rp, conc=r(c, 3)) for i, rp, c in zip(suf.Indicatore, suf.Rappresentante, suf.ConcordanzaCoppie)],
                ngruppi={str(t): int((cg.TaglioTau == t).sum()) for t in sorted(cg.TaglioTau.unique())},
                pareto=dict(uguali=int(cp.Coincidono.sum()), tot=len(cp)))
out["cluster"] = dict(fino18=cluster(T18), griglia25=cluster(T25))

# --- stabilita': eccesso del Nucleolo (% v(N)) per taglia e fascia ----------
tf = pd.read_csv(E18 / "tfair_lungo.csv")
tf["Fascia"] = tf.Scheda.map(fascia)
nu = tf[tf.Metodo == "Nucleolo"].pivot_table(index="Membri", columns="Fascia", values="EccessoMax_pct_vN")
out["nucleolo"] = dict(taglie=[int(x) for x in nu.index], fasce=[int(f) for f in nu.columns],
                       valori=[[r(v, 2) for v in nu.loc[t]] for t in nu.index])
ecc = tf.groupby("Metodo").EccessoMax_pct_vN.mean()
out["eccesso_medio"] = [dict(metodo=mm, v=r(ecc[mm], 1)) for mm in metodi]

# --- forza incentivante netta per fascia -------------------------------------
fz = tf.pivot_table(index="Metodo", columns="Fascia", values="ForzaIncentivante")
out["forza"] = dict(fasce=[int(f) for f in fz.columns], righe=[dict(metodo=mm, valori=[r(v, 2) for v in fz.loc[mm]]) for mm in metodi])

# --- VAN dei prosumer -----------------------------------------------------------
qm = pd.read_csv(E18 / "quote_membri.csv")
qm["Fascia"] = qm.Scheda.map(fascia)
pv = qm[qm.Prosumer == 1]
out["van"] = dict(fasce=[1, 2, 3, 4],
                  medio=[r(pv[pv.Fascia == f].VAN_EUR.mean(), 0) for f in [1, 2, 3, 4]],
                  negativi=[r(100 * (pv[pv.Fascia == f].VAN_EUR < 0).mean(), 0) for f in [1, 2, 3, 4]],
                  spread_mediano=r(qm.groupby(["Scheda", "Membro"]).VAN_EUR.agg(lambda x: x.max() - x.min()).median(), 0))

# --- Shapley vs AS -----------------------------------------------------------
f1 = pd.read_csv(T18 / "fase1/regime_le18_Shapley_vs_AS_per_taglia.csv")
out["shapley_as"] = f1.round(3).to_dict(orient="records")

# --- inclusione: media per metodo (dove definita) ------------------------------
inc = tf.groupby("Metodo").InclusioneLIHC.mean()
out["inclusione"] = [dict(metodo=mm, v=r(inc[mm], 2)) for mm in metodi]

json.dump(out, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
print("ok", len(json.dumps(out)), "byte")
