import datetime as dt
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.colors import LinearSegmentedColormap

base, out_png = sys.argv[1], sys.argv[2]
PV = np.load(sys.argv[3])                         # 366 x 24, kW (310,5 kWp)
L = np.load(f"{base}/lucca_year_P.npy")           # 366 x 24, kW carico ricostruito

SURF, INK, INK2, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#e4e3df"
BLUE, ORANGE = "#2a78d6", "#eb6834"
cmap = LinearSegmentedColormap.from_list("arancio", ["#fdf0e9", "#f7bb9d", "#eb6834", "#8a3412"])

# autoconsumo (indicativo: il carico e' esso stesso ricostruito)
used = np.minimum(PV, L)
selfc = used.sum() / PV.sum()
cover = used.sum() / L.sum()
print("autoconsumo (quota del FV usata in sito): %.0f%% | copertura del carico: %.0f%%" % (100 * selfc, 100 * cover))

fig = plt.figure(figsize=(11.5, 8.6), facecolor=SURF)
gs = fig.add_gridspec(2, 1, height_ratios=[1.3, 1], hspace=0.45)

ax = fig.add_subplot(gs[0])
im = ax.imshow(PV.T, aspect="auto", origin="lower", cmap=cmap, vmin=0, vmax=285,
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
ax.set_title("Palazzetto di Lucca: produzione fotovoltaica oraria 2024, 310 kWp", loc="left",
             fontsize=13, color=INK, fontweight="bold", pad=22)
ax.text(0, 1.02, "Ogni colonna è un giorno. Meteo orario dal TMY PVGIS (2005-2023); energia di ogni mese riscalata alla tabella PVGIS-SARAH3 (391,2 MWh/anno).",
        transform=ax.transAxes, fontsize=9, color=INK2, va="bottom")
cb = fig.colorbar(im, ax=ax, pad=0.015, fraction=0.025)
cb.set_label("kW", color=INK2, fontsize=9)
cb.ax.tick_params(colors=INK2, labelsize=8.5, length=0)
cb.outline.set_visible(False)

ax2 = fig.add_subplot(gs[1], facecolor=SURF)
i0 = (dt.date(2024, 6, 10) - dt.date(2024, 1, 1)).days
t = np.arange(168)
ax2.plot(t, L[i0:i0 + 7].ravel(), color=BLUE, linewidth=2.0, label="Carico ricostruito")
ax2.plot(t, PV[i0:i0 + 7].ravel(), color=ORANGE, linewidth=2.0, label="Produzione FV (TMY PVGIS)")
ax2.set_xlim(0, 167)
ax2.set_ylim(0, 300)
ax2.set_xticks(np.arange(0, 168, 24) + 12)
ax2.set_xticklabels(["lun 10", "mar 11", "mer 12", "gio 13", "ven 14", "sab 15", "dom 16"], color=INK2, fontsize=9)
for x in range(24, 168, 24):
    ax2.axvline(x, color=GRID, linewidth=0.8)
ax2.grid(axis="y", color=GRID, linewidth=0.8)
ax2.set_axisbelow(True)
ax2.set_ylabel("Potenza (kW)", color=INK2, fontsize=9.5)
ax2.tick_params(colors=INK2, length=0, labelsize=9)
for sp in ("top", "right", "left"):
    ax2.spines[sp].set_visible(False)
ax2.set_title("Una settimana di giugno: carico e produzione a confronto", loc="left",
              fontsize=11, color=INK, fontweight="bold", pad=10)
ax2.legend(loc="lower right", bbox_to_anchor=(1.0, 1.0), ncol=2, frameon=False, fontsize=9, labelcolor=INK2)

fig.text(0.055, 0.012,
         "Fonte: PVGIS-SARAH3, anno tipico (TMY) e medie mensili a 43,844 N, 10,489 E; moduli a 15° verso sud, perdite 14%; modello di conversione in pvlib.\n"
         "Il TMY è un anno tipico, non il 2024: i giorni nuvolosi sono quelli tipici di ogni mese. Carico ricostruito, non misurato.",
         fontsize=8.2, color=INK2, ha="left", va="bottom")
fig.subplots_adjust(left=0.07, right=0.97, top=0.90, bottom=0.10)
fig.savefig(out_png, dpi=170, facecolor=SURF)
print("ok")
