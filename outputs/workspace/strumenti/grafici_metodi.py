"""Figure e numeri per la tesi, generati dalle tabelle dei run (nessun valore scritto a mano).

Uso, dalla root del progetto:
    python -I outputs/workspace/strumenti/grafici_metodi.py \
        [--tabelle outputs/tables_main2] [--export outputs/workspace/export_fino18] \
        [--out outputs/figures_tesi] [--numeri outputs/tables_tesi]

DUE FONTI, E PERCHE'
  --tabelle  cartella di MAIN2 (run del 20 ottobre): per ogni livello di composizione
             <tabelle>/sintesi/ (livello 0, PA0) e <tabelle>/<LIVELLO>/sintesi/ (PA1, PA2, ...).
             Da qui si leggono i punteggi normalizzati (1 - rimpianto di tradeoff_losses.m,
             con la soglia di rilevanza gia' applicata), le quote ai prosumer, il tau-b per
             comunita' e, se c'e', confronto_PA/pa_effetti.csv. Un livello nuovo (per esempio
             con PMI) entra da solo: basta che MAIN2 scriva <tabelle>/<NOME>/sintesi/.
  --export   CSV lunghi di esporta_run.m: servono per i valori GREZZI (Gini, eccesso in % di
             v(N), ...) e per le quote dei singoli membri. Oggi esistono solo per il livello 0
             e vengono dal run del 13 ottobre. Lo script confronta le quote ai prosumer
             dell'export con quelle delle tabelle e toglie dai grafici grezzi i metodi le cui
             quote non coincidono (oggi il Tri-level EP, rifatto il 20 ottobre): lo scrive a
             video e nel file controlli.txt.

UNITA' STATISTICA
  Ogni comunita' (scheda) e' UNA simulazione deterministica: non ci sono repliche. L'unico
  elemento stocastico e' l'Adaptive Sampling Shapley (seme fisso), che e' fuori dall'analisi
  dove c'e' lo Shapley esatto. Quindi:
  - non si disegna mai una deviazione standard su un punto che e' una sola comunita';
  - la dispersione fra comunita' e' variabilita' fra CONFIGURAZIONI diverse (taglia,
    penetrazione), non incertezza di stima: si mostra la distribuzione (punti, mediana,
    intervallo interquartile) e non media +- std;
  - non si calcolano intervalli di confidenza: la griglia e' un disegno fattoriale scelto,
    non un campione casuale di comunita', e un IC suggerirebbe un'inferenza che i dati non
    sostengono.

Figure e tabelle prodotte: elencate in main() e nel README della cartella di uscita.
"""
import argparse
import re
from dataclasses import dataclass
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.colors import LinearSegmentedColormap
from matplotlib.lines import Line2D


# ============================================================ configurazione
@dataclass(frozen=True)
class Metrica:
    chiave: str     # nome dell'indicatore nelle tabelle di MAIN2
    grezza: str     # colonna dei valori grezzi (export) da disegnare
    nome: str       # etichetta in figura
    unita: str
    verso: int      # +1 piu' alto = meglio, -1 piu' basso = meglio
    gruppo: str
    normativo: bool = True   # False: il verso e' una convenzione (orientamenti.csv), non un giudizio


def leggi_verso(m, breve=False):
    if not m.normativo:
        return "↑ more reward to synchrony" if breve else "higher = rewards synchrony more (not a fairness judgement)"
    return ("↓" if m.verso < 0 else "↑") + " better" if breve else ("lower" if m.verso < 0 else "higher") + " is better"


# Equita' = solo Gini (EI_orig = 1 - Gini; InclusioneLIHC e VAN_min_EUR sono analisi a parte).
# Eccesso e coalizioni: dentro una comunita' ordinano i metodi come le colonne in euro e in
# conteggio, ma fra comunita' si confrontano solo in quota (v(N) va da 40 a 1121 EUR e le
# coalizioni sono 2^n - 2).
METRICHE = [
    Metrica("Gini", "Gini", "Gini of savings", "–", -1, "Equality"),
    Metrica("FairnessIndex", "FairnessIndex", "Fairness Index", "distance from merit", -1, "Merit"),
    Metrica("Sigma", "Sigma", "σ of merit deviation", "–", -1, "Merit"),
    Metrica("EccessoMax_EUR", "EccessoMax_pct_vN", "Max coalition excess", "% of v(N)", -1, "Stability"),
    Metrica("CoalizioniInstabili", "Instabili_pct", "Blocking coalitions", "% of 2ⁿ−2", -1, "Stability"),
    Metrica("ForzaIncentivante", "ForzaIncentivante", "Incentive strength (net)", "SU = 1", +1, "Incentive", False),
    Metrica("AllineamentoVirtu", "AllineamentoVirtu", "Alignment (net)", "cosine", +1, "Incentive", False),
    Metrica("AllineamentoVirtu_lordo", "AllineamentoVirtu_lordo", "Alignment (gross)", "cosine", +1, "Incentive", False),
]
MET = {m.chiave: m for m in METRICHE}
GRUPPI = ["Equality", "Merit", "Stability", "Incentive"]

# ordine per famiglia metodologica; colori di method_color.m (stessi delle figure MATLAB)
METODI = {
    "Shapley": ("Shapley", (0.20, 0.55, 0.85)),
    "Adaptive Sampling Shapley": ("AS-Shapley", (0.65, 0.55, 0.90)),
    "Nucleolo": ("Nucleolus", (0.08, 0.25, 0.55)),
    "Variance Least Core": ("Variance Least Core", (0.85, 0.35, 0.25)),
    "Equal Split": ("Equal Split", (0.60, 0.60, 0.60)),
    "Proportional to Consumption": ("Prop. to Consumption", (0.90, 0.70, 0.15)),
    "Pearson Key": ("Pearson Key", (0.35, 0.30, 0.65)),
    "Similarity-Utilization": ("Similarity-Utilization", (0.50, 0.60, 0.20)),
    "Remuneration Model 1": ("Remuneration Model 1", (0.75, 0.25, 0.55)),
    "Cascading Tree": ("Cascading Tree", (0.35, 0.75, 0.70)),
    "Weighted Solidarity": ("Weighted Solidarity", (0.95, 0.55, 0.55)),
    "Tri-level EP": ("Tri-level EP", (0.80, 0.20, 0.35)),
}
FAMIGLIA = {
    "Shapley": "Cooperative game", "Adaptive Sampling Shapley": "Cooperative game",
    "Nucleolo": "Cooperative game", "Variance Least Core": "Cooperative game",
    "Equal Split": "Simple", "Proportional to Consumption": "Simple",
    "Pearson Key": "Synchrony-based", "Similarity-Utilization": "Synchrony-based",
    "Remuneration Model 1": "Literature heuristics", "Cascading Tree": "Literature heuristics",
    "Weighted Solidarity": "Literature heuristics", "Tri-level EP": "Literature heuristics",
}

