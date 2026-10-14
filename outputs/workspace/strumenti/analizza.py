"""Analisi del run fino a 18 membri. Uso: python -I analizza.py <export_dir> <tables_dir>"""
import sys
import numpy as np
import pandas as pd

pd.set_option("display.width", 250)
pd.set_option("display.max_columns", 40)
pd.set_option("display.max_rows", 400)
pd.set_option("display.float_format", lambda x: f"{x:,.3f}")

EXP, TAB = sys.argv[1], sys.argv[2]
com = pd.read_csv(f"{EXP}/comunita.csv")
tf = pd.read_csv(f"{EXP}/tfair_lungo.csv")
sc = pd.read_csv(f"{EXP}/punteggi_orientati.csv")
qm = pd.read_csv(f"{EXP}/quote_membri.csv")
vir = pd.read_csv(f"{EXP}/virtuosita.csv")

# fascia = rango della penetrazione dentro la taglia
com = com.sort_values(["Membri", "Penetrazione_pct"]).reset_index(drop=True)
com["Fascia"] = com.groupby("Membri")["Penetrazione_pct"].rank(method="first").astype(int)
fascia = dict(zip(com.Scheda, com.Fascia))
taglia = dict(zip(com.Scheda, com.Membri))
vN = dict(zip(com.Scheda, com.vN_EUR))
for d in (tf, sc, qm):
    d["Fascia"] = d.Scheda.map(fascia)
    d["Membri"] = d.Scheda.map(taglia)


def titolo(t):
    print("\n" + "=" * 100 + f"\n{t}\n" + "=" * 100)


# ---------------------------------------------------------------- 1
titolo("1) COMUNITA': montepremi, energia, contendibile, soglia regolatoria")
c = com.copy()
c["vN_per_membro"] = c.vN_EUR / c.Membri
c["Incentivata_pct"] = 100 * c.QuotaIncentivata
c["Margine55_pt"] = 55 - c.Incentivata_pct
c["Margine45_pt"] = 45 - c.Incentivata_pct
c["Contendibile_pct"] = 100 * c.QuotaContendibile
print(c[["Scheda", "Membri", "Fascia", "Penetrazione_pct", "vN_EUR", "vN_per_membro", "Condivisa_kWh",
         "NonCondivisa_kWh", "Contendibile_pct", "Incentivata_pct", "Margine55_pt", "Margine45_pt",
         "Binding"]].to_string(index=False))
print(f"\nBinding (55%): {int(c.Binding.sum())}/{len(c)}; sarebbero binding al 45%: "
      f"{', '.join(c.loc[c.Margine45_pt < 0, 'Scheda'])}")

# ---------------------------------------------------------------- 2
titolo("2) SHAPLEY ESATTO vs ADAPTIVE SAMPLING")
f1 = pd.read_csv(f"{TAB}/fase1/regime_le18_Shapley_vs_AS_per_taglia.csv")
print(f1.to_string(index=False))
f1c = pd.read_csv(f"{TAB}/fase1/regime_le18_Shapley_vs_AS_per_CER.csv")
print("\nCER peggiori per RD_max:")
print(f1c.sort_values("RD_max_pct", ascending=False).head(5).to_string(index=False))
f1m = pd.read_csv(f"{TAB}/fase1/regime_le18_Shapley_vs_AS_per_membro.csv")
big = f1m[f1m.Scarto_rel_pct.abs() > 3]
print(f"\nMembri con scarto relativo > 3%: {len(big)} su {len(f1m)}; quota media di questi sul totale "
      f"Shapley: {big.ShapleyEsatto_EUR.mean():.2f} EUR (media generale {f1m.ShapleyEsatto_EUR.mean():.2f})")

