"""Anteprima della palette proposta (blu Polimi) su dati veri del repository."""
import glob, sys
from pathlib import Path
import numpy as np, pandas as pd, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap

ROOT = Path(sys.argv[1]); OUT = Path(sys.argv[2])
BLU = "#005AA0"
ORD = ["#7FAACB", "#4A82AE", "#005AA0", "#00305A"]                 # fasce 1-4
FAM = {"Cooperative game": ("#005AA0", "o"), "Simple": ("#D9731A", "s"),
       "Synchrony-based": ("#3BA272", "^"), "Literature heuristics": ("#A23B72", "D")}
GRP = {"households only": ("#005AA0", "o"), "with public buildings": ("#D9731A", "s"),
       "with firms": ("#3BA272", "^")}
DIV = LinearSegmentedColormap.from_list("div", ["#D9731A", "#F2F2F2", "#005AA0"])
SEQ = LinearSegmentedColormap.from_list("seq", ["#F4F8FB", "#7FAACB", "#005AA0", "#00305A"])
FAMIGLIA = {"Shapley": "Cooperative game", "Variance Least Core": "Cooperative game",
            "Equal Split": "Simple", "Proportional to Consumption": "Simple",
            "Pearson Key": "Synchrony-based", "Similarity-Utilization": "Synchrony-based",
            "Remuneration Model 1": "Literature heuristics", "Cascading Tree": "Literature heuristics",
            "Weighted Solidarity": "Literature heuristics", "Tri-level EP": "Literature heuristics"}
plt.rcParams.update({"font.size": 8, "axes.spines.top": False, "axes.spines.right": False,
                     "axes.edgecolor": "#888", "axes.grid": True, "grid.color": "#e8e8e8", "grid.linewidth": .5})

rep = sorted(glob.glob(str(ROOT / "outputs/repliche/fino15/r[0-9][0-9]/export")))
tf = pd.concat([pd.read_csv(Path(d) / "tfair_lungo.csv").assign(Replica=int(Path(d).parent.name[1:])) for d in rep])
tf = tf[(tf.Replica >= 1) & (tf.Composizione == "PA0") & (tf.Metodo != "Nucleolo")]
tf.loc[tf.Metodo == "Adaptive Sampling Shapley", "Metodo"] = "AS (dropped)"
tf = tf[tf.Metodo != "AS (dropped)"]
tf["Fascia"] = tf.groupby(["Replica", "Membri"]).Penetrazione_pct.rank(method="dense").astype(int)
com = pd.concat([pd.read_csv(f) for f in glob.glob(str(ROOT / "outputs/repliche/*/r[0-9][0-9]/export/comunita.csv"))
                 if "/r00/" not in f])
tau = pd.read_csv(ROOT / "outputs/repliche/fino15/aggregato/tau.csv")

fig, ax = plt.subplots(2, 2, figsize=(11, 7.5))
rng = np.random.default_rng(0)
# (a) ordinale: fasce di penetrazione
a = ax[0, 0]; metodi = list(FAMIGLIA)
for j, m in enumerate(metodi):
    for f in range(1, 5):
        s = tf[(tf.Metodo == m) & (tf.Fascia == f)].Gini
        y = j + (f - 2.5) * 0.17
        a.scatter(s, y + rng.uniform(-.05, .05, len(s)), s=4, color=ORD[f - 1], lw=0, alpha=.5)
        a.plot([s.median()] * 2, [y - .08, y + .08], color="#222", lw=1.2)
a.set_yticks(range(len(metodi)), metodi); a.invert_yaxis(); a.set_xlabel("Gini of savings (lower = more equal)")
for f in range(4): a.scatter([], [], color=ORD[f], s=20, label=f"band {f+1}")
a.legend(frameon=False, title="prosumer penetration", loc="lower right", fontsize=7)
a.set_title("(a) ORDINAL - one Polimi-blue ramp for the 4 penetration bands", loc="left", fontsize=8.5)
# (b) categoriale: famiglie, con marker diversi (codifica secondaria)
b = ax[0, 1]
med = tf.groupby("Metodo")[["FairnessIndex", "ForzaIncentivante"]].median()
for m, r in med.iterrows():
    c, mk = FAM[FAMIGLIA[m]]
    b.scatter(r.FairnessIndex, r.ForzaIncentivante, color=c, marker=mk, s=60, ec="white", lw=1.2, zorder=3)
    b.annotate(m, (r.FairnessIndex, r.ForzaIncentivante), xytext=(5, 3), textcoords="offset points", fontsize=7, color="#333")
for k, (c, mk) in FAM.items(): b.scatter([], [], color=c, marker=mk, s=40, label=k)
b.legend(frameon=False, fontsize=7, loc="best"); b.set_xlabel("Fairness Index (median, lower = closer to merit)")
b.set_ylabel("Incentive strength (median)")
b.set_title("(b) CATEGORICAL - 4 families: distinct hues + markers + labels", loc="left", fontsize=8.5)
# (c) divergente: tau mediano per fascia
c_ = ax[1, 0]
ind = ["Gini", "FairnessIndex", "EccessoMax_EUR", "ForzaIncentivante", "AllineamentoVirtu_lordo"]
t = tau[tau.IndicatoreA.isin(ind) & tau.IndicatoreB.isin(ind)]
t = t.assign(Coppia=t.IndicatoreA + " – " + t.IndicatoreB).pivot_table(index="Coppia", columns="Fascia", values="mediana")
im = c_.imshow(t.values, cmap=DIV, vmin=-1, vmax=1, aspect="auto")
c_.set_yticks(range(len(t)), t.index, fontsize=6.5); c_.set_xticks(range(t.shape[1]), [f"band {x}" for x in t.columns])
for i in range(t.shape[0]):
    for j in range(t.shape[1]):
        v = t.values[i, j]
        c_.text(j, i, f"{v:+.2f}", ha="center", va="center", fontsize=6.5, color="white" if abs(v) > .6 else "#222")
c_.grid(False); fig.colorbar(im, ax=c_, shrink=.8, label="Kendall τ-b (median of 20 replicas)")
c_.set_title("(c) DIVERGING - orange ↔ grey ↔ Polimi blue for τ (−1…+1)", loc="left", fontsize=8.5)
# (d) gruppi di comunita': soglia regolatoria su tutte le repliche
d = ax[1, 1]
com["Gruppo"] = np.where(com.Composizione == "PA0", "households only",
                         np.where(com.Composizione.str.startswith("ND"), "with firms", "with public buildings"))
for g, (col, mk) in GRP.items():
    s = com[com.Gruppo == g]
    d.scatter(s.Penetrazione_pct + rng.uniform(-1.2, 1.2, len(s)), 100 * s.QuotaIncentivata, s=7, color=col,
              marker=mk, lw=.2, ec="white", alpha=.7, label=f"{g} ({len(s)})")
d.axhline(55, color="#222", lw=1); d.text(101, 56.5, "55% threshold", ha="right", fontsize=7)
d.set_xlabel("prosumer penetration [%]"); d.set_ylabel("shared / injected energy [%]")
d.legend(frameon=False, fontsize=7, loc="upper right")
d.set_title("(d) CATEGORICAL, 3 groups - real data: threshold across replicas r01-r20", loc="left", fontsize=8.5)
fig.suptitle("Proposed palette (Polimi blue #005AA0 as anchor) on real data of the repository", fontsize=10)
fig.tight_layout(); fig.savefig(OUT, dpi=170)
print("ok", OUT)