# livelli di composizione: etichette per quelli noti, il nome della cartella per gli altri
ETICHETTE_LIVELLO = {
    "PA0": "households only",
    "PA1": "+ town hall",
    "PA2": "+ town hall, school",
    "PA3": "+ town hall, school, sports hall",
}
BASE = "PA0"

COL_FASCIA = ["#c6dbef", "#6baed6", "#2171b5", "#08306b"]          # penetrazione crescente
COL_TAGLIA = ["#fdd0a2", "#fdae6b", "#f16913", "#d94801", "#7f2704", "#4a1503", "#2b0c02"]

plt.rcParams.update({
    "font.size": 8, "axes.titlesize": 8.5, "axes.labelsize": 8, "legend.fontsize": 7,
    "xtick.labelsize": 7, "ytick.labelsize": 7, "axes.spines.top": False,
    "axes.spines.right": False, "axes.grid": True, "grid.color": "#e6e6e6",
    "grid.linewidth": 0.5, "axes.axisbelow": True, "pdf.fonttype": 42, "ps.fonttype": 42,
    "savefig.bbox": "tight", "savefig.dpi": 200,
})


def nome(metodo):
    return METODI.get(metodo, (metodo, None))[0]


def colore(metodo):
    return METODI.get(metodo, (None, (0.55, 0.35, 0.75)))[1]


def ordina_metodi(presenti):
    noti = [m for m in METODI if m in presenti]
    return noti + sorted(set(presenti) - set(noti))


def etichetta_livello(liv):
    return ETICHETTE_LIVELLO.get(liv, liv)


def livello_da_codice(c):
    """Codice numerico di pa_effetti.csv (10*imprese + PA) -> nome del livello come nelle cartelle:
    0..3 -> PA0..PA3, 10 -> ND1, 11 -> ND1_PA1, 23 -> ND2_PA3."""
    c = int(c)
    if c < 10:
        return f"PA{c}"
    return f"ND{c // 10}" + (f"_PA{c % 10}" if c % 10 else "")


def salva(fig, out, nome_file):
    out.mkdir(parents=True, exist_ok=True)
    for ext in ("png", "pdf"):
        fig.savefig(out / f"{nome_file}.{ext}")
    plt.close(fig)


# ============================================================ dati
def fascia_da_penetrazione(df):
    """Fascia = rango della penetrazione dentro la taglia, come in MAIN2 (§7.6.2), calcolata
    sul livello base (griglia completa) e riportata per nome di scheda a tutti i livelli."""
    base = df[df.Livello == BASE] if (df.Livello == BASE).any() else df
    u = base[["Scheda", "Membri", "Penetrazione_pct"]].drop_duplicates("Scheda")
    u = u.assign(Fascia=u.groupby("Membri").Penetrazione_pct.rank(method="dense").astype(int))
    return df.merge(u[["Scheda", "Fascia"]], on="Scheda")


def etichette_fascia(df):
    """'20–30%' per ogni fascia, dai valori effettivi (non arrotondati)."""
    g = df.drop_duplicates(["Livello", "Scheda"]).groupby("Fascia").Penetrazione_pct
    return {f: (f"{lo:.0f}–{hi:.0f}%" if round(lo) != round(hi) else f"{lo:.0f}%")
            for f, lo, hi in zip(g.min().index, g.min(), g.max())}


def livelli_tabelle(tabelle):
    """{livello: cartella sintesi}: PA0 alla radice, poi ogni sottocartella con sintesi/."""
    liv = {}
    if (tabelle / "sintesi" / "rimpianto_per_comunita.csv").exists():
        liv[BASE] = tabelle
    for d in sorted(p for p in tabelle.iterdir() if p.is_dir()):
        if (d / "sintesi" / "rimpianto_per_comunita.csv").exists():
            liv[d.name] = d
    if not liv:
        raise SystemExit(f"nessun sintesi/rimpianto_per_comunita.csv sotto {tabelle}")
    return liv


def senza_as_duplicato(df):
    """Toglie l'AS-Shapley dove c'e' lo Shapley esatto nella stessa comunita' (MAIN2 §7b)."""
    if df is None or "Metodo" not in df:
        return df
    chiave = [c for c in ("Livello", "Scheda") if c in df]
    con = df.groupby(chiave).Metodo.transform(lambda s: "Shapley" in set(s))
    return df[~(con & (df.Metodo == "Adaptive Sampling Shapley"))]


def carica_tabelle(tabelle):
    """Punteggi normalizzati, quote ai prosumer e tau-b per comunita', tutti i livelli."""
    liv = livelli_tabelle(tabelle)
    punt, quote, tau = [], [], []
    for k, d in liv.items():
        r = pd.read_csv(d / "sintesi" / "rimpianto_per_comunita.csv")
        punt.append(r.assign(Livello=k, Punteggio=1 - r.Rimpianto))
        q = d / "sintesi" / "quote_prosumer.csv"
        if q.exists():
            quote.append(pd.read_csv(q).assign(Livello=k))
        t = d / "sintesi" / "tau_per_cella.csv"
        if t.exists():
            tau.append(pd.read_csv(t).assign(Livello=k))
    P = pd.concat(punt, ignore_index=True)
    P = P[P.Indicatore.isin(MET)]
    eff = tabelle / "confronto_PA" / "pa_effetti.csv"
    return {
        "livelli": list(liv),
        "punteggi": P,
        "quote": senza_as_duplicato(pd.concat(quote, ignore_index=True)) if quote else None,
        "tau": pd.concat(tau, ignore_index=True) if tau else None,
        "effetti": senza_as_duplicato(pd.read_csv(eff)) if eff.exists() else None,
    }


def carica_export(export, quote_tab, controlli):
    """Valori grezzi, tutti i livelli dell'export, con il controllo di coerenza con le tabelle.
    Gli export fino al 13 ottobre non hanno la colonna Composizione: sono tutti livello base."""
    def leggi(nome_file):
        d = pd.read_csv(export / nome_file)
        return d.assign(Livello=d.Composizione if "Composizione" in d else BASE)
    tf, com, qm = leggi("tfair_lungo.csv"), leggi("comunita.csv"), leggi("quote_membri.csv")
    tf["Instabili_pct"] = 100 * tf.CoalizioniInstabili / (2.0 ** tf.Membri - 2)
    tf = fascia_da_penetrazione(tf)
    dup = tf.duplicated(["Livello", "Scheda", "Metodo"]).sum()
    if dup:
        raise SystemExit(f"{dup} righe ripetute (livello, scheda, metodo) in tfair_lungo.csv: export "
                         "senza colonna Composizione da un run con piu' livelli? Riesportare con "
                         "esporta_run.m aggiornato.")
    controlli.append("livelli nell'export: " + ", ".join(
        f"{k} ({g.Scheda.nunique()} comunita')" for k, g in tf.groupby("Livello")))

    # l'AS esce dove c'e' lo Shapley esatto (come in MAIN2 §7b: duplica lo Shapley)
    tf, qm = senza_as_duplicato(tf), senza_as_duplicato(qm)

    # metodi superati: quota ai prosumer dell'export diversa da quella delle tabelle
    superati = []
    if quote_tab is not None:
        qp = (qm.assign(Q=qm.Quota_EUR * qm.Prosumer).groupby(["Livello", "Scheda", "Metodo"])
                .agg(Q=("Q", "sum"), Tot=("Quota_EUR", "sum")))
        qp = (qp.Q / qp.Tot).rename("QuotaExport").reset_index()
        cfr = qp.merge(quote_tab, on=["Livello", "Scheda", "Metodo"])
        diff = cfr.assign(d=(cfr.QuotaExport - cfr.QuotaProsumer).abs()).groupby("Metodo").d.max()
        superati = sorted(diff[diff > 1e-3].index)
        controlli.append(f"export vs tabelle, quota ai prosumer: {len(cfr)} terne (livello, scheda, metodo); "
                         f"scarto massimo per metodo = {diff.round(5).to_dict()}")
        controlli.append(f"metodi esclusi dai grafici grezzi perche' l'export e' superato: {superati}")
    tf = tf[~tf.Metodo.isin(superati)]
    qm = qm[~qm.Metodo.isin(superati)]
    return tf, com, qm, superati