# ---------------------------------------------------------------- 3
titolo("3) VINCITORI per indicatore (punteggi orientati, pareggio = soglia di rilevanza di MAIN2)")
ind_all = list(dict.fromkeys(sc.Indicatore))
metodi = list(dict.fromkeys(sc.Metodo))
win_rows = []
for (s, ind), g in sc.groupby(["Scheda", "Indicatore"]):
    g = g.dropna(subset=["PunteggioOrientato"])
    if g.empty or not g.Discrimina.iloc[0]:
        continue
    best = g.PunteggioOrientato.max()
    tol = g.TolPareggio.iloc[0]
    rng = best - g.PunteggioOrientato.min()
    tied = g[g.PunteggioOrientato >= best - tol].Metodo.tolist()
    second = g.PunteggioOrientato.nlargest(2).iloc[-1]
    win_rows.append(dict(Scheda=s, Indicatore=ind, Vincitore=g.loc[g.PunteggioOrientato.idxmax(), "Metodo"],
                         NPari=len(tied), Pari="; ".join(tied),
                         DistaccoRel=(best - second) / rng if rng > 0 else np.nan))
W = pd.DataFrame(win_rows)
W["Fascia"] = W.Scheda.map(fascia)
for ind in ind_all:
    w = W[W.Indicatore == ind]
    if w.empty:
        print(f"{ind:26s} mai discriminante")
        continue
    cnt = w.Vincitore.value_counts()
    print(f"{ind:26s} n={len(w):2d}  " + ", ".join(f"{m} {k}" for m, k in cnt.items())
          + f"  | pari medi {w.NPari.mean():.1f}, distacco rel. medio {w.DistaccoRel.mean():.2f}")

# ---------------------------------------------------------------- 4
titolo("4) ACCORDO FRA INDICATORI: tau-b medio sulle comunita' (tolleranza numerica)")
acc = pd.read_csv(f"{TAB}/confronto/accordo_indicatori.csv")
acc = acc[acc.IndicatoreA != acc.IndicatoreB]
inds = [i for i in ind_all if i in set(acc.IndicatoreA)]
T = acc.pivot_table(index="IndicatoreA", columns="IndicatoreB", values="TauB", aggfunc="mean").reindex(index=inds, columns=inds)
abbr = {i: i.replace("ForzaIncentivante", "FI_").replace("AllineamentoVirtu", "AV_").replace("_lordo", "L")
        .replace("EccessoMax_EUR", "Ecc").replace("CoalizioniInstabili", "CoalI").replace("FairnessIndex", "FairIdx")
        .replace("VAN_min_EUR", "VANmin").replace("QuoteNulle", "QNull") for i in inds}
print(T.rename(index=abbr, columns=abbr).to_string())
Tn = acc.pivot_table(index="IndicatoreA", columns="IndicatoreB", values="TauB", aggfunc="count").reindex(index=inds, columns=inds)
print("\nNumero di comunita' su cui il tau e' definito:")
print(Tn.rename(index=abbr, columns=abbr).fillna(0).astype(int).to_string())
sd = acc.pivot_table(index="IndicatoreA", columns="IndicatoreB", values="TauB", aggfunc="std").reindex(index=inds, columns=inds)
neg = acc.groupby(["IndicatoreA", "IndicatoreB"]).TauB.agg(lambda x: (x > 0).mean())

# ---------------------------------------------------------------- 5
titolo("5) [ESPLORATIVO] SOTTOINSIEME MINIMO: raggruppamento gerarchico average-linkage su d = 1 - tau medio")
use = [i for i in inds if (Tn.loc[i].drop(i) >= 5).sum() >= len(inds) - 2]  # tau definito quasi ovunque
D = (1 - T.loc[use, use]).copy()
np.fill_diagonal(D.values, 0)
clusters = {i: [i] for i in use}
dist = {(a, b): D.loc[a, b] for a in use for b in use if a != b}
merges = []
while len(clusters) > 1:
    keys = list(clusters)
    best = None
    for ii, a in enumerate(keys):
        for b in keys[ii + 1:]:
            vals = [D.loc[x, y] for x in clusters[a] for y in clusters[b] if not np.isnan(D.loc[x, y])]
            if not vals:
                continue
            d = np.mean(vals)
            if best is None or d < best[0]:
                best = (d, a, b)
    if best is None:
        break
    d, a, b = best
    merges.append((d, list(clusters[a]), list(clusters[b])))
    clusters[a] = clusters[a] + clusters[b]
    del clusters[b]
