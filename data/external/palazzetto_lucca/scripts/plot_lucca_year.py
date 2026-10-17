import datetime as dt
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.colors import LinearSegmentedColormap

base, out_png = sys.argv[1], sys.argv[2]
P = np.load(f"{base}/lucca_year_P.npy")                                   # 366 x 24 (kW)
week = pd.read_csv(f"{base}/lucca_settimana_22_28_gen_2024_kW.csv", index_col=0).to_numpy().T.ravel()
i0 = (dt.date(2024, 1, 22) - dt.date(2024, 1, 1)).days
rec = P[i0:i0 + 7].ravel()

SURF, INK, INK2, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#e4e3df"
BLUE, ORANGE = "#2a78d6", "#eb6834"
cmap = LinearSegmentedColormap.from_list("blu", ["#eaf2fc", "#9cc3f0", "#2a78d6", "#123f7a"])

fig = plt.figure(figsize=(11.5, 8.4), facecolor=SURF)
gs = fig.add_gridspec(2, 1, height_ratios=[1.35, 1], hspace=0.42)

# ---- pannello 1: mappa giorno x ora -------------------------------------------------
ax = fig.add_subplot(gs[0])
im = ax.imshow(P.T, aspect="auto", origin="lower", cmap=cmap, vmin=0, vmax=120,
               extent=[0, 366, 0, 24], interpolation="nearest")
starts = [(dt.date(2024, m, 1) - dt.date(2024, 1, 1)).days for m in range(1, 13)]
ax.set_xticks([s + 15 for s in starts])
ax.set_xticklabels(["gen", "feb", "mar", "apr", "mag", "giu", "lug", "ago", "set", "ott", "nov", "dic"],
                   color=INK2, fontsize=9)
for s in starts[1:]:
    ax.axvline(s, color=SURF, linewidth=0.6, alpha=0.6)
ax.set_yticks(range(0, 25, 4))
ax.set_ylabel("Ora del giorno", color=INK2, fontsize=9.5)
ax.tick_params(colors=INK2, length=0, labelsize=9)
for sp in ax.spines.values():
    sp.set_visible(False)
ax.set_title("Palazzetto di Lucca, anno 2024: potenza oraria ricostruita", loc="left",
             fontsize=13, color=INK, fontweight="bold", pad=22)
ax.text(0, 1.02, "Ogni colonna è un giorno. Fermo estivo visibile dal 21 luglio al 19 agosto; picchi serali e di domenica pomeriggio.",
        transform=ax.transAxes, fontsize=9, color=INK2, va="bottom")
cb = fig.colorbar(im, ax=ax, pad=0.015, fraction=0.025)
cb.set_label("kW", color=INK2, fontsize=9)
cb.ax.tick_params(colors=INK2, labelsize=8.5, length=0)
cb.outline.set_visible(False)

# ---- pannello 2: verifica sulla settimana letta ------------------------------------
ax2 = fig.add_subplot(gs[1], facecolor=SURF)
t = np.arange(168)
ax2.plot(t, week, color=BLUE, linewidth=2.0, label="Letta dal grafico del documento (Fig. 4)")
ax2.plot(t, rec, color=ORANGE, linewidth=2.0, label="Ricostruita da massimi e minimi giornalieri")
ax2.set_xlim(0, 167)
ax2.set_ylim(0, 125)
ax2.set_xticks(np.arange(0, 168, 24) + 12)
ax2.set_xticklabels(["lun 22", "mar 23", "mer 24", "gio 25", "ven 26", "sab 27", "dom 28"], color=INK2, fontsize=9)
for x in range(24, 168, 24):
    ax2.axvline(x, color=GRID, linewidth=0.8)
ax2.grid(axis="y", color=GRID, linewidth=0.8)
ax2.set_axisbelow(True)
ax2.set_ylabel("Potenza (kW)", color=INK2, fontsize=9.5)
ax2.tick_params(colors=INK2, length=0, labelsize=9)
for sp in ("top", "right", "left"):
    ax2.spines[sp].set_visible(False)
rmse = np.sqrt(((rec - week) ** 2).mean())
ax2.set_title("Verifica sulla settimana 22-28 gennaio: scarto quadratico medio %.0f kW su un carico medio di %.0f kW"
              % (rmse, week.mean()), loc="left", fontsize=11, color=INK, fontweight="bold", pad=10)
leg = ax2.legend(loc="upper left", frameon=False, fontsize=9, labelcolor=INK2)

fig.text(0.055, 0.012,
         "Fonte: diagnosi energetica del Palazzetto dello Sport di Lucca (Fig. 2, 3, 4); curva ricostruita, non misurata.\n"
         "Massimo e minimo di ogni giorno letti dal grafico annuo; forma oraria dalla settimana tipo; energia mensile uguale a quella del documento.",
         fontsize=8.2, color=INK2, ha="left", va="bottom")
fig.subplots_adjust(left=0.07, right=0.97, top=0.90, bottom=0.09)
fig.savefig(out_png, dpi=170, facecolor=SURF)
print("ok")