# ============================================================ elementi grafici comuni
def legenda_fasce(ax_o_fig, lab_fascia, mediana="|", **kw):
    h = [Line2D([], [], marker="o", ls="", color=COL_FASCIA[f - 1], ms=4, label=lab_fascia[f])
         for f in sorted(lab_fascia)]
    h.append(Line2D([], [], marker=mediana, ls="", color="k", ms=9, mew=1.6, label="median"))
    return ax_o_fig.legend(handles=h, title="prosumer penetration", **kw)


def strip(ax, y0, valori, fasce, jitter=0.22, seme=0):
    rng = np.random.default_rng(seme)
    y = y0 + rng.uniform(-jitter, jitter, len(valori))
    ax.scatter(valori, y, s=9, c=[COL_FASCIA[f - 1] for f in fasce], lw=0.3, ec="white", zorder=3)
    if len(valori):
        ax.plot([np.median(valori)] * 2, [y0 - 0.35, y0 + 0.35], color="k", lw=1.6, zorder=4)


# ============================================================ F01: valori grezzi per metrica
def f01_grezzi(tf, lab_fascia, out, tab):
    metodi = ordina_metodi(tf.Metodo.unique())[::-1]
    fig, axs = plt.subplots(2, 4, figsize=(7.2, 5.4), sharey=True)
    righe = []
    for ax, m in zip(axs.ravel(), METRICHE):
        for i, k in enumerate(metodi):
            s = tf[tf.Metodo == k]
            strip(ax, i, s[m.grezza].values, s.Fascia.values, seme=i)
            righe.append((m.chiave, k, s[m.grezza].median(), s[m.grezza].quantile(.25),
                          s[m.grezza].quantile(.75), s[m.grezza].min(), s[m.grezza].max(), len(s)))
        ax.set_title(f"{m.nome} [{m.unita}]\n{leggi_verso(m, breve=True)}", fontsize=7.5)
        ax.axvline(0, color="#999", lw=0.6)
        ax.grid(axis="y", visible=False)
    axs[0, 0].set_yticks(range(len(metodi)), [nome(k) for k in metodi])
    axs[1, 0].set_yticks(range(len(metodi)), [nome(k) for k in metodi])
    legenda_fasce(fig, lab_fascia, loc="lower center", ncol=5, bbox_to_anchor=(0.5, -0.04), frameon=False)
    fig.suptitle(f"Raw indicator values per community (households only, n = {tf.Membri.min()}–{tf.Membri.max()})", y=1.0)
    fig.tight_layout(rect=(0, 0.04, 1, 1))
    salva(fig, out, "F01_valori_grezzi")
    pd.DataFrame(righe, columns=["Indicatore", "Metodo", "Mediana", "Q1", "Q3", "Min", "Max", "Comunita"]) \
      .to_csv(tab / "F01_valori_grezzi.csv", index=False)
    tf[["Livello", "Scheda", "Membri", "Fascia", "Penetrazione_pct", "Metodo"] + [m.grezza for m in METRICHE]] \
      .to_csv(tab / "valori_grezzi_per_comunita.csv", index=False)


# ============================================================ F02: profilo normalizzato per metodo
def f02_profili(P, lab_fascia, out, tab):
    p0 = P[P.Livello == BASE]
    metodi = ordina_metodi(p0.Metodo.unique())
    nc = 4
    nr = int(np.ceil(len(metodi) / nc))
    fig, axs = plt.subplots(nr, nc, figsize=(7.2, 1.9 * nr), sharex=True, sharey=True, squeeze=False)
    xs = np.arange(len(METRICHE))
    for ax, k in zip(axs.ravel(), metodi):
        s = p0[p0.Metodo == k]
        for j, m in enumerate(METRICHE):
            v = s[s.Indicatore == m.chiave]
            rng = np.random.default_rng(j)
            ax.scatter(j + rng.uniform(-.2, .2, len(v)), v.Punteggio, s=6,
                       c=[COL_FASCIA[f - 1] for f in v.Fascia], lw=0.2, ec="white", zorder=3)
            if len(v):
                ax.plot([j - .32, j + .32], [v.Punteggio.median()] * 2, color="k", lw=1.4, zorder=4)
        ax.set_title(nome(k), color=colore(k), fontweight="bold")
        ax.set_ylim(-0.06, 1.06)
        for g in GRUPPI[1:]:
            ax.axvline(next(i for i, m in enumerate(METRICHE) if m.gruppo == g) - .5, color="#bbb", lw=.6)
    for ax in axs.ravel()[len(metodi):]:
        ax.axis("off")
    for ax in axs[-1]:
        ax.set_xticks(xs, [m.nome for m in METRICHE], rotation=60, ha="right")
    for ax in axs[:, 0]:
        ax.set_ylabel("score (1 = best)")
    legenda_fasce(fig, lab_fascia, mediana="_", loc="lower right", bbox_to_anchor=(0.98, 0.04), frameon=False)
    fig.suptitle("Normalised score per community: 1 = best method in that community, 0 = worst "
                 "(households only)", y=1.0)
    fig.tight_layout()
    salva(fig, out, "F02_profili_metodo")
    (p0.groupby(["Metodo", "Indicatore"]).Punteggio
       .describe(percentiles=[.25, .5, .75])[["count", "min", "25%", "50%", "75%", "max"]]
       .to_csv(tab / "F02_profili_metodo.csv"))