for d, a, b in merges:
    print(f"  d={d:5.2f} (tau~{1-d:+.2f})  unisce {a}  +  {b}")
for cut in (0.3, 0.5, 0.7):
    cl = {i: [i] for i in use}
    for d, a, b in merges:
        if d > cut:
            break
        ka = next(k for k, v in cl.items() if a[0] in v)
        kb = next(k for k, v in cl.items() if b[0] in v)
        cl[ka] += cl[kb]
        del cl[kb]
    print(f"\n  taglio d<={cut} (tau medio >= {1-cut:.1f}): {len(cl)} gruppi")
    for v in cl.values():
        rep = max(v, key=lambda x: (T.loc[x, v].drop(x).mean() if len(v) > 1 else 1)) if len(v) > 1 else v[0]
        print(f"     {v}   -> rappresentante: {rep}")
print(f"  (esclusi per tau poco definito: {[i for i in inds if i not in use]})")

# ---------------------------------------------------------------- 6
titolo("6) [ESPLORATIVO] ENTITA' DEI TRADE-OFF: perdita su B scegliendo il migliore su A")
print("   perdita = (max_B - B(scelto)) / (max_B - min_B), media sulle comunita'; 0 = nessun costo, 1 = il peggiore su B")
norm = ["EI_orig", "Gini", "FairnessIndex", "Sigma", "EccessoMax_EUR", "CoalizioniInstabili",
        "ForzaIncentivante", "ForzaIncentivante_lordo", "VAN_min_EUR"]
norm = [i for i in norm if i in inds]
L = pd.DataFrame(np.nan, index=norm, columns=norm)
Leur = pd.DataFrame(np.nan, index=norm, columns=norm)
for A in norm:
    for B in norm:
        if A == B:
            continue
        vals, veur = [], []
        for s, g in sc.groupby("Scheda"):
            ga = g[g.Indicatore == A].set_index("Metodo").PunteggioOrientato
            gb = g[g.Indicatore == B].set_index("Metodo").PunteggioOrientato
            ok = ga.notna() & gb.notna()
            ga, gb = ga[ok], gb[ok]
            if len(ga) < 3 or gb.max() - gb.min() <= 0 or ga.max() - ga.min() <= 0:
                continue
            tol = g[g.Indicatore == A].TolPareggio.iloc[0]
            tied = ga[ga >= ga.max() - tol].index
            chosen = gb[tied].max()  # lettura ottimistica: fra i pari su A, il migliore su B
            vals.append((gb.max() - chosen) / (gb.max() - gb.min()))
            if B in ("EccessoMax_EUR", "VAN_min_EUR"):
                veur.append(100 * (gb.max() - chosen) / vN[s])
        if vals:
            L.loc[A, B] = np.mean(vals)
        if veur:
            Leur.loc[A, B] = np.mean(veur)
print(L.rename(index=abbr, columns=abbr).to_string())
print("\n   stessa perdita in % di v(N) per le colonne in euro (EccessoMax, VAN_min):")
print(Leur[["EccessoMax_EUR", "VAN_min_EUR"]].rename(index=abbr, columns=abbr).to_string())

# ---------------------------------------------------------------- 7
titolo("7) [ESPLORATIVO] QUANTO SI SOMIGLIANO I METODI: valore spostato fra due metodi, % di v(N)")
qm["q"] = qm.Quota_EUR / qm.Scheda.map(vN)
P = {}
for s, g in qm.groupby("Scheda"):
    w = g.pivot(index="Membro", columns="Metodo", values="q")
    for a in w.columns:
        for b in w.columns:
            P.setdefault((a, b), []).append(50 * (w[a] - w[b]).abs().sum())
