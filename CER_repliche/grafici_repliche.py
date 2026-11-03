"""Figure della tesi basate sulle repliche dei partecipanti (passo 4 del piano).

Legge outputs/repliche/<blocco>/aggregato/ (scritto da aggrega_repliche.py) e produce, in
inglese, PNG e PDF in --out (default outputs/tesi_finale/figure/):

  G01_poles               chi vince: quota di celle in cui il metodo e' fra i primi, per indicatore
  G02_tau_by_band         tau-b delle coppie chiave per fascia: mediana, banda 10-90%, repliche
  G03_reversals           coppie di metodi invertite lungo penetrazione e taglia, per replica
  G04_variance            scomposizione della varianza: penetrazione, taglia, interazione, partecipanti
  G05_composition         effetto di PA e imprese rispetto al livello base
  G06_tradeoff_losses     perdita su un criterio scegliendo il migliore su un altro
  G07_reduced_set         insieme ridotto di indicatori: rappresentante e concordanza
  G08_pareto              quota di comunita' in cui il metodo non e' dominato
  G09_threshold           soglia regolatoria, tutte le comunita' di tutte le repliche
  G10_npv                 VAN minimo per metodo e gruppo (analisi complementare)
  G11_prosumer_share      quota dell'incentivo ai prosumer per metodo e fascia
  G12_stability_by_size   chi vince sulla stabilita', per taglia
  G13_robustness          quante conclusioni reggono, e se le due meta' delle repliche concordano

Ogni figura e' descritta da una riga in figure.csv (nome, titolo, cosa mostra), che il rapporto
usa per le didascalie. r00 non compare: i risultati sono le repliche r01..rNN.
Uso:  python -I CER_repliche/grafici_repliche.py --blocco unito [--radice ...] [--out ...]
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
import stile_tesi as st  # noqa: E402
from stile_tesi import plt  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
LARGO, ALTO = 6.4, 3.6          # pollici: larghezza del testo della tesi
CATALOGO = []                   # (file, titolo, descrizione)


def registra(nome, titolo, descrizione):
    CATALOGO.append({"Figura": nome, "Titolo": titolo, "Descrizione": descrizione})


def as_shapley(df, col="Metodo"):
    """Nelle tabelle di MAIN2 il nome resta quello dei dati: l'AS e' lo Shapley sopra 18 membri."""
    if col in df:
        df = df.copy()
        df[col] = df[col].replace(st.AS, "Shapley")
    return df


def etichetta_fascia(f):
    return f"band {f}"


# ---------------------------------------------------------------------------- G01
def g01_poli(A, out):
    p = as_shapley(A["poli_per_replica"])
    p = p.groupby(["Replica", "Indicatore", "Metodo"]).agg(C=("CelleFraIPrimi", "sum")).reset_index()
    tot = A["poli_per_replica"].drop_duplicates(["Replica", "Indicatore", "Membri"]).groupby(
        ["Replica", "Indicatore"]).Celle.sum().rename("Tot")
    p = p.join(tot, on=["Replica", "Indicatore"]).assign(Q=lambda d: (d.C / d.Tot).clip(upper=1))
    M = p.pivot_table(index="Metodo", columns="Indicatore", values="Q", aggfunc="median").fillna(0)
    M = M.reindex(index=st.ordina_metodi(M.index), columns=[i for i in st.INDICATORI if i in M.columns])
    fig, ax = plt.subplots(figsize=(LARGO, 3.9))
    im = ax.imshow(M.values, cmap=st.MAPPA, vmin=0, vmax=1, aspect="auto")
    for i in range(M.shape[0]):
        for j in range(M.shape[1]):
            v = M.values[i, j]
            ax.text(j, i, f"{100 * v:.0f}", ha="center", va="center", fontsize=6.5,
                    color="white" if v > 0.55 else st.INCHIOSTRO)
    ax.set_xticks(range(M.shape[1]), [st.nome_indicatore(c) for c in M.columns], rotation=30, ha="right")
    ax.set_yticks(range(M.shape[0]), [st.nome_metodo(m) for m in M.index])
    ax.grid(False)
    fig.colorbar(im, ax=ax, shrink=0.8, label="share of cells ranked first (%), median of replicas",
                 format=lambda x, _: f"{100 * x:.0f}")
    ax.set_title("Which mechanism ranks first on each indicator (households only, all sizes and bands)",
                 loc="left")
    st.salva(fig, out, "G01_poles")
    registra("G01_poles", "Which mechanism ranks first on each indicator",
             "Per indicatore, quota delle celle (taglia x fascia, livello base) in cui il metodo e' fra i "
             "primi a pari merito; mediana sulle repliche.")
    return M


# ---------------------------------------------------------------------------- G02
COPPIE = [("Gini", "ForzaIncentivante"), ("FairnessIndex", "ForzaIncentivante"),
          ("Gini", "FairnessIndex"), ("FairnessIndex", "EccessoMax_EUR")]


def g02_tau(A, out):
    T = A["tau_per_replica"]
    fig, axs = plt.subplots(1, 4, figsize=(LARGO, 2.6), sharey=True)
    rng = np.random.default_rng(0)
    for ax, (a, b) in zip(axs, COPPIE):
        s = T[((T.IndicatoreA == a) & (T.IndicatoreB == b)) | ((T.IndicatoreA == b) & (T.IndicatoreB == a))]
        g = s.groupby("Fascia").TauMedio
        f = np.array(sorted(s.Fascia.unique()))
        ax.axhline(0, color=st.GRIGIO, lw=0.8)
        ax.fill_between(f, g.quantile(0.1).values, g.quantile(0.9).values, color=st.BLU, alpha=0.15, lw=0)
        ax.scatter(s.Fascia + rng.uniform(-0.12, 0.12, len(s)), s.TauMedio, s=6, color=st.GRIGIO, lw=0,
                   alpha=0.7, zorder=2)
        ax.plot(f, g.median().values, color=st.BLU, lw=2, marker="o", ms=4, zorder=3)
        ax.set_xticks(f, [str(x) for x in f])
        ax.set_xlabel("penetration band")
        ax.set_title(f"{st.nome_indicatore(a)} vs\n{st.nome_indicatore(b)}", fontsize=7.5)
        ax.set_ylim(-1.05, 1.05)
    axs[0].set_ylabel("Kendall τ-b (mean over communities)")
    fig.suptitle("Agreement between criteria by penetration band: median (line), 10-90% of replicas (band), "
                 "each replica (dots)", fontsize=8, x=0.01, ha="left")
    fig.tight_layout()
    st.salva(fig, out, "G02_tau_by_band")
    registra("G02_tau_by_band", "Agreement between criteria by penetration band",
             "tau-b medio fra comunita' per le quattro coppie chiave, per fascia di penetrazione: "
             "mediana sulle repliche, banda 10-90%, punti = singole repliche.")


# ---------------------------------------------------------------------------- G03
def g03_inversioni(A, out):
    I = A["inversioni_per_replica"]
    fig, axs = plt.subplots(1, 2, figsize=(LARGO, 2.8), gridspec_kw={"width_ratios": [7, 4]}, sharey=True)
    rng = np.random.default_rng(1)
    for ax, sweep, titolo in [(axs[0], "penetrazione", "along penetration, at fixed size"),
                              (axs[1], "taglia", "along size, at fixed band")]:
        s = I[I.Sweep == sweep]
        chiavi = sorted(s.Fisso.unique(), key=lambda x: float("".join(c for c in x.split("(")[0] if c.isdigit()) or 0))
        for k, fisso in enumerate(chiavi):
            v = s[s.Fisso == fisso].QuotaInvertite.values
            col = st.TAGLIE[min(k, 6)] if sweep == "penetrazione" else st.FASCE[min(k, 3)]
            ax.scatter(k + rng.uniform(-0.18, 0.18, len(v)), 100 * v, s=8, color=col, lw=0.3, ec="white", zorder=2)
            ax.plot([k - 0.3, k + 0.3], [100 * np.median(v)] * 2, color=st.INCHIOSTRO, lw=1.6, zorder=3)
        lab = [x.replace("n = ", "") + (" members" if i == 0 else "") if sweep == "penetrazione"
               else "band " + x.split()[1] for i, x in enumerate(chiavi)]
        ax.set_xticks(range(len(chiavi)), lab)
        ax.set_title(titolo, loc="left")
    axs[0].set_ylabel("pairs of mechanisms reversed (%)")
    fig.suptitle("Ranking reversals: one dot per replica, bar = median", fontsize=8, x=0.01, ha="left")
    fig.tight_layout()
    st.salva(fig, out, "G03_reversals")
    registra("G03_reversals", "Ranking reversals along penetration and size",
             "Quota di coppie di metodi il cui ordine si inverte lungo la penetrazione (a taglia fissa) e "
             "lungo la taglia (a fascia fissa); un punto per replica, barra = mediana.")


# ---------------------------------------------------------------------------- G04
def g04_varianza(A, out):
    V = A["varianza"].dropna(subset=["penetrazione"]).set_index("Indicatore")
    comp = [("penetrazione", "prosumer penetration", st.BLU), ("taglia", "size", st.ARANCIO),
            ("interazione", "penetration × size", "#B5B5B5"), ("partecipanti", "participants (replicas)", st.VERDE)]
    fig, ax = plt.subplots(figsize=(LARGO, 2.9))
    y = np.arange(len(V))[::-1]
    sin = np.zeros(len(V))
    for c, lab, col in comp:
        v = 100 * V[c].clip(lower=0).values
        ax.barh(y, v, left=sin, color=col, height=0.62, ec=st.SFONDO, lw=1.2, label=lab)
        for yi, x0, w in zip(y, sin, v):
            if w >= 7:
                ax.text(x0 + w / 2, yi, f"{w:.0f}", ha="center", va="center", fontsize=6.5,
                        color="white" if col in (st.BLU, st.VERDE) else st.INCHIOSTRO)
        sin += v
    ax.set_yticks(y, [st.nome_indicatore(i) for i in V.index])
    ax.set_xlim(0, 100)
    ax.set_xlabel("share of the variance of the scores (%)")
    ax.legend(ncol=4, loc="lower left", bbox_to_anchor=(0, 1.0), fontsize=6.8)
    ax.grid(axis="y", visible=False)
    st.salva(fig, out, "G04_variance")
    registra("G04_variance", "What the scores depend on",
             "Scomposizione della varianza dei punteggi (1 - rimpianto) del livello base: penetrazione, "
             "taglia, interazione e partecipanti (variazione fra repliche dentro la stessa cella).")


# ---------------------------------------------------------------------------- G05
def g05_composizione(A, out):
    C = A["composizione"]
    C = C[C.Confronto.str.match(r"^PA0-")]
    g = C.groupby("Confronto")[["mediana_inv", "min_inv", "max_inv", "mediana_vinc"]].mean()
    ordine = sorted(g.index, key=lambda x: (x.count("ND") > 0, x))
    g = g.reindex(ordine)
    fig, axs = plt.subplots(1, 2, figsize=(LARGO, 3.4), sharey=True)
    y = np.arange(len(g))[::-1]
    gr = ["with firms" if "ND" in x else "with public buildings" for x in g.index]
    for ax, col, xl in [(axs[0], "mediana_inv", "pairs of mechanisms reversed (%)"),
                        (axs[1], "mediana_vinc", "cells where the winner changes (%)")]:
        for yi, (k, r), grp in zip(y, g.iterrows(), gr):
            c, mk = st.GRUPPI[grp]
            if col == "mediana_inv":
                ax.plot([100 * r.min_inv, 100 * r.max_inv], [yi, yi], color=c, lw=1, alpha=0.5)
            ax.scatter(100 * r[col], yi, color=c, marker=mk, s=28, ec="white", lw=0.8, zorder=3)
        ax.set_xlabel(xl)
    axs[0].set_yticks(y, [x.replace("PA0-", "") for x in g.index])
    axs[0].set_ylabel("composition level vs households only")
    for grp in ("with public buildings", "with firms"):
        c, mk = st.GRUPPI[grp]
        axs[1].scatter([], [], color=c, marker=mk, s=28, label=grp)
    axs[1].legend(loc="lower right", bbox_to_anchor=(1, 1.0), ncol=2)
    fig.suptitle("Effect of public administrations (PA) and firms (ND): median over replicas and indicators "
                 "(line: min-max)", fontsize=8, x=0.01, ha="left")
    fig.tight_layout()
    st.salva(fig, out, "G05_composition")
    registra("G05_composition", "Effect of member-category composition",
             "Per ogni livello di composizione rispetto al solo domestico: coppie di metodi invertite e celle "
             "in cui cambia il vincitore; mediana sulle repliche, media sugli indicatori.")


# ---------------------------------------------------------------------------- G06
def g06_perdite(A, out):
    P = A["perdite"]
    ind = [i for i in st.INDICATORI if i in set(P.Scelto)]
    M = P.pivot_table(index="Scelto", columns="Perde", values="mediana").reindex(index=ind, columns=ind)
    lo = P.pivot_table(index="Scelto", columns="Perde", values="p10").reindex(index=ind, columns=ind)
    hi = P.pivot_table(index="Scelto", columns="Perde", values="p90").reindex(index=ind, columns=ind)
    fig, ax = plt.subplots(figsize=(LARGO, 4.4))
    im = ax.imshow(M.values, cmap=st.MAPPA, vmin=0, vmax=1, aspect="auto")
    for i in range(len(ind)):
        for j in range(len(ind)):
            v = M.values[i, j]
            if np.isnan(v) or i == j:
                continue
            ax.text(j, i, f"{v:.2f}\n{lo.values[i, j]:.2f}–{hi.values[i, j]:.2f}", ha="center", va="center",
                    fontsize=5.6, color="white" if v > 0.55 else st.INCHIOSTRO)
    nomi = [st.nome_indicatore(i) for i in ind]
    ax.set_xticks(range(len(ind)), nomi, rotation=30, ha="right")
    ax.set_yticks(range(len(ind)), nomi)
    ax.set_xlabel("criterion that is sacrificed")
    ax.set_ylabel("criterion chosen (best mechanism)")
    ax.grid(False)
    fig.colorbar(im, ax=ax, shrink=0.8, label="loss (0 = none, 1 = worst mechanism)")
    ax.set_title("Cost of the trade-offs: median loss over replicas, 10–90% below", loc="left")
    st.salva(fig, out, "G06_tradeoff_losses")
    registra("G06_tradeoff_losses", "Cost of the trade-offs",
             "Perdita (ottimistica, normalizzata 0-1) sul criterio in colonna quando si sceglie il metodo "
             "migliore sul criterio in riga; mediana sulle repliche e intervallo 10-90%.")


# ---------------------------------------------------------------------------- G07
def g07_insieme_ridotto(A, out):
    S = A["sufficienza"]
    ind = [i for i in st.INDICATORI if i in set(S.Indicatore)]   # gli otto del confronto
    tagli = sorted(S.TaglioTau.unique(), reverse=True)
    M = S.pivot_table(index="Indicatore", columns="TaglioTau", values="mediana").reindex(index=ind, columns=tagli)
    R = S.pivot_table(index="Indicatore", columns="TaglioTau", values="RappresentanteModale", aggfunc="first") \
        .reindex(index=ind, columns=tagli)
    fig, ax = plt.subplots(figsize=(LARGO, 3.6))
    im = ax.imshow(M.values, cmap=st.MAPPA, vmin=0.5, vmax=1, aspect="auto")
    for i in range(M.shape[0]):
        for j in range(M.shape[1]):
            v = M.values[i, j]
            ax.text(j, i, f"→ {st.nome_indicatore(R.values[i, j])}\n{v:.2f}", ha="center", va="center",
                    fontsize=6, color="white" if v > 0.8 else st.INCHIOSTRO)
    ax.set_xticks(range(len(tagli)), [f"τ cut {t}" for t in tagli])
    ax.set_yticks(range(len(ind)), [st.nome_indicatore(i) for i in ind])
    ax.grid(False)
    fig.colorbar(im, ax=ax, shrink=0.8, label="pairwise order agreement with the representative")
    ax.set_title("Reduced indicator set: representative (most frequent over replicas) and agreement (median)",
                 loc="left")
    st.salva(fig, out, "G07_reduced_set")
    registra("G07_reduced_set", "Reduced indicator set",
             "Per ogni taglio di tau: l'indicatore rappresentante del gruppo (il piu' frequente fra le repliche) "
             "e la concordanza delle coppie di metodi con il rappresentante (mediana).")


# ---------------------------------------------------------------------------- G08
def g08_pareto(A, out):
    P = as_shapley(A["pareto"])
    insiemi = list(P.InsiemeCriteri.unique())
    fig, axs = plt.subplots(1, len(insiemi), figsize=(LARGO, 3.4), sharey=True)
    axs = np.atleast_1d(axs)
    metodi = st.ordina_metodi(P.Metodo.unique())
    y = np.arange(len(metodi))[::-1]
    for ax, k in zip(axs, insiemi):
        s = P[P.InsiemeCriteri == k].set_index("Metodo").reindex(metodi)
        for yi, (m, r) in zip(y, s.iterrows()):
            c, mk = st.stile_metodo(m)
            ax.plot([100 * r["min"], 100 * r["max"]], [yi, yi], color=c, lw=1, alpha=0.5)
            ax.scatter(100 * r.mediana, yi, color=c, marker=mk, s=22, ec="white", lw=0.7, zorder=3)
        ax.set_xlim(-5, 105)
        ax.set_title(k.replace(" + ", "\n+ ").replace("Equita", "Equality").replace("Merito", "Merit")
                     .replace("Stabilita", "Stability").replace("Incentivo", "Incentive")
                     .replace("Sostenibilita", "NPV").replace("Tutti i criteri normativi", "All normative")
                     .replace("coseno lordo", "gross cosine").replace("Eccesso", "excess"), fontsize=6.5)
        ax.set_xlabel("non-dominated (%)")
    axs[0].set_yticks(y, [st.nome_metodo(m) for m in metodi])
    for f, (c, mk) in st.FAMIGLIE.items():
        axs[-1].scatter([], [], color=c, marker=mk, s=22, label=f)
    fig.legend(*axs[-1].get_legend_handles_labels(), loc="lower center", ncol=4, bbox_to_anchor=(0.5, -0.06))
    fig.suptitle("Share of communities in which the mechanism is on the Pareto front: median (marker), "
                 "min-max over replicas", fontsize=8, x=0.01, ha="left")
    fig.tight_layout()
    st.salva(fig, out, "G08_pareto")
    registra("G08_pareto", "Pareto front by set of criteria",
             "Quota di comunita' in cui il metodo non e' dominato, per insieme di criteri; mediana e "
             "min-max sulle repliche. Colore e marker = famiglia del metodo.")


# ---------------------------------------------------------------------------- G09
def g09_soglia(A, out):
    c = A["comunita_tutte"]
    c = c[c.Replica >= 1]
    fig, ax = plt.subplots(figsize=(LARGO, 3.4))
    rng = np.random.default_rng(2)
    for g in ("with firms", "with public buildings", "households only"):
        s = c[c.Gruppo == g]
        col, mk = st.GRUPPI[g]
        ax.scatter(s.Penetrazione_pct + rng.uniform(-1.3, 1.3, len(s)), 100 * s.QuotaIncentivata, s=6,
                   color=col, marker=mk, lw=0.2, ec="white", alpha=0.75,
                   label=f"{g} ({len(s)} communities)", zorder=3 if g == "households only" else 2)
    for t, ls, testo in [(55, "-", "55%: premium only"), (45, "--", "45%: premium + capital grant")]:
        ax.axhline(t, color=st.INCHIOSTRO, lw=0.9, ls=ls)
        ax.text(101, t + 0.8, testo, ha="right", fontsize=6.8)
    ax.set_xlabel("prosumer penetration (%)")
    ax.set_ylabel("shared / injected energy (%)")
    ax.legend(loc="upper right", bbox_to_anchor=(1, 1.0), markerscale=2)
    n = c.Replica.nunique()
    ax.set_title(f"Regulatory threshold on incentivised energy: every community of the {n} replicas", loc="left")
    st.salva(fig, out, "G09_threshold")
    registra("G09_threshold", "Regulatory threshold on incentivised energy",
             "Quota di energia condivisa sull'immessa di ogni comunita' di ogni replica, per gruppo; la soglia "
             "conta solo per le imprese.")


# ---------------------------------------------------------------------------- G10
def g10_van(A, out):
    V = A["van"]
    V = V[V.Fascia == "tutte"]
    metodi = st.ordina_metodi(V.Metodo.unique())
    gruppi = ["households only", "with public buildings", "with firms"]
    fig, axs = plt.subplots(1, 2, figsize=(LARGO, 3.4), sharey=True, gridspec_kw={"width_ratios": [3, 2]})
    y = np.arange(len(metodi))[::-1]
    for k, g in enumerate(gruppi):
        s = V[V.Gruppo == g].set_index("Metodo").reindex(metodi)
        col, mk = st.GRUPPI[g]
        dy = (k - 1) * 0.22
        axs[0].hlines(y + dy, s.VAN_min_p10, s.VAN_min_p90, color=col, lw=1, alpha=0.6)
        axs[0].scatter(s.VAN_min_mediana, y + dy, color=col, marker=mk, s=18, ec="white", lw=0.6, zorder=3, label=g)
        axs[1].scatter(100 * s.QuotaComunitaConNegativi, y + dy, color=col, marker=mk, s=18, ec="white", lw=0.6,
                       zorder=3)
    axs[0].axvline(0, color=st.INCHIOSTRO, lw=0.8)
    axs[0].set_yticks(y, [st.nome_metodo(m) for m in metodi])
    axs[0].set_xlabel("lowest member NPV in the community (EUR)\nmedian, 10–90%")
    axs[1].set_xlabel("communities with at least\none member at negative NPV (%)")
    axs[1].set_xlim(-3, 103)
    axs[0].legend(loc="lower right", fontsize=6.3)
    fig.suptitle("Complementary analysis: economic sustainability of participation", fontsize=8, x=0.01, ha="left")
    fig.tight_layout()
    st.salva(fig, out, "G10_npv")
    registra("G10_npv", "Economic sustainability of participation (NPV)",
             "VAN minimo fra i membri di ogni comunita' (mediana e 10-90% su comunita' e repliche) e quota di "
             "comunita' con almeno un membro a VAN negativo, per metodo e gruppo. Analisi complementare.")


# ---------------------------------------------------------------------------- G11
def g11_prosumer(A, out):
    Q = A["quote_prosumer"]
    Q = Q[(Q.Gruppo == "households only") & (Q.Fascia != "tutte")]
    metodi = st.ordina_metodi(Q.Metodo.unique())
    fasce = sorted(Q.Fascia.unique())
    fig, ax = plt.subplots(figsize=(LARGO, 3.3))
    y = np.arange(len(metodi))[::-1]
    for k, f in enumerate(fasce):
        s = Q[Q.Fascia == f].set_index("Metodo").reindex(metodi)
        dy = (k - (len(fasce) - 1) / 2) * 0.22
        col = st.FASCE[int(f) - 1]
        ax.hlines(y + dy, 100 * s.QuotaProsumer_p10, 100 * s.QuotaProsumer_p90, color=col, lw=1, alpha=0.7)
        ax.scatter(100 * s.QuotaProsumer_mediana, y + dy, color=col, s=20, ec="white", lw=0.6, zorder=3,
                   label=etichetta_fascia(f))
    ax.set_yticks(y, [st.nome_metodo(m) for m in metodi])
    ax.set_xlabel("share of the incentive going to prosumers (%): median, 10–90%")
    ax.legend(title="penetration", loc="lower left", bbox_to_anchor=(0, 1.0), ncol=3, title_fontsize=7)
    fig.suptitle("Who is rewarded: share to prosumers (households only; band 4 = 100% prosumers, omitted)",
                 fontsize=8, x=0.01, ha="left", y=1.06)
    st.salva(fig, out, "G11_prosumer_share")
    registra("G11_prosumer_share", "Share of the incentive going to prosumers",
             "Quota dell'incentivo ai prosumer per metodo e fascia di penetrazione (livello base): mediana e "
             "10-90% su comunita' e repliche.")


# ---------------------------------------------------------------------------- G12
def g12_stabilita(A, out):
    p = as_shapley(A["poli_per_replica"])
    p = p[p.Indicatore.isin(["EccessoMax_EUR", "CoalizioniInstabili"])]
    p = p.groupby(["Replica", "Indicatore", "Membri", "Metodo"]).agg(C=("CelleFraIPrimi", "sum"),
                                                                      Tot=("Celle", "first")).reset_index()
    p["Q"] = (p.C / p.Tot).clip(upper=1)
    fig, axs = plt.subplots(1, 2, figsize=(LARGO, 3.3), sharey=True)
    righe = st.ordina_metodi(p.Metodo.unique())
    colonne = sorted(p.Membri.unique())
    for ax, ind in zip(axs, ["EccessoMax_EUR", "CoalizioniInstabili"]):
        M = p[p.Indicatore == ind].pivot_table(index="Metodo", columns="Membri", values="Q", aggfunc="median")
        M = M.reindex(index=righe, columns=colonne).fillna(0)
        im = ax.imshow(M.values, cmap=st.MAPPA, vmin=0, vmax=1, aspect="auto")
        for i in range(M.shape[0]):
            for j in range(M.shape[1]):
                v = M.values[i, j]
                if v > 0:
                    ax.text(j, i, f"{100 * v:.0f}", ha="center", va="center", fontsize=6,
                            color="white" if v > 0.55 else st.INCHIOSTRO)
        ax.set_xticks(range(M.shape[1]), [str(c) for c in M.columns])
        ax.set_xlabel("members")
        ax.set_title(st.nome_indicatore(ind), fontsize=7.5)
        ax.grid(False)
        axs[0].set_yticks(range(M.shape[0]), [st.nome_metodo(m) for m in M.index])
    fig.colorbar(im, ax=axs, shrink=0.8, label="share of bands ranked first (%), median",
                 format=lambda x, _: f"{100 * x:.0f}")
    fig.suptitle("Coalitional stability by community size (households only)", fontsize=8, x=0.01, ha="left")
    st.salva(fig, out, "G12_stability_by_size")
    registra("G12_stability_by_size", "Coalitional stability by community size",
             "Per taglia, quota delle fasce in cui il metodo e' fra i primi sull'eccesso massimo e sulle "
             "coalizioni instabili; mediana sulle repliche. Stabilita' calcolata fino a 25 membri.")


# ---------------------------------------------------------------------------- G13
def g13_robustezza(A, out):
    R = A["robustezza"]
    nomi = {"tau": "sign of τ-b\n(pair × band)", "vincitore": "first-ranked mechanism\n(indicator × cell)",
            "capovolgimento": "reversal with\npenetration", "soglia": "regulatory\nthreshold"}
    tipi = [t for t in nomi if t in set(R.Tipo)]
    fig, ax = plt.subplots(figsize=(LARGO, 2.4))
    y = np.arange(len(tipi))[::-1]
    for yi, t in zip(y, tipi):
        s = R[R.Tipo == t]
        sin = 0
        for v, col, lab in [("regge", st.BLU, "holds (≥ 15/20)"), ("dipende dai partecipanti", "#B5B5B5",
                            "depends on participants"), ("si inverte", st.ARANCIO, "reverses (≤ 5/20)")]:
            w = 100 * (s.Verdetto == v).mean()
            ax.barh(yi, w, left=sin, color=col, height=0.55, ec=st.SFONDO, lw=1.2,
                    label=lab if yi == y[0] else None)
            if w >= 8:
                ax.text(sin + w / 2, yi, f"{w:.0f}%", ha="center", va="center", fontsize=6.5,
                        color="white" if col != "#B5B5B5" else st.INCHIOSTRO)
            sin += w
        ax.text(101, yi, f"n = {len(s)}; halves agree {100 * s.MetaConcordi.mean():.0f}%", va="center", fontsize=6.5)
    ax.set_yticks(y, [nomi[t] for t in tipi])
    ax.set_xlim(0, 100)
    ax.set_xlabel("share of conclusions (%)")
    ax.legend(ncol=3, loc="lower left", bbox_to_anchor=(0, 1.0))
    ax.grid(axis="y", visible=False)
    st.salva(fig, out, "G13_robustness")
    registra("G13_robustness", "Robustness of the conclusions to the households drawn",
             "Quota di conclusioni che reggono (>= 15/20 repliche), dipendono dai partecipanti o si invertono; "
             "a destra, quota di conclusioni su cui le due meta' delle repliche danno lo stesso verdetto.")


# ---------------------------------------------------------------------------- main
FILE = ["poli_per_replica", "tau_per_replica", "inversioni_per_replica", "varianza", "composizione",
        "perdite", "sufficienza", "pareto", "comunita_tutte", "van", "quote_prosumer", "robustezza"]
FIGURE = [g01_poli, g02_tau, g03_inversioni, g04_varianza, g05_composizione, g06_perdite,
          g07_insieme_ridotto, g08_pareto, g09_soglia, g10_van, g11_prosumer, g12_stabilita, g13_robustezza]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--blocco", default="unito")
    ap.add_argument("--radice", default=str(ROOT / "outputs" / "repliche"))
    ap.add_argument("--out", default=str(ROOT / "outputs" / "tesi_finale" / "figure"))
    a = ap.parse_args(argv)
    agg = Path(a.radice) / a.blocco / "aggregato"
    A = {}
    for f in FILE:
        p = agg / f"{f}.csv"
        if not p.exists():
            raise SystemExit(f"manca {p}: lanciare prima aggrega_repliche.py --blocco {a.blocco}")
        A[f] = pd.read_csv(p, dtype={"Fascia": str} if f in ("van", "quote_prosumer") else None)
    st.imposta()
    out = Path(a.out)
    for g in FIGURE:
        g(A, out)
    pd.DataFrame(CATALOGO).to_csv(out / "figure.csv", index=False)
    print(f"{len(CATALOGO)} figure in {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