# ============================================================ F03: mappa di sintesi
def mappa(ax, M, annot, cmap, vmin, vmax, metodi, titolo=None, xt=True, yt=True, fmt="{:.2f}"):
    im = ax.imshow(M, cmap=cmap, vmin=vmin, vmax=vmax, aspect="auto")
    for (i, j), v in np.ndenumerate(M):
        if np.isfinite(v):
            lum = np.mean(im.cmap(im.norm(v))[:3])
            ax.text(j, i, annot[i][j] if annot is not None else fmt.format(v), ha="center",
                    va="center", fontsize=6, color="white" if lum < 0.5 else "black")
    ax.set_xticks(range(len(METRICHE)), [m.nome for m in METRICHE] if xt else [], rotation=55, ha="right")
    ax.set_yticks(range(len(metodi)), [nome(k) for k in metodi] if yt else [])
    ax.grid(False)
    for g in GRUPPI[1:]:
        ax.axvline(next(i for i, m in enumerate(METRICHE) if m.gruppo == g) - .5, color="white", lw=2)
    if titolo:
        ax.set_title(titolo)
    return im


CMAP_PUNTEGGIO = LinearSegmentedColormap.from_list("p", ["#b2182b", "#f7f7f7", "#2166ac"])
CMAP_DELTA = LinearSegmentedColormap.from_list("d", ["#8c510a", "#f5f5f5", "#01665e"])


def f03_sintesi(P, lab_fascia, out, tab):
    p0 = P[P.Livello == BASE]
    metodi = ordina_metodi(p0.Metodo.unique())
    g = p0.groupby(["Metodo", "Indicatore"]).Punteggio
    med = g.median().unstack().reindex(index=metodi, columns=list(MET))
    q1 = g.quantile(.25).unstack().reindex(index=metodi, columns=list(MET))
    q3 = g.quantile(.75).unstack().reindex(index=metodi, columns=list(MET))
    ann = [[f"{med.iat[i, j]:.2f}\n[{q1.iat[i, j]:.2f}–{q3.iat[i, j]:.2f}]" for j in range(med.shape[1])]
           for i in range(med.shape[0])]
    fig, ax = plt.subplots(figsize=(6.0, 4.6))
    im = mappa(ax, med.values, ann, CMAP_PUNTEGGIO, 0, 1, metodi)
    fig.colorbar(im, ax=ax, fraction=0.04, pad=0.02, label="median normalised score (1 = best)")
    ax.set_title(f"Median score over {p0.Scheda.nunique()} communities [interquartile range]")
    salva(fig, out, "F03_sintesi_metodi_metriche")
    pd.concat({"mediana": med, "Q1": q1, "Q3": q3}, axis=1).to_csv(tab / "F03_sintesi.csv")

    # stessa mappa per fascia di penetrazione: il cambio di regime
    fasce = sorted(p0.Fascia.unique())
    fig, axs = plt.subplots(1, len(fasce), figsize=(7.2, 3.6))
    righe = []
    for ax, f in zip(np.atleast_1d(axs), fasce):
        s = p0[p0.Fascia == f]
        M = s.groupby(["Metodo", "Indicatore"]).Punteggio.median().unstack().reindex(index=metodi, columns=list(MET))
        im = mappa(ax, M.values, None, CMAP_PUNTEGGIO, 0, 1, metodi, f"penetration {lab_fascia[f]}",
                   yt=(f == fasce[0]), fmt="{:.1f}")
        righe.append(M.assign(Fascia=f))
    fig.colorbar(im, ax=axs, fraction=0.02, pad=0.01, label="median score over sizes (1 = best)")
    fig.suptitle("Normalised scores by penetration band (each cell: median over "
                 f"{'the ' + str(p0.Membri.nunique()) + ' sizes' if 'Membri' in p0 else 'all sizes'})", y=1.03)
    salva(fig, out, "F03b_sintesi_per_fascia")
    pd.concat(righe).to_csv(tab / "F03b_sintesi_per_fascia.csv")


# ============================================================ F04/F05: assi della griglia
def griglia_per_metodo(tf, m, asse, out, lab_fascia):
    """Small multiples, un pannello per metodo. asse = 'pen' (x = penetrazione, linee = taglie)
    o 'n' (x = taglia, linee = fasce). Ogni punto e' UNA comunita': nessuna barra d'errore."""
    metodi = ordina_metodi(tf.Metodo.unique())
    nc = 4
    nr = int(np.ceil(len(metodi) / nc))
    fig, axs = plt.subplots(nr, nc, figsize=(7.2, 1.75 * nr + 0.6), sharex=True, sharey=True, squeeze=False)
    taglie = sorted(tf.Membri.unique())
    for ax, k in zip(axs.ravel(), metodi):
        s = tf[tf.Metodo == k]
        if asse == "pen":
            for c, n in zip(COL_TAGLIA, taglie):
                r = s[s.Membri == n].sort_values("Penetrazione_pct")
                ax.plot(r.Penetrazione_pct, r[m.grezza], "-o", color=c, ms=2.2, lw=0.8)
            # mediana fra le taglie, fascia per fascia: la variabilita' per punto e' fra taglie
            g = s.groupby("Fascia").agg(x=("Penetrazione_pct", "median"), y=(m.grezza, "median"))
            ax.plot(g.x, g.y, color="k", lw=1.6, ls="--", zorder=5)
        else:
            for f in sorted(s.Fascia.unique()):
                r = s[s.Fascia == f].sort_values("Membri")
                ax.plot(r.Membri, r[m.grezza], "-o", color=COL_FASCIA[f - 1], ms=2.2, lw=1)
        ax.axhline(0, color="#999", lw=0.6)
        ax.set_title(nome(k), color=colore(k), fontweight="bold")
    for ax in axs.ravel()[len(metodi):]:
        ax.axis("off")
    for ax in axs[:, 0]:
        ax.set_ylabel(f"{m.unita}")
    if asse == "pen":
        for ax in axs[-1]:
            ax.set_xlabel("prosumer penetration [%]")
        h = [Line2D([], [], color=c, marker="o", ms=3, label=f"n = {n}") for c, n in zip(COL_TAGLIA, taglie)]
        h.append(Line2D([], [], color="k", ls="--", lw=1.6, label="median over sizes (per band)"))
        tit = f"{m.nome} vs penetration — one line per community size, each point = one community"
        nome_file = f"F04_penetrazione_{m.chiave}"
    else:
        for ax in axs[-1]:
            ax.set_xlabel("members n")
        h = [Line2D([], [], color=COL_FASCIA[f - 1], marker="o", ms=3, label=lab_fascia[f]) for f in sorted(lab_fascia)]
        tit = f"{m.nome} vs community size — one line per penetration band, each point = one community"
        nome_file = f"F05_taglia_{m.chiave}"
    fig.legend(handles=h, loc="lower center", ncol=len(h), frameon=False, bbox_to_anchor=(0.5, -0.01))
    fig.suptitle(f"{tit}\n[{m.unita}; {leggi_verso(m)}]")
    fig.tight_layout(rect=(0, 0.04, 1, 1))
    salva(fig, out / "assi", nome_file)