mlist = sorted({a for a, _ in P})
TV = pd.DataFrame([[np.mean(P[(a, b)]) for b in mlist] for a in mlist], index=mlist, columns=mlist)
short = {m: "".join(w[0] for w in m.replace("-", " ").split())[:5] for m in mlist}
print(TV.rename(index=short, columns=short).to_string())
print("   legenda:", ", ".join(f"{v}={k}" for k, v in short.items()))
for m in mlist:
    nn = TV.loc[m].drop(m).nsmallest(2)
    print(f"   {m:30s} piu' vicini: " + ", ".join(f"{k} {v:.1f}%" for k, v in nn.items()))

# ---------------------------------------------------------------- 8
titolo("8) QUOTE AI PROSUMER: rapporto quota di v(N) / quota di membri, per fascia e per taglia")
qq = qm.groupby(["Scheda", "Metodo"]).apply(lambda g: g.loc[g.Prosumer == 1, "q"].sum(), include_groups=False).rename("QP").reset_index()
qq["pen"] = qq.Scheda.map(dict(zip(com.Scheda, com.Penetrazione_pct))) / 100
qq["R"] = qq.QP / qq.pen
qq["Fascia"] = qq.Scheda.map(fascia)
qq["Membri"] = qq.Scheda.map(taglia)
q3 = qq[qq.Fascia < 4]
print(q3.pivot_table(index="Metodo", columns="Fascia", values="R").to_string())
print()
print(q3.pivot_table(index="Metodo", columns="Membri", values="R").to_string())

# ---------------------------------------------------------------- 9
titolo("9) FORZA INCENTIVANTE: netta contro lorda")
fz = tf.pivot_table(index="Metodo", columns="Fascia", values="ForzaIncentivante")
fl = tf.pivot_table(index="Metodo", columns="Fascia", values="ForzaIncentivante_lordo")
print("IS netta, media per fascia:\n" + fz.to_string())
print("\nIS lorda, media per fascia:\n" + fl.to_string())
sg = tf.assign(conc=np.sign(tf.ForzaIncentivante) == np.sign(tf.ForzaIncentivante_lordo)).groupby("Metodo").conc.mean()
print("\nQuota di comunita' in cui netta e lorda hanno lo stesso segno:\n" + sg.to_string())
cosv = []
for s, g in vir.groupby("Scheda"):
    a, b = g.VirtuositaNetta - g.VirtuositaNetta.mean(), g.VirtuositaLorda - g.VirtuositaLorda.mean()
    den = np.linalg.norm(a) * np.linalg.norm(b)
    cosv.append(dict(Scheda=s, Membri=taglia[s], Fascia=fascia[s], cos=(a @ b) / den if den > 0 else np.nan))
cv = pd.DataFrame(cosv)
print("\nCoseno fra asse netto e lordo, per fascia:\n" + cv.pivot_table(index="Membri", columns="Fascia", values="cos").to_string())

# ---------------------------------------------------------------- 10
titolo("10) STABILITA': eccesso massimo in % di v(N) e coalizioni instabili")
tf["Ecc_pct"] = 100 * tf.EccessoMax_EUR / tf.vN_EUR
print(tf.pivot_table(index="Metodo", columns="Fascia", values="Ecc_pct").to_string())
print("\nCoalizioni instabili, media per fascia:")
print(tf.pivot_table(index="Metodo", columns="Fascia", values="CoalizioniInstabili").to_string())
core = tf.assign(nelCore=tf.EccessoMax_EUR <= 1e-6 * tf.vN_EUR).groupby("Scheda").nelCore.sum()
nuc = tf[tf.Metodo == "Nucleolo"].set_index("Scheda").Ecc_pct
print("\nPer comunita': eccesso del Nucleolo (% v(N), <=0 = core non vuoto) e quanti metodi stanno nel core:")
print(pd.DataFrame({"EccNucleolo_pct": nuc, "MetodiNelCore": core}).assign(
    Membri=lambda d: d.index.map(taglia), Fascia=lambda d: d.index.map(fascia)).sort_values(["Membri", "Fascia"]).to_string())