# ============================================================ F06: scomposizione della varianza
def eta_quadro(s):
    """Two-way senza repliche (fascia x taglia, una comunita' per cella): quota della somma
    dei quadrati spiegata da ciascun fattore. Il residuo e' interazione (non separabile)."""
    piena = s.pivot_table(index="Fascia", columns="Membri", values="Punteggio")
    if piena.isna().any().any():
        return None
    y = piena.values
    gm = y.mean()
    sst = ((y - gm) ** 2).sum()
    if sst < 1e-12:
        return None
    ssf = y.shape[1] * ((y.mean(axis=1) - gm) ** 2).sum()
    ssn = y.shape[0] * ((y.mean(axis=0) - gm) ** 2).sum()
    return ssf / sst, ssn / sst, 1 - (ssf + ssn) / sst, sst


def f06_varianza(P, out, tab):
    p0 = P[P.Livello == BASE]
    righe = []
    for (k, i), s in p0.groupby(["Metodo", "Indicatore"]):
        e = eta_quadro(s)
        if e:
            righe.append((k, i, *e))
    V = pd.DataFrame(righe, columns=["Metodo", "Indicatore", "eta2_penetrazione", "eta2_taglia",
                                     "residuo_interazione", "SST"])
    V.to_csv(tab / "F06_scomposizione_varianza.csv", index=False)
    pes = V.groupby("Indicatore").apply(
        lambda d: pd.Series({c: np.average(d[c], weights=d.SST) for c in
                             ["eta2_penetrazione", "eta2_taglia", "residuo_interazione"]}),
        include_groups=False).reindex([m.chiave for m in METRICHE])
    pes.to_csv(tab / "F06_scomposizione_varianza_per_indicatore.csv")

    fig, (a1, a2) = plt.subplots(1, 2, figsize=(7.2, 3.3), gridspec_kw={"width_ratios": [1, 1.25]})
    y = np.arange(len(pes))[::-1]
    sin = np.zeros(len(pes))
    for c, col, lab in [("eta2_penetrazione", "#2171b5", "penetration band"),
                        ("eta2_taglia", "#f16913", "size"),
                        ("residuo_interazione", "#bdbdbd", "residual (interaction)")]:
        a1.barh(y, pes[c], left=sin, color=col, label=lab, height=0.65)
        sin += pes[c].values
    a1.set_yticks(y, [MET[i].nome for i in pes.index])
    a1.set_xlim(0, 1)
    a1.legend(loc="upper center", bbox_to_anchor=(0.45, -0.1), ncol=3, frameon=False, fontsize=6)
    a1.set_title("Share of between-community variance\n(pooled over methods, weighted by variance)")
    metodi = ordina_metodi(V.Metodo.unique())
    M = V.pivot_table(index="Metodo", columns="Indicatore", values="eta2_penetrazione").reindex(
        index=metodi, columns=list(MET))
    im = mappa(a2, M.values, None, plt.get_cmap("Blues"), 0, 1, metodi, "η² of penetration, per method",
               fmt="{:.1f}")
    fig.colorbar(im, ax=a2, fraction=0.04, pad=0.02)
    for (i, j), v in np.ndenumerate(M.values):
        if not np.isfinite(v):
            a2.text(j, i, "const.", ha="center", va="center", fontsize=5, color="#888")
    fig.suptitle(f"What drives the normalised scores across the {p0.Membri.nunique()} × {p0.Fascia.nunique()} grid (households only)\n"
                 "two-way decomposition, one community per cell: residual = interaction, not noise")
    fig.tight_layout()
    salva(fig, out, "F06_scomposizione_varianza")
    return pes


# ============================================================ F07: posta in gioco
def f07_posta(qm, com, out, tab):
    q = qm.groupby(["Scheda", "Membro"]).Quota_EUR.agg(lambda x: x.max() - x.min()).rename("Escursione")
    q = q.groupby("Scheda").agg(["mean", "max"]).add_prefix("Escursione_")
    c = com.set_index("Scheda").join(q)
    c["vN_membro"] = c.vN_EUR / c.Membri
    c["Escursione_rel"] = 100 * c.Escursione_mean / c.vN_membro
    c = c.reset_index()
    c.to_csv(tab / "F07_posta_in_gioco.csv", index=False)
    taglie = sorted(c.Membri.unique())
    fig, axs = plt.subplots(1, 3, figsize=(7.2, 2.6), sharex=True)
    for col, ax, yl in [("vN_membro", axs[0], "v(N) per member [€/yr]"),
                        ("Escursione_mean", axs[1], "range across methods [€/yr]"),
                        ("Escursione_rel", axs[2], "range / equal share [%]")]:
        for cc, n in zip(COL_TAGLIA, taglie):
            r = c[c.Membri == n].sort_values("Penetrazione_pct")
            ax.plot(r.Penetrazione_pct, r[col], "-o", color=cc, ms=2.5, lw=1, label=f"n = {n}")
        ax.set_ylabel(yl)
        ax.set_xlabel("prosumer penetration [%]")
        ax.set_ylim(bottom=0)
    axs[0].set_title("Value to share")
    axs[1].set_title("What one member can gain or lose\nby the choice of rule (mean member)")
    axs[2].set_title("Same, relative to the equal share")
    axs[0].legend(frameon=False)
    fig.tight_layout()
    salva(fig, out, "F07_posta_in_gioco")
    return c


# ============================================================ F08: compromessi in unita' naturali
def f08_compromessi(tf, lab_fascia, out, tab):
    coppie = [("Gini", "EccessoMax_EUR"), ("Gini", "ForzaIncentivante"), ("ForzaIncentivante", "EccessoMax_EUR")]
    fasce = sorted(tf.Fascia.unique())
    fig, axs = plt.subplots(len(coppie), len(fasce), figsize=(7.2, 2.0 * len(coppie) + 0.5))
    metodi = ordina_metodi(tf.Metodo.unique())
    righe = []
    for r, (a, b) in enumerate(coppie):
        ma, mb = MET[a], MET[b]
        for c, f in enumerate(fasce):
            ax = axs[r, c]
            s = tf[tf.Fascia == f]
            for k in metodi:
                v = s[s.Metodo == k]
                ax.scatter(v[ma.grezza], v[mb.grezza], s=7, color=colore(k), alpha=0.35, lw=0)
                ax.scatter(v[ma.grezza].median(), v[mb.grezza].median(), s=28, color=colore(k),
                           ec="k", lw=0.5, zorder=4)
                righe.append((a, b, f, k, v[ma.grezza].median(), v[mb.grezza].median()))
            if r == 0:
                ax.set_title(f"penetration {lab_fascia[f]}")
            if c == 0:
                ax.set_ylabel(f"{mb.nome}\n[{mb.unita}]")
            ax.set_xlabel(f"{ma.nome} [{ma.unita}]", fontsize=6.5)
    h = [Line2D([], [], marker="o", ls="", color=colore(k), mec="k", mew=.5, ms=5, label=nome(k)) for k in metodi]
    fig.legend(handles=h, loc="lower center", ncol=6, frameon=False, bbox_to_anchor=(0.5, -0.03))
    fig.suptitle("Trade-offs in natural units: small dots = one community, large = median over sizes\n"
                 "(Gini and excess: lower is better; incentive strength: higher rewards synchrony)")
    fig.tight_layout(rect=(0, 0.06, 1, 1))
    salva(fig, out, "F08_compromessi")
    pd.DataFrame(righe, columns=["X", "Y", "Fascia", "Metodo", "MedianaX", "MedianaY"]) \
      .to_csv(tab / "F08_compromessi.csv", index=False)


# ============================================================ F09: chi viene premiato
def f09_prosumer(quote, lab_fascia, out, tab):
    q = quote[quote.Livello == BASE]
    q = q[q.Fascia < q.Fascia.max()] if (q[q.Fascia == q.Fascia.max()].Penetrazione_pct == 100).all() else q
    metodi = ordina_metodi(q.Metodo.unique())
    taglie = sorted(q.Membri.unique())
    nc = 4
    nr = int(np.ceil(len(metodi) / nc))
    fig, axs = plt.subplots(nr, nc, figsize=(7.2, 1.7 * nr + 0.6), sharex=True, sharey=True, squeeze=False)
    for ax, k in zip(axs.ravel(), metodi):
        s = q[q.Metodo == k]
        for c, n in zip(COL_TAGLIA, taglie):
            r = s[s.Membri == n].sort_values("Penetrazione_pct")
            ax.plot(r.Penetrazione_pct, r.RapportoAllaQuotaDiMembri, "-o", color=c, ms=2.2, lw=.8)
        ax.axhline(1, color="k", lw=0.8, ls=":")
        ax.set_yscale("symlog", linthresh=0.05, linscale=0.4)
        ax.set_ylim(0, 4)
        ax.set_yticks([0, 0.1, 0.3, 1, 3], ["0", "0.1", "0.3", "1", "3"])
        ax.minorticks_off()
        ax.set_title(nome(k), color=colore(k), fontweight="bold")
    for ax in axs.ravel()[len(metodi):]:
        ax.axis("off")
    for ax in axs[:, 0]:
        ax.set_ylabel("prosumer share of v(N)\n/ prosumer share of members")
    for ax in axs[-1]:
        ax.set_xlabel("prosumer penetration [%]")
    h = [Line2D([], [], color=c, marker="o", ms=3, label=f"n = {n}") for c, n in zip(COL_TAGLIA, taglie)]
    fig.legend(handles=h, loc="lower center", ncol=len(h), frameon=False, bbox_to_anchor=(0.5, -0.01))
    fig.suptitle("Who is rewarded: > 1 = prosumers receive more than their head count\n"
                 "(log scale above 0.05, linear below so that 0 is visible; 100% penetration omitted: ratio = 1)")
    fig.tight_layout(rect=(0, 0.04, 1, 1))
    salva(fig, out, "F09_quota_prosumer")
    q.to_csv(tab / "F09_quota_prosumer.csv", index=False)


# ============================================================ F10/F11: composizione
def delta_composizione(P, livelli):
    """Differenza APPAIATA di punteggio (livello k - PA0), scheda per scheda.
    Si appaia sul solo nome della scheda: la Fascia delle tabelle e' il rango della penetrazione
    DENTRO il livello, e in PA2/PA3 mancano le schede a bassa penetrazione, quindi lo stesso
    rango indica schede diverse nei due livelli. Taglia e fascia si prendono da PA0."""
    W = P.pivot_table(index=["Scheda", "Metodo", "Indicatore"], columns="Livello", values="Punteggio")
    rif = P[P.Livello == BASE].drop_duplicates("Scheda").set_index("Scheda")[["Membri", "Fascia", "Penetrazione_pct"]]
    righe = []
    for k in livelli:
        if k == BASE or k not in W:
            continue
        d = (W[k] - W[BASE]).dropna().rename("Delta").reset_index().assign(Livello=k).join(rif, on="Scheda")
        righe.append(d)
    return pd.concat(righe, ignore_index=True) if righe else None


def f10_composizione(P, livelli, out, tab):
    D = delta_composizione(P, livelli)
    if D is None:
        return None
    D.to_csv(tab / "F10_delta_composizione_dettaglio.csv", index=False)
    liv = [k for k in livelli if k != BASE]
    metodi = ordina_metodi(D.Metodo.unique())
    nc = min(len(liv), 4) if len(liv) > 3 else min(len(liv), 3)
    nr = int(np.ceil(len(liv) / nc))
    # un pannello abbastanza largo da leggere le celle; con molti livelli (asse imprese: 15)
    # la figura e' ampia e va vista a schermo intero o in PDF
    fig, axs = plt.subplots(nr, nc, figsize=(3.3 * nc + 1.6, 3.2 * nr + 1.4), squeeze=False,
                            layout="constrained")
    for ax in axs.ravel()[len(liv):]:
        ax.axis("off")
    righe = []
    for i_ax, (ax, k) in enumerate(zip(axs.ravel(), liv)):
        s = D[D.Livello == k]
        g = s.groupby(["Metodo", "Indicatore"]).Delta
        med = g.median().unstack().reindex(index=metodi, columns=list(MET))
        # coerenza di segno: quota di schede con lo stesso segno della mediana (pari esclusi)
        coer = g.apply(lambda x: np.mean(np.sign(x[x.abs() > 0.05]) == np.sign(np.median(x)))
                       if (x.abs() > 0.05).any() else np.nan).unstack().reindex(index=metodi, columns=list(MET))
        ann = [["" if not np.isfinite(med.iat[i, j]) else "0" if abs(med.iat[i, j]) < 0.05 else
                (f"{med.iat[i, j]:+.1f}" + ("" if coer.iat[i, j] >= 0.8 else "°"))
                for j in range(med.shape[1])] for i in range(med.shape[0])]
        ultimo_della_colonna = i_ax + nc >= len(liv)
        im = mappa(ax, med.values, ann, CMAP_DELTA, -1, 1, metodi,
                   (k if etichetta_livello(k) == k else f"{k}: {etichetta_livello(k)}")
                   + f"\n({s.Scheda.nunique()} paired communities)",
                   xt=ultimo_della_colonna, yt=(i_ax % nc == 0))
        righe.append(pd.DataFrame({"Mediana": med.stack(), "CoerenzaSegno": coer.stack()})
                     .reset_index().assign(Livello=k, Comunita=s.Scheda.nunique()))
    fig.colorbar(im, ax=axs, fraction=0.02, pad=0.01, label="median Δ score vs households only")
    fig.suptitle("Effect of adding public buildings or firms at fixed n and penetration (paired by community)\n"
                 "° = fewer than 80% of communities agree with the sign of the median; 0 = |median| < 0.05")
    salva(fig, out, "F10_effetto_composizione")
    pd.concat(righe).to_csv(tab / "F10_delta_composizione.csv", index=False)
    return D