# ---------------------------------------------------------------- 11
titolo("11) SOSTENIBILITA' ECONOMICA: VAN per membro")
qv = qm.dropna(subset=["VAN_EUR"])
if qv.empty:
    print("nessun VAN")
else:
    g = qv.groupby(["Metodo"]).agg(VANmin=("VAN_EUR", "min"), VANmedio=("VAN_EUR", "mean"),
                                    QuotaNeg=("VAN_EUR", lambda x: (x < 0).mean()))
    print(g.to_string())
    print("\nVAN medio per ruolo e fascia (media sui metodi):")
    print(qv.pivot_table(index="Prosumer", columns="Fascia", values="VAN_EUR").to_string())
    print("\nQuota di membri con VAN < 0, per ruolo e fascia:")
    print(qv.assign(neg=qv.VAN_EUR < 0).pivot_table(index="Prosumer", columns="Fascia", values="neg").to_string())
    spread = qv.groupby(["Scheda", "Membro"]).VAN_EUR.agg(lambda x: x.max() - x.min())
    lvl = qv.groupby(["Scheda", "Membro"]).VAN_EUR.agg(lambda x: x.abs().mean())
    print(f"\nEscursione del VAN di un membro fra i metodi: mediana {spread.median():.1f} EUR, "
          f"contro |VAN| medio {lvl.median():.1f} EUR: il metodo sposta il VAN del {100*spread.median()/lvl.median():.0f}% del suo livello")
    cons = qv[qv.Prosumer == 0]
    sign_all_neg = cons.groupby(["Scheda", "Membro"]).VAN_EUR.max() < 0
    print(f"Consumatori con VAN negativo con QUALUNQUE metodo: {sign_all_neg.sum()} su {len(sign_all_neg)}")

# ---------------------------------------------------------------- 12
titolo("12) INVERSIONI DI GRADUATORIA")
ps = pd.read_csv(f"{TAB}/confronto/inversioni_per_sweep.csv")
print(ps.to_string(index=False))
so = pd.read_csv(f"{TAB}/confronto/inversioni_sommario.csv")
pen_sw = so[so.Sweep == "penetrazione"]
print("\nSweep di penetrazione - quota di coppie che si invertono, per indicatore:")
print(pen_sw.groupby("Indicatore").agg(Serie=("nInversioni", "size"), QuotaInvertite=("nInversioni", lambda x: (x > 0).mean()),
                                       QuotaInvertiteEstremi=("InvertitoAgliEstremi", "mean")).sort_values("QuotaInvertite").to_string())
print("\nCoppie di metodi piu' instabili (quota di serie invertite su tutti gli indicatori normativi, sweep di penetrazione):")
nn = pen_sw[pen_sw.Indicatore.isin(["EI_orig", "Gini", "FairnessIndex", "Sigma", "EccessoMax_EUR", "VAN_min_EUR"])]
pp = nn.groupby(["MetodoA", "MetodoB"]).nInversioni.agg(lambda x: (x > 0).mean()).sort_values(ascending=False)
print(pp.head(12).to_string())
print("...coppie piu' stabili:")
print(pp.tail(8).to_string())

# ---------------------------------------------------------------- 13
titolo("13) INDICATORI PER METODO, media su tutte le comunita' (valori grezzi)")
cols = ["Gini", "FairnessIndex", "Sigma", "QuoteNulle", "Ecc_pct", "CoalizioniInstabili", "ForzaIncentivante", "ForzaIncentivante_lordo"]
print(tf.groupby("Metodo")[cols].mean().to_string())