def f11_scala(D, effetti, out, tab):
    """La PA cambia composizione e scala insieme: |Delta| contro il rapporto v(N)/v(N)_PA0.
    Colore = numero di PA, forma = numero di imprese (asse imprese: livelli ND<k>_PA<p>)."""
    if D is None or effetti is None:
        return None
    e = effetti.drop_duplicates(["Scheda", "Livello"])[["Scheda", "Livello", "vN_rapportoPA0"]]
    e = e.assign(Livello=e.Livello.map(livello_da_codice))
    A = (D.assign(absD=D.Delta.abs()).groupby(["Scheda", "Livello"]).absD.mean()
          .rename("DeltaMedioAssoluto").reset_index().merge(e, on=["Scheda", "Livello"]))
    A.to_csv(tab / "F11_scala_vs_composizione.csv", index=False)

    def pa_nd(k):                                   # "ND2_PA1" -> (1, 2); "PA3" -> (3, 0)
        m = re.fullmatch(r"(?:ND(\d))?_?(?:PA(\d))?", k)
        return int(m.group(2) or 0), int(m.group(1) or 0)

    def ordine(k):
        return (pa_nd(k)[1], pa_nd(k)[0])

    col_pa = {0: "#4575b4", 1: "#fdae6b", 2: "#e6550d", 3: "#7f2704"}
    forma = {0: "o", 1: "s", 2: "^", 3: "D"}
    liv = sorted(A.Livello.unique(), key=ordine)
    fig, (a1, a2) = plt.subplots(1, 2, figsize=(10.5, 4.4), layout="constrained",
                                 gridspec_kw={"width_ratios": [1, 1.25]})
    for k in liv:
        p_, n_ = pa_nd(k)
        s_ = A[A.Livello == k]
        a1.scatter(s_.vN_rapportoPA0, s_.DeltaMedioAssoluto, s=22, color=col_pa[p_], marker=forma[n_],
                   lw=0.3, ec="white")
    a1.set_xscale("log")
    a1.set_xlabel("v(N) with the added members / v(N) households only")
    a1.set_ylabel("mean |Δ score| over methods × indicators")
    a1.set_title("Is the ranking shift a scale effect?\n(one point = one community)")
    h = [Line2D([], [], marker="o", ls="", color=col_pa[p_], ms=5,
                label=f"{p_} public building" + ("s" if p_ != 1 else ""))
         for p_ in sorted({pa_nd(k)[0] for k in liv})]
    h += [Line2D([], [], marker=forma[n_], ls="", color="#555", ms=5,
                 label=f"{n_} firm" + ("s" if n_ != 1 else ""))
          for n_ in sorted({pa_nd(k)[1] for k in liv})]
    a1.legend(handles=h, frameon=False, fontsize=7, loc="best")
    if "RapportoQuotaPA" in effetti:
        q = effetti[effetti.Livello > 0].dropna(subset=["RapportoQuotaPA"])
        q = q.assign(Liv=q.Livello.map(livello_da_codice))
        q = q[q.Liv.map(lambda k: pa_nd(k)[0] > 0)]            # solo i livelli con PA
        metodi = ordina_metodi(q.Metodo.unique())
        livq = sorted(q.Liv.unique(), key=ordine)
        M = q.groupby(["Metodo", "Liv"]).RapportoQuotaPA.median().unstack().reindex(index=metodi, columns=livq)
        im = a2.imshow(M.values, cmap="YlOrBr", vmin=0, aspect="auto")
        for (i, j), v in np.ndenumerate(M.values):
            if np.isfinite(v):
                a2.text(j, i, f"{v:.1f}", ha="center", va="center", fontsize=6.5,
                        color="white" if v > 0.6 * np.nanmax(M.values) else "black")
        a2.set_xticks(range(len(livq)), livq, rotation=60, ha="right")
        a2.set_yticks(range(len(metodi)), [nome(m) for m in metodi])
        a2.grid(False)
        fig.colorbar(im, ax=a2, fraction=0.04, pad=0.02, label="PA share of v(N) / PA share of members")
        a2.set_title("How much the public buildings take\n(median over communities; 1 = proportional to headcount)")
    salva(fig, out, "F11_scala_e_quote_PA")
    return A


# ============================================================ F13: valori grezzi fra livelli
def f13_grezzi_composizione(tf, out, tab):
    """Valori grezzi appaiati: x = stessa scheda senza PA, y = con PA. Sopra la diagonale il
    valore cresce. Si legge in unita' naturali cio' che F10 mostra in graduatoria."""
    livelli = [k for k in sorted(tf.Livello.unique()) if k != BASE]
    metodi = ordina_metodi(tf.Metodo.unique())
    W = tf.pivot_table(index=["Scheda", "Metodo"], columns="Livello",
                       values=[m.grezza for m in METRICHE])
    righe = []
    for k in livelli:
        fig, axs = plt.subplots(2, 4, figsize=(7.2, 4.2))
        for ax, m in zip(axs.ravel(), METRICHE):
            if (m.grezza, k) not in W:
                ax.axis("off")
                continue
            d = W[[(m.grezza, BASE), (m.grezza, k)]].dropna()
            d.columns = ["x", "y"]
            d = d.reset_index()
            for metodo in metodi:
                v = d[d.Metodo == metodo]
                ax.scatter(v.x, v.y, s=8, color=colore(metodo), lw=0)
            lim = [np.nanmin(d[["x", "y"]].values), np.nanmax(d[["x", "y"]].values)]
            ax.plot(lim, lim, color="k", lw=0.6, ls=":")
            ax.set_title(f"{m.nome} [{m.unita}]", fontsize=7)
            righe.append(d.assign(Indicatore=m.chiave, Livello=k))
        axs[1, 0].set_xlabel(f"{BASE} ({etichetta_livello(BASE)})")
        axs[1, 0].set_ylabel(f"{k} ({etichetta_livello(k)})")
        h = [Line2D([], [], marker="o", ls="", color=colore(x), ms=4, label=nome(x)) for x in metodi]
        fig.legend(handles=h, loc="lower center", ncol=6, frameon=False, bbox_to_anchor=(0.5, -0.06))
        fig.suptitle(f"Raw indicators, same community without and with {k}: {etichetta_livello(k)} "
                     "(dotted = no change)")
        fig.tight_layout(rect=(0, 0.05, 1, 1))
        salva(fig, out, f"F13_grezzi_{k}")
    if righe:
        pd.concat(righe).to_csv(tab / "F13_grezzi_composizione.csv", index=False)


# ============================================================ F12: accordo fra indicatori
def f12_accordo(tau, lab_fascia, out, tab):
    t = tau[(tau.Livello == BASE) & tau.IndicatoreA.isin(MET) & tau.IndicatoreB.isin(MET)]
    t = pd.concat([t, t.rename(columns={"IndicatoreA": "IndicatoreB", "IndicatoreB": "IndicatoreA"})])
    chiavi = [m.chiave for m in METRICHE]
    fasce = sorted(t.Fascia.unique())
    fig, axs = plt.subplots(1, len(fasce), figsize=(7.2, 2.6), sharey=True)
    righe = []
    for ax, f in zip(axs, fasce):
        M = t[t.Fascia == f].groupby(["IndicatoreA", "IndicatoreB"]).TauB.mean().unstack().reindex(index=chiavi, columns=chiavi)
        M = M.copy()
        for c in chiavi:
            M.loc[c, c] = 1.0
        im = ax.imshow(M.values, cmap="RdBu", vmin=-1, vmax=1)
        for (i, j), v in np.ndenumerate(M.values):
            if i > j and np.isfinite(v):
                ax.text(j, i, f"{v:+.1f}".replace("+", ""), ha="center", va="center", fontsize=5,
                        color="white" if abs(v) > 0.6 else "black")
        ax.set_xticks(range(len(chiavi)), [MET[c].nome for c in chiavi], rotation=70, ha="right", fontsize=5.5)
        ax.set_yticks(range(len(chiavi)), [MET[c].nome for c in chiavi], fontsize=5.5)
        ax.grid(False)
        ax.set_title(f"penetration {lab_fascia[f]}")
        righe.append(M.stack().rename("TauMedio").reset_index().assign(Fascia=f))
    fig.colorbar(im, ax=axs, fraction=0.02, pad=0.01, label="mean Kendall τ-b (oriented)")
    n_taglie = f"the {t.Membri.nunique()} sizes" if "Membri" in t else "all sizes"
    fig.suptitle(f"Do the indicators rank the methods the same way? (mean τ-b over {n_taglie})", y=1.04)
    salva(fig, out, "F12_accordo_indicatori")
    pd.concat(righe).to_csv(tab / "F12_accordo_indicatori.csv", index=False)


# ============================================================ main
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--tabelle", default="outputs/tables_main2")
    ap.add_argument("--export", default="outputs/workspace/export_fino18")
    ap.add_argument("--out", default="outputs/figures_tesi")
    ap.add_argument("--numeri", default="outputs/tables_tesi")
    ap.add_argument("--apri", action="store_true", help="apre la pagina dei risultati nel browser")
    ap.add_argument("--senza-pagina", action="store_true", help="non genera la pagina HTML")
    a = ap.parse_args()
    out, tab = Path(a.out), Path(a.numeri)
    tab.mkdir(parents=True, exist_ok=True)
    controlli = []

    T = carica_tabelle(Path(a.tabelle))
    P = T["punteggi"]
    controlli.append(f"livelli trovati in {a.tabelle}: " + ", ".join(
        f"{k} ({P[P.Livello == k].Scheda.nunique()} comunita')" for k in T["livelli"]))
    copertura = P.groupby(["Livello", "Indicatore"]).Scheda.nunique().unstack(0)
    controlli.append("comunita' in cui ciascun indicatore discrimina (soglia di rilevanza):\n"
                     + copertura.to_string())
    # Gli indicatori senza dati (eccesso e coalizioni instabili: Shapley e Nucleolo non si
    # calcolano oltre 18 membri) non occupano colonne vuote nelle figure.
    presenti = set(P.Indicatore)
    METRICHE[:] = [m for m in METRICHE if m.chiave in presenti]
    MET.clear()
    MET.update({m.chiave: m for m in METRICHE})
    GRUPPI[:] = [g for g in GRUPPI if any(m.gruppo == g for m in METRICHE)]
    lab_fascia = etichette_fascia(P[P.Livello == BASE])

    tf, com, qm, superati = carica_export(Path(a.export), T["quote"], controlli)
    # controllo: il punteggio delle tabelle e' (max - s)/(max - min) sui punteggi orientati
    assert P.Punteggio.between(-1e-9, 1 + 1e-9).all(), "punteggi fuori da [0,1]"
    ck = P[P.Livello == BASE].groupby(["Scheda", "Indicatore"]).Punteggio.agg(["min", "max"])
    controlli.append(f"per ogni (comunita', indicatore) il migliore vale 1 e il peggiore 0: "
                     f"min max = {ck['min'].max():.2e}, min min = {ck['max'].min():.6f}")

    # le figure F01-F09 descrivono la griglia del livello base; i livelli dell'export vanno in F13
    tf_tutti = tf
    tf, com, qm = (d[d.Livello == BASE] for d in (tf, com, qm))
    # I valori grezzi vengono dall'export, che e' di un altro run: si usano solo se contiene
    # tutte le comunita' delle tabelle. Altrimenti F01, F04/F05, F07 e F08 descriverebbero
    # comunita' diverse da quelle di tutte le altre figure.
    export_ok = set(P[P.Livello == BASE].Scheda) <= set(tf.Scheda)
    if not export_ok:
        controlli.append(
            "F01, F04/F05, F07, F08 e F13 NON prodotte: l'export (" + str(a.export) + ") non contiene "
            f"{len(set(P[P.Livello == BASE].Scheda) - set(tf.Scheda))} delle "
            f"{P[P.Livello == BASE].Scheda.nunique()} comunita' delle tabelle. Servono i valori grezzi "
            "di questo run: esporta_run.m vuole il workspace con AGR e LIV, che MAIN2 non salva "
            "(salva solo il checkpoint RESULTS).")
    if export_ok:
        f01_grezzi(tf, lab_fascia, out, tab)
    f02_profili(P, lab_fascia, out, tab)
    f03_sintesi(P, lab_fascia, out, tab)
    if export_ok:
        for m in METRICHE:
            griglia_per_metodo(tf, m, "pen", out, lab_fascia)
            griglia_per_metodo(tf, m, "n", out, lab_fascia)
    pes = f06_varianza(P, out, tab)
    if export_ok:
        f07_posta(qm, com, out, tab)
        f08_compromessi(tf, lab_fascia, out, tab)
    if T["quote"] is not None:
        f09_prosumer(T["quote"], lab_fascia, out, tab)
    D = f10_composizione(P, T["livelli"], out, tab)
    f11_scala(D, T["effetti"], out, tab)
    if T["tau"] is not None:
        f12_accordo(T["tau"], lab_fascia, out, tab)
    if not export_ok:
        pass
    elif tf_tutti.Livello.nunique() > 1:
        f13_grezzi_composizione(tf_tutti, out, tab)
    else:
        controlli.append("F13 (valori grezzi per livello) non prodotta: l'export ha solo il livello "
                         f"{BASE}. Serve un export del run con PA fatto con esporta_run.m aggiornato.")

    controlli.append("scomposizione della varianza (pesata), per indicatore:\n" + pes.round(3).to_string())
    (tab / "controlli.txt").write_text("\n\n".join(controlli) + "\n", encoding="utf-8")
    print("\n\n".join(controlli))
    print(f"\nfigure in {out}, numeri in {tab}")

    if not a.senza_pagina and not export_ok:
        print("pagina_risultati.py non eseguita: pretende F01, F07 e F08. Pagina senza commenti: "
              f"python -I {Path(__file__).with_name('pagina_figure.py')} --figure {out} --numeri {tab}")
    elif not a.senza_pagina:
        # la pagina sta in un file a parte; con python -I la cartella dello script non e' in
        # sys.path, quindi si carica per percorso invece che con import
        import runpy
        pagina = runpy.run_path(str(Path(__file__).with_name("pagina_risultati.py")), run_name="pagina")
        pagina["costruisci"](out, tab, apri=a.apri)


if __name__ == "__main__":
    main()
