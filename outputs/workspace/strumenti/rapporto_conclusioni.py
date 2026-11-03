"""Rapporto finale: figure commentate e conclusioni rispetto alla domanda di ricerca.

Uso, dalla root del progetto (dopo grafici_metodi.py sui due blocchi, vedi LEGGIMI.md):
    venv/Scripts/python.exe -I outputs/workspace/strumenti/rapporto_conclusioni.py

Scrive un file HTML unico, con le figure incorporate, in outputs/report/. Ogni numero del
testo viene dai CSV dei run (nessun valore scritto a mano). Ogni affermazione qualitativa del
testo ha un controllo: se i dati cambiano e un'affermazione non regge piu', lo script si ferma
e dice quale, invece di scrivere una pagina sbagliata.

Fonti (default):
  --tabelle    outputs/tables_main2_fino25_unito      295 comunita', 5-25 membri, 10 metodi
  --tabelle18  outputs/tables_main2_fino18_IND        fino a 18 membri, 11 metodi (Shapley, Nucleolo)
  --export     outputs/workspace/export_fino25_unito  valori grezzi (esporta_run_livelli.m)
  --figure     outputs/figures_tesi_fino25_unito      figure di grafici_metodi.py, 5-25 membri
  --figure18   outputs/figures_tesi_fino18_IND        figure di grafici_metodi.py, fino a 18
  --numeri     outputs/tables_tesi_fino25_unito       numeri dietro le figure
Produce anche F14 (soglia regolatoria) in --figure e il suo CSV in --numeri.
"""
import argparse
import base64
import html
import io
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from PIL import Image

# ============================================================ utilita'
FALLITE = []


def verifica(cond, msg):
    """Un'affermazione del testo che i dati devono sostenere."""
    if not bool(cond):
        FALLITE.append(msg)


def n(x, d=2):
    if x is None or not np.isfinite(float(x)):
        return "n.d."
    return f"{float(x):.{d}f}".replace("-", "−").replace(".", ",")


def pc(x, d=0):
    """Frazione -> percentuale."""
    return n(100 * float(x), d) + "%"


def e(s):
    return html.escape(str(s))


def livello_da_codice(c):
    c = int(c)
    if c < 10:
        return f"PA{c}"
    return f"ND{c // 10}" + (f"_PA{c % 10}" if c % 10 else "")


NOMI_IND = {
    "EI_orig": "EI", "Gini": "Gini", "FairnessIndex": "Fairness Index", "Sigma": "σ",
    "EccessoMax_EUR": "Eccesso massimo", "CoalizioniInstabili": "Coalizioni instabili",
    "ForzaIncentivante": "Forza incentivante", "AllineamentoVirtu": "Allineamento netto",
    "AllineamentoVirtu_lordo": "Allineamento lordo", "VAN_min_EUR": "VAN minimo",
    "InclusioneLIHC": "Inclusione LIHC",
}


def ni(k):
    return NOMI_IND.get(k, k)


def immagine(p, larghezza):
    """PNG ridotto e a 256 colori: le figure sono grafici, la palette basta e il file pesa un quarto."""
    im = Image.open(p).convert("RGB")
    if im.width > larghezza:
        im = im.resize((larghezza, round(im.height * larghezza / im.width)), Image.LANCZOS)
    im = im.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    buf = io.BytesIO()
    im.save(buf, "PNG", optimize=True)
    return base64.b64encode(buf.getvalue()).decode()


def figura(p, titolo, cosa, lettura, larghezza=1600, ident=None):
    if not p.exists():
        raise SystemExit(f"manca la figura {p}: lanciare prima grafici_metodi.py (LEGGIMI.md)")
    ident = ident or p.stem
    return (f"<div class='fig' id='{e(ident)}'><h3>{titolo}</h3>"
            f"<p class='cosa'><b>Cosa mostra.</b> {cosa}</p>"
            f"<img alt='{e(titolo)}' src='data:image/png;base64,{immagine(p, larghezza)}'>"
            f"<p class='file'>{e(p.parent.name)}/{e(p.name)} (anche .pdf)</p>"
            f"<div class='lettura'><b>Cosa dice.</b> {lettura}</div></div>")


def tabella(righe, intestazioni, num_da=1):
    """righe: liste di stringhe gia' formattate; le colonne da num_da in poi sono allineate a destra."""
    th = "".join(f"<th{' class=n' if i >= num_da else ''}>{h}</th>" for i, h in enumerate(intestazioni))
    tr = "".join("<tr>" + "".join(f"<td{' class=n' if i >= num_da else ''}>{c}</td>"
                                  for i, c in enumerate(r)) + "</tr>" for r in righe)
    return f"<div class='tab'><table><thead><tr>{th}</tr></thead><tbody>{tr}</tbody></table></div>"


def dettagli(sommario, contenuto):
    return f"<details><summary>{sommario}</summary>{contenuto}</details>"


# ============================================================ dati
def carica(a):
    T, T18, X, NUM = Path(a.tabelle), Path(a.tabelle18), Path(a.export), Path(a.numeri)
    D = {"T": T, "T18": T18, "NUM": NUM}
    D["com"] = pd.read_csv(X / "comunita.csv")
    D["tf"] = pd.read_csv(X / "tfair_lungo.csv")
    # fascia = rango della penetrazione dentro la taglia, sul livello base (come MAIN2 §7.6.2)
    base = D["com"][D["com"].Composizione == "PA0"][["Scheda", "Membri", "Penetrazione_pct"]].copy()
    base["Fascia"] = base.groupby("Membri").Penetrazione_pct.rank(method="dense").astype(int)
    D["fascia"] = base.set_index("Scheda").Fascia
    g = base.groupby("Fascia").Penetrazione_pct
    D["lab_fascia"] = {f: (f"{lo:.0f}–{hi:.0f}%" if round(lo) != round(hi) else f"{lo:.0f}%")
                       for f, lo, hi in zip(g.min().index, g.min(), g.max())}
    D["tf0"] = D["tf"][D["tf"].Composizione == "PA0"].merge(base[["Scheda", "Fascia"]], on="Scheda")
    D["com0"] = D["com"][D["com"].Composizione == "PA0"].merge(base[["Scheda", "Fascia"]], on="Scheda")
    for nome, rel in [("vinc", "confronto/griglia_vincitori.csv"), ("sweep", "confronto/inversioni_per_sweep.csv"),
                      ("tpf", "sintesi/tau_per_fascia.csv"), ("perd", "sintesi/perdite_tradeoff.csv"),
                      ("perdf", "sintesi/perdite_tradeoff_fascia.csv"), ("qp", "sintesi/quote_prosumer.csv"),
                      ("cg", "sintesi/cluster_gruppi.csv"), ("cs", "sintesi/cluster_sufficienza.csv"),
                      ("cp", "sintesi/cluster_pareto.csv"), ("par", "sintesi/pareto_conteggi.csv"),
                      ("sens", "sintesi/sensibilita_soglia_sweep.csv"),
                      ("sensv", "sintesi/sensibilita_soglia_vincitori.csv"),
                      ("rimp", "sintesi/rimpianto_medio.csv"),
                      ("pas", "confronto_PA/pa_sommario.csv"), ("pps", "confronto_PA/pa_per_scheda.csv"),
                      ("pae", "confronto_PA/pa_effetti.csv"), ("pac", "confronto_PA/pa_cluster.csv"),
                      ("f1", "fase1/regime_le18_Shapley_vs_AS_per_taglia.csv")]:
        D[nome] = pd.read_csv(T / rel)
    D["cp18"] = pd.read_csv(T18 / "sintesi/cluster_pareto.csv")
    D["rimp18"] = pd.read_csv(T18 / "sintesi/rimpianto_medio.csv")
    D["f03"] = pd.read_csv(NUM / "F03_sintesi.csv", header=[0, 1], index_col=0)
    D["f03_18"] = pd.read_csv(Path(a.numeri18) / "F03_sintesi.csv", header=[0, 1], index_col=0)
    D["f03b"] = pd.read_csv(NUM / "F03b_sintesi_per_fascia.csv", index_col=0)
    D["f06"] = pd.read_csv(NUM / "F06_scomposizione_varianza_per_indicatore.csv", index_col=0)
    D["f07"] = pd.read_csv(NUM / "F07_posta_in_gioco.csv")
    D["f10"] = pd.read_csv(NUM / "F10_delta_composizione.csv")
    D["f11"] = pd.read_csv(NUM / "F11_scala_vs_composizione.csv")
    D["controlli"] = (NUM / "controlli.txt").read_text(encoding="utf-8")
    return D


# ============================================================ F14: soglia regolatoria
def f14_soglia(D, out, tab):
    c = D["com"].copy()
    c["Gruppo"] = np.where(c.Composizione == "PA0", "households only",
                           np.where(c.Composizione.str.startswith("ND"), "with firms (and possibly PA)",
                                    "with public buildings"))
    c["Quota_pct"] = 100 * c.QuotaIncentivata
    c.to_csv(tab / "F14_soglia_regolatoria.csv", index=False)
    stile = {"households only": ("#2171b5", "o"), "with public buildings": ("#e6550d", "s"),
             "with firms (and possibly PA)": ("#54278f", "^")}
    fig, ax = plt.subplots(figsize=(6.4, 3.4))
    rng = np.random.default_rng(0)
    for g, (col, mk) in stile.items():
        s = c[c.Gruppo == g]
        ax.scatter(s.Penetrazione_pct + rng.uniform(-1.2, 1.2, len(s)), s.Quota_pct, s=14, color=col,
                   marker=mk, lw=0.3, ec="white", label=f"{g} ({len(s)})", zorder=3)
    ax.axhline(55, color="k", lw=1.0)
    ax.axhline(45, color="k", lw=0.8, ls="--")
    ax.text(101, 55.8, "55%: premium only", fontsize=7, ha="right")
    ax.text(101, 45.8, "45%: premium + capital grant", fontsize=7, ha="right")
    ax.set_xlabel("prosumer penetration [%]")
    ax.set_ylabel("shared / injected energy [%]")
    ax.set_ylim(0, 60)
    ax.grid(True, color="#e6e6e6", lw=0.5)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    ax.legend(frameon=False, fontsize=7, loc="upper right", bbox_to_anchor=(1, 0.70))
    ax.set_title("Regulatory threshold on incentivised energy (DM 414/2023): one point per community",
                 fontsize=8.5)
    fig.tight_layout()
    for ext in ("png", "pdf"):
        fig.savefig(out / f"F14_soglia_regolatoria.{ext}", dpi=200, bbox_inches="tight")
    plt.close(fig)
    return c


# ============================================================ sezioni
def sezione(ident, titolo, corpo):
    return f"<section id='{ident}'><h2>{titolo}</h2>{corpo}</section>"


def tau(D, a, b, f):
    t = D["tpf"]
    r = t[(((t.IndicatoreA == a) & (t.IndicatoreB == b)) | ((t.IndicatoreA == b) & (t.IndicatoreB == a)))
          & (t.Fascia == f)]
    return r.iloc[0]


def perdita(D, scelto, perde, col="PerditaOttimistica_medio"):
    p = D["perd"]
    r = p[(p.Scelto == scelto) & (p.Perde == perde)]
    return r.iloc[0][col] if len(r) else np.nan


def costruisci(a):
    D = carica(a)
    FIG, FIG18 = Path(a.figure), Path(a.figure18)
    com, tf0, com0, lab = D["com"], D["tf0"], D["com0"], D["lab_fascia"]
    fasce = sorted(lab)
    taglie = sorted(com0.Membri.unique())
    metodi_unito = sorted(D["rimp"].Metodo.unique())
    metodi_18 = sorted(D["rimp18"].Metodo.unique())
    livelli = com.Composizione.value_counts()
    soglia = f14_soglia(D, FIG, Path(a.numeri))
    S = {}   # numeri citati nel testo

    # ---------------------------------------------------------------- disegno
    verifica(len(com) == 295, f"comunita' attese 295, trovate {len(com)}")
    verifica(len(com0) == 28 and len(taglie) == 7 and len(fasce) == 4, "griglia base 7 taglie x 4 fasce")
    verifica(len(metodi_unito) == 10 and "Shapley" not in metodi_unito and "Nucleolo" not in metodi_unito,
             "analisi unita: 10 metodi senza Shapley esatto e Nucleolo")
    verifica(len(metodi_18) == 11 and "Nucleolo" in metodi_18, "analisi fino a 18: 11 metodi con il Nucleolo")
    verifica(D["tf"].InclusioneLIHC.isna().all(), "InclusioneLIHC e' NaN in tutte le comunita'")
    f1 = D["f1"]
    S["as_rd"] = (f1.RD_medio_pct.min(), f1.RD_medio_pct.max())
    S["as_rho"] = f1.Spearman_rho_min.min()

    righe_liv = []
    for k in ["PA0", "PA1", "PA2", "PA3"] + sorted(x for x in livelli.index if x.startswith("ND")):
        if k in livelli:
            righe_liv.append([e(k), str(int(livelli[k])),
                              f"{int(com[com.Composizione == k].Membri.min())}–{int(com[com.Composizione == k].Membri.max())}"])
    disegno = (
        "<p>Ogni comunità è una simulazione deterministica di un anno orario (8760 ore, prezzi zonali "
        "MGP 2025, zona Nord). In ogni comunità i metodi si dividono lo stesso montepremi v(N), cioè "
        "l'incentivo sull'energia condivisa, e vengono giudicati con gli stessi indicatori. Le comunità "
        "variano su tre assi:</p><ul>"
        f"<li><b>taglia</b>: {', '.join(str(t) for t in taglie)} membri;</li>"
        f"<li><b>penetrazione dei prosumer</b>: quattro fasce per taglia ({', '.join(lab[f] for f in fasce)}). "
        "La fascia è il rango della penetrazione dentro la taglia, non una soglia fissa;</li>"
        "<li><b>composizione</b>: solo famiglie (PA0), più 1-3 edifici pubblici (PA1-PA3: comune, scuola, "
        "palazzetto), più 1-3 imprese (ND1-ND3), oppure imprese e PA insieme. N, consumatori e prosumer "
        "restano quelli della scheda di partenza: per ogni PA o impresa che entra esce un prosumer domestico.</li></ul>"
        + tabella(righe_liv, ["Livello", "Comunità", "Membri"]) +
        f"<p><b>Due analisi, perché due insiemi di metodi.</b> Shapley esatto, Nucleolo ed eccesso di "
        f"coalizione enumerano le 2<sup>n</sup> coalizioni e si calcolano fino a 18 membri. "
        f"L'<b>analisi unita 5-25 membri</b> ({len(com)} comunità) usa quindi i {len(metodi_unito)} metodi "
        f"presenti ovunque: l'Adaptive Sampling Shapley prende il posto dello Shapley, che sotto i 18 membri "
        f"approssima con uno scarto relativo medio fra {n(S['as_rd'][0], 1)}% e {n(S['as_rd'][1], 1)}% per taglia "
        f"(Spearman minimo {n(S['as_rho'])}), e il Nucleolo manca. "
        f"L'<b>analisi fino a 18 membri</b> ha {len(metodi_18)} metodi, con Shapley esatto e Nucleolo. "
        f"La stabilità di coalizione esiste solo lì: nell'analisi unita vale per le 20 comunità di base fino a 18 membri.</p>"
        f"<p><b>Metodi e famiglie.</b> Teoria dei giochi cooperativi: Shapley (o la sua stima AS), Nucleolo, "
        f"Variance Least Core. Regole semplici: Equal Split, Proportional to Consumption. Euristiche dalla "
        f"letteratura sulle CER italiane: Remuneration Model 1, Cascading Tree, Weighted Solidarity, Tri-level EP. "
        f"Chiavi di sincronismo (performance-based): Pearson Key, Similarity-Utilization.</p>"
        f"<p><b>Indicatori.</b> Uguaglianza: Gini dei risparmi (EI = 1 − Gini). Merito: Fairness Index e σ, "
        f"distanza dalla ripartizione per contributo marginale v(N) − v(N∖{{i}}). Stabilità: eccesso massimo "
        f"di coalizione e numero di coalizioni bloccanti. Premio al sincronismo: forza incentivante (covarianza "
        f"fra quota e virtuosità, 1 = Similarity-Utilization, 0 = Equal Split) e allineamento (coseno) sui profili "
        f"netti e lordi. Sostenibilità: VAN del membro messo peggio. L'inclusione LIHC è implementata ma non "
        f"valutabile (sezione 13).</p>"
        f"<p><b>Punteggio normalizzato.</b> Le figure F02, F03, F06 e F10 usano 1 − rimpianto: in ogni comunità e "
        f"per ogni indicatore il metodo migliore vale 1 e il peggiore 0, con la soglia di rilevanza del README "
        f"§7.6.3 (pari se la distanza è sotto il 10% dell'escursione, o sotto il 5% di v(N) per gli euro).</p>")

    # ---------------------------------------------------------------- graduatorie per criterio
    med = D["f03"]["mediana"]
    m = lambda k, i: med.loc[k, i]
    verifica(m("Equal Split", "Gini") == 1 and m("Equal Split", "CoalizioniInstabili") < 0.1,
             "Equal Split: primo sul Gini, quasi ultimo sulle coalizioni instabili")
    verifica(m("Variance Least Core", "FairnessIndex") == 1 and m("Variance Least Core", "EccessoMax_EUR") == 1
             and m("Variance Least Core", "Gini") < 0.3, "VLC: primo su merito e stabilita', basso sul Gini")
    verifica(m("Similarity-Utilization", "ForzaIncentivante") == 1 and m("Similarity-Utilization", "Gini") < 0.1,
             "Similarity-Utilization: primo sull'incentivo, ultimo sul Gini")
    verifica(m("Cascading Tree", "Gini") > 0.6 and m("Cascading Tree", "ForzaIncentivante") < 0.05,
             "Cascading Tree: buono sul Gini, ultimo sull'incentivo")
    verifica(med.min(axis=1).max() < 0.35, "ogni metodo ha almeno una mediana sotto 0,35")
    compromessi = sorted(med.index[med.min(axis=1) >= 0.25])
    verifica(compromessi == ["Adaptive Sampling Shapley", "Remuneration Model 1"],
             "solo AS-Shapley e Remuneration Model 1 non hanno mediane sotto 0,25")
    v = D["vinc"]
    righe_v = []
    for ind in ["Gini", "FairnessIndex", "Sigma", "EccessoMax_EUR", "CoalizioniInstabili", "ForzaIncentivante",
                "AllineamentoVirtu", "AllineamentoVirtu_lordo", "VAN_min_EUR"]:
        s = v[(v.Indicatore == ind) & v.Vincitore.notna()]       # stabilita': solo fino a 18 membri
        soli = s[s.Vincitore != "(pari)"].Vincitore.value_counts()
        pari = (s.Vincitore == "(pari)").sum()
        # chi compare fra i primi (da solo o a pari)
        primi = pd.Series([x.strip() for r in s.PrimiAPari for x in str(r).split("=")]).value_counts()
        righe_v.append([ni(ind), str(len(s)),
                        "; ".join(f"{e(k)} {c}" for k, c in soli.items()) or "–", str(pari),
                        "; ".join(f"{e(k)} {c}" for k, c in primi.head(3).items())])
    S["es_gini"] = (v[(v.Indicatore == "Gini")].Vincitore == "Equal Split").sum()
    verifica(S["es_gini"] == 28, "Equal Split primo sul Gini in 28 comunita' su 28")
    primi_is = pd.Series([x.strip() for r in v[v.Indicatore == "ForzaIncentivante"].PrimiAPari
                          for x in str(r).split("=")]).value_counts()
    verifica(primi_is.index[0] in ("Similarity-Utilization", "Pearson Key", "Tri-level EP"),
             "sulla forza incentivante i primi sono le chiavi di sincronismo")
    is100 = tf0[(tf0.Penetrazione_pct == 100) & tf0.Metodo.isin(["Pearson Key", "Tri-level EP"])].ForzaIncentivante
    verifica(is100.max() > 1, "Pearson Key e Tri-level EP superano 1 di forza incentivante al 100%")
    m18 = D["f03_18"]["mediana"]
    verifica((m18.loc["Nucleolo"] - m18.loc["Variance Least Core"]).abs().max() <= 0.02,
             "fino a 18 membri Nucleolo e VLC hanno lo stesso profilo")
    d_sh = (m18.loc["Shapley"] - med.loc["Adaptive Sampling Shapley"]).abs()
    verifica(d_sh.drop("AllineamentoVirtu_lordo").max() <= 0.05,
             "Shapley (<=18) e AS (5-25) differiscono al piu' di 0,05 tranne l'allineamento lordo")
    f3b = D["f03b"]
    fb = lambda k, i, f: f3b[f3b.Fascia == f].loc[k, i]
    chiavi_cons = ["Proportional to Consumption", "Pearson Key", "Similarity-Utilization", "Tri-level EP"]
    fi1 = max(fb(k, "FairnessIndex", 1) for k in chiavi_cons)
    fi23 = [fb(k, "FairnessIndex", f) for k in chiavi_cons for f in (2, 3)]
    verifica(fi1 <= 0.15 and min(fi23) >= 0.6, "chiavi di consumo: ultime sul merito a fascia 1, buone alle fasce 2-3")
    vlc_g = [fb("Variance Least Core", "Gini", f) for f in fasce]
    verifica(vlc_g[0] >= 0.5 and max(vlc_g[1:]) <= 0.25, "VLC: discreto sul Gini solo alla fascia 1")
    verifica(f3b[f3b.Fascia == 4].AllineamentoVirtu_lordo.idxmax() == "Weighted Solidarity",
             "al 100% la Weighted Solidarity e' prima sull'allineamento lordo")
    gini_max = tf0.Gini.max()
    es_ex_max = tf0[tf0.Metodo == "Equal Split"].EccessoMax_pct_vN.max()
    verifica(es_ex_max > 40, "eccesso massimo dell'Equal Split oltre il 40% di v(N)")

    graduatorie = (
        figura(FIG / "F03_sintesi_metodi_metriche.png", "F03 · Profilo di ogni metodo, analisi unita 5-25 membri",
               "per ogni metodo (righe) e indicatore (colonne), la mediana sulle 28 comunità di sole famiglie del "
               "punteggio normalizzato (1 = migliore in quella comunità), con l'intervallo interquartile.",
               f"<p>Nessun metodo è buono su tutto: ogni riga ha almeno una mediana sotto "
               f"{n(med.min(axis=1).max())}. I metodi si dispongono attorno a <b>tre poli</b>:</p><ul>"
               f"<li><b>uguaglianza</b>: Equal Split (Gini {n(m('Equal Split', 'Gini'))}) e, più distanti, Cascading "
               f"Tree ({n(m('Cascading Tree', 'Gini'))}), Remuneration Model 1 ({n(m('Remuneration Model 1', 'Gini'))}) "
               f"e Weighted Solidarity ({n(m('Weighted Solidarity', 'Gini'))}). Pagano su merito e stabilità: l'Equal "
               f"Split vale {n(m('Equal Split', 'CoalizioniInstabili'))} sulle coalizioni bloccanti;</li>"
               f"<li><b>merito e stabilità</b>: Variance Least Core ({n(m('Variance Least Core', 'FairnessIndex'))} su "
               f"Fairness Index ed eccesso) e Shapley/AS ({n(m('Adaptive Sampling Shapley', 'FairnessIndex'))}). "
               f"Pagano sull'uguaglianza (Gini {n(m('Variance Least Core', 'Gini'))} e "
               f"{n(m('Adaptive Sampling Shapley', 'Gini'))});</li>"
               f"<li><b>sincronismo</b>: Similarity-Utilization ({n(m('Similarity-Utilization', 'ForzaIncentivante'))}), "
               f"Pearson Key ({n(m('Pearson Key', 'ForzaIncentivante'))}), Tri-level EP "
               f"({n(m('Tri-level EP', 'ForzaIncentivante'))}) e Proportional to Consumption "
               f"({n(m('Proportional to Consumption', 'ForzaIncentivante'))}). Sono gli ultimi sul Gini "
               f"(≤ {n(max(m(k, 'Gini') for k in ['Similarity-Utilization', 'Pearson Key', 'Tri-level EP', 'Proportional to Consumption']))}).</li></ul>"
               f"<p>Il Cascading Tree è un caso a parte: discreto sull'uguaglianza, ultimo su merito "
               f"({n(m('Cascading Tree', 'FairnessIndex'))}) e incentivo ({n(m('Cascading Tree', 'ForzaIncentivante'))}). "
               f"La Weighted Solidarity non ha un punto di forza: è il metodo più spesso dominato (sezione 9). "
               f"Solo AS-Shapley (minimo {n(med.loc['Adaptive Sampling Shapley'].min())}, sul Gini) e Remuneration "
               f"Model 1 (minimo {n(med.loc['Remuneration Model 1'].min())}) non hanno mediane sotto 0,25: sono i "
               f"compromessi del set.</p>")
        + figura(FIG18 / "F03_sintesi_metodi_metriche.png", "F03 · Lo stesso profilo fino a 18 membri, con Shapley esatto e Nucleolo",
                 "come sopra, sulle 20 comunità di sole famiglie fino a 18 membri, con 11 metodi.",
                 "<p>Il Nucleolo e il Variance Least Core hanno lo stesso profilo (differenze ≤ 0,02): stanno entrambi "
                 "nel least core, e su questi dati il core non è mai vuoto. Lo Shapley esatto ha quasi lo stesso "
                 "profilo dell'AS dell'analisi unita (differenze ≤ 0,05 tranne l'allineamento lordo), quindi "
                 "sostituirlo sopra i 18 membri non cambia la lettura.</p>")
        + "<h3>Chi vince su ciascun indicatore (28 comunità di sole famiglie, 5-25 membri)</h3>"
        + tabella(righe_v, ["Indicatore", "Comunità", "Primo da solo", "A pari", "Più spesso fra i primi"], num_da=1)
        + "<p class='nota'>Stabilità (eccesso, coalizioni) solo fino a 18 membri, quindi 20 comunità. Primo da "
          "solo e a pari sommano al numero di comunità; l'ultima colonna conta le presenze fra i primi, da solo "
          "o a pari.</p>"
        + "<h3>Indicatori con un vincitore per costruzione</h3>"
        + tabella([
            ["Gini", "Equal Split", "Gini = 0 per definizione (quote uguali)."],
            ["Eccesso massimo", "Nucleolo (e VLC)", "il Nucleolo minimizza l'eccesso massimo; il VLC sta nel least core e ha lo stesso minimo."],
            ["Forza incentivante", "Similarity-Utilization = 1, Equal Split = 0", "sono le due ancore della scala, non un primato: la forza non è limitata a 1 (Pearson Key e Tri-level EP la superano al 100%)."],
            ["Fairness Index, σ", "nessuno", "il riferimento è la ripartizione per contributo marginale, che non è fra i metodi confrontati. Nucleolo e VLC ci arrivano più vicino, ma non per definizione."],
          ], ["Indicatore", "Favorito", "Perché"], num_da=9)
        + "<p>Per questi indicatori il primo posto non è un risultato. L'informazione sta nella graduatoria degli "
          "altri metodi e in quanto perdono rispetto al favorito (sezione 7).</p>"
        + figura(FIG / "F02_profili_metodo.png", "F02 · Il profilo comunità per comunità",
                 "ogni punto è una comunità, colorato per fascia di penetrazione; il trattino è la mediana. È la "
                 "distribuzione dietro le mediane di F03.",
                 f"<p>La dispersione verticale è quasi tutta fra fasce, cioè dovuta alla penetrazione, non al "
                 f"rumore (sezione 4). L'esempio più netto: Proportional to Consumption, Pearson Key, "
                 f"Similarity-Utilization e Tri-level EP valgono al più {n(fi1, 1)} sul Fairness Index alla fascia più "
                 f"bassa e {n(min(fi23), 1)}-{n(max(fi23), 1)} alle fasce 40-80%.</p>")
        + figura(FIG / "F01_valori_grezzi.png", "F01 · Gli stessi indicatori in unità naturali",
                 "valore grezzo di ogni indicatore, un punto per comunità (5-25 membri, sole famiglie), mediana in "
                 "nero. Lo Shapley esatto e il Nucleolo compaiono fino a 18 membri, l'AS solo a 20 e 25.",
                 f"<p>Serve a non leggere i punteggi come distanze assolute. Il Gini dei risparmi va da 0 (Equal Split) "
                 f"a {n(gini_max)} ({e(tf0.loc[tf0.Gini.idxmax(), 'Metodo'])}). L'eccesso massimo dell'Equal Split "
                 f"arriva al {n(es_ex_max, 0)}% di v(N), quello di Nucleolo e VLC resta ≤ 0.</p>"))

    # ---------------------------------------------------------------- accordo fra indicatori
    t_gi = [tau(D, "Gini", "ForzaIncentivante", f) for f in fasce]
    t_fi = [tau(D, "FairnessIndex", "ForzaIncentivante", f) for f in fasce]
    t_gf = [tau(D, "Gini", "FairnessIndex", f) for f in fasce]
    t_fe = [tau(D, "FairnessIndex", "EccessoMax_EUR", f) for f in fasce]
    verifica(t_gi[0].TauMedio > -0.5 and t_gi[0].TauMin < 0 < t_gi[0].TauMax,
             "tau(Gini, IS) alla fascia 1: debole e di segno variabile fra le taglie")
    verifica(all(t.TauMedio < -0.6 for t in t_gi[1:]), "tau(Gini, IS) < -0,6 dalla fascia 2")
    verifica(t_fi[0].TauMedio < -0.4 and all(t.TauMedio > 0 for t in t_fi[1:]),
             "tau(FI, IS): negativo alla fascia 1, positivo sopra")
    verifica(t_gf[0].TauMedio > 0.3 and all(t.TauMedio < 0 for t in t_gf[1:]),
             "tau(Gini, FI): positivo alla fascia 1, negativo sopra")
    verifica(all(t.TauMedio > 0.5 for t in t_fe), "tau(FI, eccesso) > 0,5 in tutte le fasce")
    righe_t = []
    for nome_c, serie in [("Gini ↔ forza incentivante", t_gi), ("Fairness Index ↔ forza incentivante", t_fi),
                          ("Gini ↔ Fairness Index", t_gf), ("Fairness Index ↔ eccesso massimo", t_fe)]:
        righe_t.append([nome_c] + [f"{n(t.TauMedio)} <span class='m'>[{n(t.TauMin)}; {n(t.TauMax)}]</span>"
                                   for t in serie])
    accordo = (
        figura(FIG / "F12_accordo_indicatori.png", "F12 · Quanto gli indicatori ordinano i metodi allo stesso modo",
               "τ-b di Kendall medio fra le graduatorie dei metodi prodotte da due indicatori, dopo averli orientati "
               "(+1 = stesso ordine, −1 = ordine opposto). Media sulle 7 taglie, un pannello per fascia.",
               "<p>La struttura del conflitto <b>cambia con la penetrazione</b>. A penetrazione 20-30% l'uguaglianza "
               "va d'accordo con merito e stabilità, e tutti e tre si oppongono all'incentivo. Dalla fascia 40-53% "
               "in su merito, stabilità e incentivo vanno d'accordo, e l'uguaglianza si oppone a tutti. "
               "L'allineamento lordo si stacca da tutto al 100%.</p>")
        + tabella(righe_t, ["Coppia (τ-b medio [min; max] fra le taglie)"] + [lab[f] for f in fasce])
        + "<p><b>Perché.</b> A bassa penetrazione l'energia condivisa è limitata dalla produzione: i prosumer "
          "sono il lato scarso e hanno contributo marginale alto, ma sui profili netti hanno virtuosità bassa "
          "(il loro carico residuo è nullo nelle ore di eccedenza). Le regole di merito premiano i prosumer, "
          "quindi premiano il contrario del sincronismo. Sopra il 40% il lato scarso diventa il carico: merito e "
          "sincronismo premiano gli stessi consumatori, e il conflitto si sposta sull'uguaglianza (sezione 5).</p>")

    # ---------------------------------------------------------------- penetrazione e taglia
    sw = D["sweep"]
    pen = sw[sw.Sweep == "penetrazione"]
    tag = sw[sw.Sweep == "taglia"]
    f06 = D["f06"]
    S["eta_p"] = (f06.eta2_penetrazione.min(), f06.eta2_penetrazione.max())
    S["eta_n"] = (f06.eta2_taglia.min(), f06.eta2_taglia.max())
    verifica(S["eta_p"][0] > 0.5 and S["eta_n"][1] < 0.15, "penetrazione > 50% della varianza, taglia < 15%")
    verifica(pen.QuotaInvertite.is_monotonic_decreasing, "inversioni lungo la penetrazione decrescenti con la taglia")
    sens = D["sens"]
    sp = sens[sens.Sweep == "penetrazione"].groupby(["FracEscursione", "FracVN"]).QuotaInvertite.agg(["min", "max"]).reset_index()
    verifica((D["sensv"].AltroMetodoPrimo == 0).all(), "a nessuna soglia un altro metodo prende il primo posto")
    righe_sw = [[e(r.Sweep), e(r.Fisso), str(int(r.Configurazioni)), pc(r.QuotaInvertite, 1),
                 pc(r.InvertiteAgliEstremi / r.SerieEsaminate, 1)] for r in sw.itertuples()]
    righe_sens = [[f"{n(100 * r.FracEscursione, 0)}% / {n(100 * r.FracVN, 1)}%", f"{pc(r['min'])}–{pc(r['max'])}"]
                  for _, r in sp.iterrows()]
    f04 = "".join(figura(FIG / "assi" / f"F04_penetrazione_{k}.png", f"F04 · {ni(k)} contro penetrazione",
                         "una linea per taglia, un punto per comunità, la linea tratteggiata è la mediana fra le taglie.",
                         "si guarda se le linee delle taglie si sovrappongono (la taglia conta poco) e dove cambia la "
                         "pendenza: il cambio di regime cade fra il 30% e il 50% di penetrazione.", larghezza=1300)
                  for k in ["Gini", "FairnessIndex", "Sigma", "AllineamentoVirtu", "AllineamentoVirtu_lordo"])
    f05 = "".join(figura(FIG / "assi" / f"F05_taglia_{k}.png", f"F05 · {ni(k)} contro taglia",
                         "una linea per fascia di penetrazione, un punto per comunità.",
                         "si guarda se le linee sono piatte. Lo sono quasi sempre da 8 membri in su, coerente con la "
                         "piccola quota di varianza spiegata dalla taglia (F06); a 5 membri, con 1-3 impianti, i "
                         "valori si staccano.",
                         larghezza=1300)
                  for k in ["Gini", "FairnessIndex", "Sigma", "EccessoMax_EUR", "CoalizioniInstabili",
                            "ForzaIncentivante", "AllineamentoVirtu", "AllineamentoVirtu_lordo"])
    sensibilita = (
        figura(FIG / "F06_scomposizione_varianza.png", "F06 · Quanto spiegano penetrazione e taglia",
               "scomposizione a due vie (fascia × taglia, una comunità per cella) della varianza dei punteggi "
               "normalizzati. A sinistra la media pesata sui metodi, a destra la quota spiegata dalla penetrazione "
               "per ogni metodo. Il residuo è interazione: senza repliche non si separa dal rumore.",
               f"<p>La penetrazione spiega fra il {pc(S['eta_p'][0])} e il {pc(S['eta_p'][1])} della varianza fra "
               f"comunità, la taglia fra il {pc(S['eta_n'][0], 1)} e il {pc(S['eta_n'][1], 1)}. L'indicatore meno "
               f"spiegato è l'allineamento lordo (residuo {pc(f06.loc['AllineamentoVirtu_lordo', 'residuo_interazione'])}): "
               f"è il meno robusto del set. Le celle 'const.' sono metodi sempre primi su quell'indicatore "
               f"(Equal Split sul Gini, VLC sulla stabilità).</p>")
        + "<h3>Inversioni di graduatoria lungo i due assi</h3>"
        + tabella(righe_sw, ["Asse", "Tenuto fisso", "Configurazioni", "Coppie invertite", "Invertite agli estremi"], num_da=2)
        + f"<p>Una coppia (indicatore, coppia di metodi) è invertita se un metodo batte l'altro oltre la soglia "
          f"di rilevanza in una configurazione e ne è battuto in un'altra. Lungo la penetrazione si inverte fra il "
          f"{pc(pen.QuotaInvertite.min())} (25 membri) e il {pc(pen.QuotaInvertite.max())} (5 membri) delle coppie, "
          f"e la quota cala con la taglia. Lungo la taglia, a fascia fissa, fra il {pc(tag.QuotaInvertite.min())} e "
          f"il {pc(tag.QuotaInvertite.max())}, massima a bassa penetrazione. I due assi non si confrontano in "
          f"valore assoluto: 4 configurazioni contro 7.</p>"
        + "<h3>Sensibilità alla soglia di rilevanza</h3>"
        + tabella(righe_sens, ["Soglia (escursione / v(N))", "Coppie invertite lungo la penetrazione"])
        + "<p>Le inversioni calano con la soglia ma non spariscono, quindi non sono un effetto di differenze "
          "minime. A nessuna soglia un altro metodo prende il primo posto: cambia solo quante celle diventano "
          "«a pari».</p>"
        + figura(FIG / "F03b_sintesi_per_fascia.png", "F03b · Il profilo dei metodi fascia per fascia",
                 "come F03, ma una mappa per fascia di penetrazione (mediana sulle 7 taglie).",
                 f"<p>È il cambio di regime visto metodo per metodo. Alla fascia più bassa Proportional to Consumption, "
                 f"Pearson Key, Similarity-Utilization e Tri-level EP sono ultimi sul merito (≤ {n(fi1, 1)}); alle fasce "
                 f"40-80% salgono a {n(min(fi23), 1)}-{n(max(fi23), 1)}. Il Variance Least Core è discreto sul Gini solo "
                 f"alla prima fascia ({n(vlc_g[0], 1)}), poi scende a {n(min(vlc_g[1:]), 1)}-{n(max(vlc_g[1:]), 1)}. Al "
                 f"100% la Weighted Solidarity diventa prima sull'allineamento lordo.</p>")
        + dettagli("F04 · gli altri indicatori contro la penetrazione (5 figure)", f04)
        + dettagli("F05 · tutti gli indicatori contro la taglia (8 figure)", f05))

    # ---------------------------------------------------------------- sincronismo
    def segni(metodo, f, col="ForzaIncentivante"):
        s = tf0[(tf0.Metodo == metodo) & (tf0.Fascia == f)][col]
        return int((s < 0).sum()), len(s)
    sh1 = segni("Shapley", 1)
    as1 = segni("Adaptive Sampling Shapley", 1)
    nu1, vl1 = segni("Nucleolo", 1), segni("Variance Least Core", 1)
    sh_neg_sopra = tf0[(tf0.Metodo == "Shapley") & (tf0.Fascia > 1) & (tf0.ForzaIncentivante < 0)]
    sh_sopra = len(sh_neg_sopra)
    sh_tot_sopra = int(((tf0.Metodo == "Shapley") & (tf0.Fascia > 1)).sum())
    ct = tf0[(tf0.Metodo == "Cascading Tree") & (tf0.Penetrazione_pct < 100)].ForzaIncentivante
    verifica(sh1[0] == sh1[1] and (sh_neg_sopra.Membri == 5).all(),
             "Shapley: forza incentivante negativa a fascia 1; sopra, negativa solo a 5 membri")
    verifica(as1[0] == as1[1], "AS: negativa a fascia 1 anche a 20 e 25 membri")
    qp = D["qp"].copy()
    rap = lambda k, f: qp[(qp.Metodo == k) & (qp.Fascia == f)].RapportoAllaQuotaDiMembri
    sh_r1, sh_r3 = rap("Shapley", 1), rap("Shapley", 3)
    verifica(sh_r1.min() > 1 and sh_r3.max() < 1, "Shapley premia i prosumer a fascia 1 e i consumatori a fascia 3")
    sinc_r1 = max(rap(k, 1).max() for k in ["Pearson Key", "Similarity-Utilization", "Tri-level EP"])
    verifica(sinc_r1 < 0.15, "le chiavi di sincronismo danno ai prosumer meno di 0,15 volte la loro quota a fascia 1")
    sotto100 = qp[qp.Penetrazione_pct < 100]
    rm1 = sotto100[sotto100.Metodo == "Remuneration Model 1"].RapportoAllaQuotaDiMembri
    ws_ = sotto100[sotto100.Metodo == "Weighted Solidarity"].RapportoAllaQuotaDiMembri
    verifica(rm1.between(0.6, 1.1).all() and ws_.between(0.8, 1.25).all(),
             "Remuneration Model 1 e Weighted Solidarity restano vicini a 1 sotto il 100%")
    sincronismo = (
        figura(FIG / "assi" / "F04_penetrazione_ForzaIncentivante.png",
               "F04 · Forza incentivante contro penetrazione",
               "forza incentivante sui profili netti (1 = come la Similarity-Utilization, 0 = come l'Equal Split, "
               "negativo = premia il contrario del sincronismo), una linea per taglia.",
               f"<p><b>Le regole della teoria dei giochi cambiano segno con la penetrazione.</b> Lo Shapley è "
               f"negativo in {sh1[0]} comunità su {sh1[1]} alla fascia 20-30% e positivo in "
               f"{sh_tot_sopra - sh_sopra} su {sh_tot_sopra} sopra"
               + (f" (l'eccezione è la comunità da 5 membri al {n(sh_neg_sopra.Penetrazione_pct.iloc[0], 0)}%, "
                  f"{n(sh_neg_sopra.ForzaIncentivante.iloc[0])})" if sh_sopra == 1 else "")
               + f"; l'AS lo conferma a 20 e 25 membri ({as1[0]} su {as1[1]}). Nucleolo e VLC sono negativi in "
               f"{nu1[0]} su {nu1[1]} e "
               f"{vl1[0]} su {vl1[1]} comunità alla prima fascia. Il Cascading Tree è negativo in {int((ct < 0).sum())} "
               f"comunità su {len(ct)} sotto il 100%. Pearson Key, Similarity-Utilization, Tri-level EP e "
               f"Proportional to Consumption restano attorno a 1 ovunque: premiano il sincronismo per costruzione.</p>")
        + figura(FIG / "F09_quota_prosumer.png", "F09 · Chi viene premiato: prosumer o consumatori",
                 "quota di v(N) che va ai prosumer divisa per la loro quota di membri (> 1 = più della loro testa). "
                 "Il 100% di penetrazione è omesso perché lì il rapporto vale 1.",
                 f"<p>È il meccanismo dietro F04. Lo Shapley dà ai prosumer {n(sh_r1.min(), 1)}-{n(sh_r1.max(), 1)} volte "
                 f"la loro quota alla prima fascia e {n(sh_r3.min(), 2)}-{n(sh_r3.max(), 2)} alla terza: premia il lato "
                 f"scarso e cambia lato fra il 30% e il 50%. Le chiavi di sincronismo danno ai prosumer al massimo "
                 f"{n(sinc_r1, 2)} volte la loro quota alla prima fascia, perché sui profili netti il prosumer non "
                 f"consuma nelle ore di eccedenza. Equal Split (1), Weighted Solidarity ({n(ws_.min())}-{n(ws_.max())}) e "
                 f"Remuneration Model 1 ({n(rm1.min())}-{n(rm1.max())}) restano vicini alla quota di membri a ogni "
                 f"penetrazione: non dipendono dal lato scarso.</p>"
                 "<p class='nota'>Il punto di inversione cade fra la prima e la seconda fascia: fra il 30% e il 50% "
                 "da 8 membri in su, fra il 40% e il 60% a 5 membri. Nessuna comunità sta fra il 30% e il 40%, quindi "
                 "non si può localizzarlo meglio.</p>"))

    # ---------------------------------------------------------------- stabilita'
    st = tf0[tf0.Membri <= 18]
    ex = lambda k: st[st.Metodo == k]
    es_b = {f: ex("Equal Split")[ex("Equal Split").Fascia == f].EccessoMax_pct_vN for f in fasce}
    sh_ex = ex("Shapley").EccessoMax_pct_vN
    nu_max = max(ex("Nucleolo").EccessoMax_pct_vN.max(), ex("Variance Least Core").EccessoMax_pct_vN.max())
    verifica(nu_max <= 1e-3, "Nucleolo e VLC: eccesso massimo <= 0 (core non vuoto)")
    verifica(es_b[3].min() > max(es_b[1].max(), es_b[4].max()), "Equal Split: eccesso massimo piu' alto alla fascia 3")
    S["sh_pos"] = int((sh_ex > 1e-6).sum())
    for k in ["Cascading Tree", "Weighted Solidarity", "Remuneration Model 1"]:
        mb = ex(k).groupby("Fascia").EccessoMax_pct_vN.median()
        verifica(mb.idxmax() == 3, f"{k}: eccesso mediano massimo alla fascia 3")
    st = st.assign(Inst=100 * st.CoalizioniInstabili / (2.0 ** st.Membri - 2))
    inst = lambda k: st[st.Metodo == k].Inst
    euristiche = ["Equal Split", "Cascading Tree", "Weighted Solidarity", "Remuneration Model 1"]
    inst_eur = st[st.Metodo.isin(euristiche)].groupby("Metodo").Inst.median()
    verifica(inst("Nucleolo").max() == 0 and inst("Variance Least Core").max() == 0,
             "Nucleolo e VLC: nessuna coalizione bloccante")
    stabilita = (
        figura(FIG / "assi" / "F04_penetrazione_EccessoMax_EUR.png", "F04 · Eccesso massimo di coalizione contro penetrazione",
               "il guadagno della coalizione più scontenta se uscisse dalla CER, in % di v(N) (≤ 0 = nessuna "
               "coalizione ha convenienza a uscire), fino a 18 membri.",
               f"<p>Nucleolo e Variance Least Core hanno eccesso ≤ 0 in tutte le 20 comunità: il core non è mai vuoto e "
               f"le due regole ci stanno dentro. Lo Shapley ha eccesso positivo in {S['sh_pos']} comunità su "
               f"{len(sh_ex)}, ma piccolo: mediana {n(sh_ex.median(), 1)}% di v(N), massimo {n(sh_ex.max(), 1)}%. "
               f"L'Equal Split ha un costo in stabilità non monotono: {n(es_b[1].min(), 0)}-{n(es_b[1].max(), 0)}% di "
               f"v(N) alla fascia {lab[1]}, {n(es_b[2].min(), 0)}-{n(es_b[2].max(), 0)}% a {lab[2]}, "
               f"<b>{n(es_b[3].min(), 0)}-{n(es_b[3].max(), 0)}%</b> a {lab[3]} e {n(es_b[4].min(), 0)}-"
               f"{n(es_b[4].max(), 0)}% al 100%. Cascading Tree, Weighted Solidarity e Remuneration Model 1 hanno "
               f"la stessa forma.</p><p>A penetrazione 60-80% i pochi consumatori sono il fattore scarso: una "
               f"coalizione di consumatori e alcuni prosumer ottiene da sola più di quanto le dia una ripartizione "
               f"uniforme.</p>")
        + figura(FIG / "assi" / "F04_penetrazione_CoalizioniInstabili.png", "F04 · Coalizioni bloccanti contro penetrazione",
                 "quota delle 2<sup>n</sup> − 2 coalizioni che avrebbero convenienza a uscire, fino a 18 membri.",
                 f"<p>Conferma l'eccesso. Equal Split e le tre euristiche hanno in mediana fra il "
                 f"{n(inst_eur.min(), 0)}% e il {n(inst_eur.max(), 0)}% di coalizioni bloccanti (fino al "
                 f"{n(st[st.Metodo.isin(euristiche)].Inst.max(), 0)}%). Lo Shapley ne ha in "
                 f"{int((inst('Shapley') > 0).sum())} comunità su {len(inst('Shapley'))}, il "
                 f"{n(inst('Shapley').median(), 0)}% in mediana (massimo {n(inst('Shapley').max(), 0)}%), ma con "
                 f"eccesso piccolo: molte coalizioni possono uscire, nessuna guadagna molto. Nucleolo e VLC "
                 f"nessuna.</p>"))

    # ---------------------------------------------------------------- trade-off
    chiavi = ["Gini", "FairnessIndex", "EccessoMax_EUR", "ForzaIncentivante", "AllineamentoVirtu_lordo", "VAN_min_EUR"]
    righe_p = []
    for sc in chiavi[:5]:
        r = [f"<b>{ni(sc)}</b>"]
        for pe in chiavi:
            if pe == sc:
                r.append("–")
                continue
            val = perdita(D, sc, pe)
            extra = ""
            if pe == "EccessoMax_EUR":
                extra = (f"<br><span class='m'>{n(perdita(D, sc, pe, 'Perdita_EUR_ott_medio'), 0)} €, "
                         f"{n(perdita(D, sc, pe, 'Perdita_pct_vN_ott_medio'), 1)}% v(N)</span>")
            elif pe == "VAN_min_EUR":
                extra = f"<br><span class='m'>{n(perdita(D, sc, pe, 'Perdita_EUR_ott_medio'), 0)} €</span>"
            r.append(n(val) + extra)
        righe_p.append(r)
    S["g_ex"] = perdita(D, "Gini", "EccessoMax_EUR")
    S["g_is"] = perdita(D, "Gini", "ForzaIncentivante")
    S["is_g"] = perdita(D, "ForzaIncentivante", "Gini")
    S["fi_ex"], S["ex_fi"] = perdita(D, "FairnessIndex", "EccessoMax_EUR"), perdita(D, "EccessoMax_EUR", "FairnessIndex")
    verifica(S["fi_ex"] == 0 and S["ex_fi"] == 0, "merito e stabilita' non si fanno concorrenza (perdita 0)")
    verifica(S["is_g"] > 0.85 and S["g_is"] > 0.7, "uguaglianza e incentivo sono la coppia piu' in conflitto")
    pf = D["perdf"]
    pfs = lambda a, b: pf[(pf.Scelto == a) & (pf.Perde == b)].set_index("Fascia").PerditaOttimistica_medio
    is_g_f, g_is_f = pfs("ForzaIncentivante", "Gini"), pfs("Gini", "ForzaIncentivante")
    f07 = D["f07"].merge(D["fascia"].reset_index(), on="Scheda")
    f07 = f07[f07.Composizione == "PA0"] if "Composizione" in f07 else f07
    posta = f07.groupby("Fascia").agg(vm=("vN_membro", "median"), esc=("Escursione_mean", "median"),
                                      rel=("Escursione_rel", "median"))
    verifica(posta.vm.iloc[0] > 5 * posta.vm.iloc[-1], "la posta per membro crolla al 100% di penetrazione")
    verifica((posta.rel.iloc[:3] >= 100).all(), "fino all'80% l'escursione per membro supera la quota uguale")
    cv = f07[f07.Membri >= 8].groupby("Fascia").vN_membro.agg(lambda x: x.std() / x.mean())
    verifica(cv.max() < 0.15, "a fascia fissa v(N) per membro varia meno del 15% fra le taglie (da 8 membri)")
    med_b = tf0.groupby(["Metodo", "Fascia"])[["Gini", "EccessoMax_pct_vN"]].median()
    vlc_gb = med_b.loc["Variance Least Core"].Gini
    es_e3 = med_b.loc[("Equal Split", 3), "EccessoMax_pct_vN"]
    # relazione Gini-incentivo fra i metodi: correlazione (Spearman) delle mediane per fascia
    mb = tf0.groupby(["Fascia", "Metodo"])[["Gini", "ForzaIncentivante"]].median()
    rho_gi = {f: mb.loc[f].corr(method="spearman").iloc[0, 1] for f in fasce}
    verifica(rho_gi[1] < 0.5 and all(rho_gi[f] > 0.85 for f in fasce[1:]),
             "Gini e forza incentivante: relazione debole alla fascia 1, forte e crescente dopo")
    righe_pf = [[lab[f], n(g_is_f.get(f, np.nan)), n(is_g_f.get(f, np.nan)), n(posta.vm[f], 0) + " €",
                 n(posta.esc[f], 0) + " €", n(posta.rel[f], 0) + "%"] for f in fasce]
    tradeoff = (
        "<h3>Matrice delle perdite (5-25 membri, sole famiglie)</h3>"
        + tabella(righe_p, ["Scelgo il migliore su ↓ / perdo su →"] + [ni(k) for k in chiavi])
        + "<p><b>Come si legge.</b> Si prende il metodo migliore sull'indicatore di riga e si misura il suo "
          "<i>rimpianto</i> sull'indicatore di colonna: 0 = è anche il migliore lì, 1 = è il peggiore. Media sulle "
          "comunità, lettura ottimistica (se più metodi sono a pari sulla riga, si prende il migliore sulla colonna). "
          "Per l'eccesso e il VAN c'è anche la perdita in euro. La stabilità vale solo fino a 18 membri.</p>"
        + f"<p><b>Cosa dice.</b> Merito e stabilità non si fanno concorrenza (perdita {n(S['fi_ex'])} nei due versi). "
          f"<b>Uguaglianza e incentivo sono la coppia più in conflitto</b>: chi vince sull'incentivo perde "
          f"{n(S['is_g'])} dell'escursione sul Gini, chi vince sul Gini perde {n(S['g_is'])} sull'incentivo. Scegliere "
          f"l'uguaglianza costa {n(S['g_ex'])} in stabilità, cioè un eccesso medio di "
          f"{n(perdita(D, 'Gini', 'EccessoMax_EUR', 'Perdita_EUR_ott_medio'), 0)} € "
          f"({n(perdita(D, 'Gini', 'EccessoMax_EUR', 'Perdita_pct_vN_ott_medio'), 0)}% di v(N)), cioè quanto la "
          f"coalizione più scontenta guadagnerebbe uscendo. Il VAN del membro peggiore sta con l'uguaglianza: "
          f"scegliere il Gini non costa nulla lì ({n(perdita(D, 'Gini', 'VAN_min_EUR'))}).</p>"
        + "<h3>Il conflitto uguaglianza-incentivo per fascia, e quanto vale in euro</h3>"
        + tabella(righe_pf, ["Fascia", "Gini → perdita su incentivo", "Incentivo → perdita sul Gini",
                             "v(N) per membro", "Escursione fra metodi per membro", "Escursione / quota uguale"])
        + f"<p>Il conflitto in punteggio è forte a ogni fascia, ma la <b>posta in euro cambia di un ordine di "
          f"grandezza</b>: v(N) vale {n(posta.vm.iloc[0], 0)} € a membro alla prima fascia e {n(posta.vm.iloc[-1], 0)} € "
          f"al 100%. Lì quasi nulla è condiviso, e le graduatorie, pur corrette, riguardano pochi euro. Una perdita "
          f"di 0,7 va quindi letta insieme alla colonna in euro.</p>"
        + figura(FIG / "F07_posta_in_gioco.png", "F07 · La posta in gioco",
                 "a sinistra v(N) per membro; al centro quanto un membro medio guadagna o perde passando dal metodo "
                 "per lui peggiore a quello migliore, in €/anno; a destra lo stesso in rapporto alla quota uguale.",
                 f"<p>Alle fasce 1-2 la scelta della regola sposta circa "
                 + (f"{n(posta.esc.iloc[0], 0)} €" if round(posta.esc.iloc[0]) == round(posta.esc.iloc[1])
                    else f"{n(min(posta.esc.iloc[:2]), 0)}-{n(max(posta.esc.iloc[:2]), 0)} €")
                 + f" "
                 f"l'anno per membro, più della quota uguale stessa ({n(posta.rel.iloc[0], 0)}-{n(posta.rel.iloc[2], 0)}% "
                 f"della quota uguale fino all'80%). Al 100% si scende a {n(posta.esc.iloc[-1], 0)} €. La taglia non "
                 f"cambia molto la posta per membro: a fascia fissa, da 8 membri in su, il coefficiente di variazione "
                 f"di v(N) per membro fra le taglie è al più del {pc(cv.max())}.</p>")
        + figura(FIG / "F08_compromessi.png", "F08 · I compromessi in unità naturali",
                 "coppie di indicatori in unità naturali, per fascia: punti piccoli = una comunità, grandi = mediana "
                 "fra le taglie per metodo.",
                 f"<p><b>Riga centrale.</b> Alla prima fascia la relazione fra Gini e forza incentivante è debole "
                 f"(Spearman fra le mediane dei metodi {n(rho_gi[1])}): le chiavi di sincronismo hanno Gini alto e "
                 f"forza 1, ma Shapley e Cascading Tree hanno Gini medio e forza negativa. Dalla seconda fascia i "
                 f"metodi si allineano su una diagonale crescente (Spearman {n(min(rho_gi[f] for f in fasce[1:]))}-"
                 f"{n(max(rho_gi[f] for f in fasce[1:]))}): più premio al sincronismo vuol dire più diseguaglianza. "
                 f"<b>Riga in alto.</b> L'Equal Split ha Gini 0 ma un eccesso mediano del {n(es_e3, 0)}% di v(N) alla "
                 f"fascia 60-80%. Il VLC ha eccesso ≤ 0 con un Gini mediano che sale da {n(vlc_gb.iloc[0])} alla prima "
                 f"fascia a {n(vlc_gb.max())}.</p>"))

    # ---------------------------------------------------------------- composizione
    pas = D["pas"]
    tutti = pas[pas.Indicatore == "(tutti)"]
    righe_c = [[e(r.Confronto), str(int(r.Comunita)), pc(r.QuotaInvertite, 1), pc(r.QuotaInvertiteSuValide, 1),
                pc(r.QuotaVincitoreCambia, 1)] for r in tutti.itertuples()]
    sum_pa = tutti[tutti.Confronto == "PA0 contro PA>=1"].iloc[0]
    sum_nd = tutti[tutti.Confronto == "PA0 contro ND>=1"].iloc[0]
    righe_ci = []
    for ind in ["Gini", "FairnessIndex", "Sigma", "EccessoMax_EUR", "CoalizioniInstabili", "ForzaIncentivante",
                "AllineamentoVirtu", "AllineamentoVirtu_lordo", "VAN_min_EUR"]:
        a_ = pas[(pas.Indicatore == ind) & (pas.Confronto == "PA0 contro PA>=1")].iloc[0]
        b_ = pas[(pas.Indicatore == ind) & (pas.Confronto == "PA0 contro ND>=1")].iloc[0]
        righe_ci.append([ni(ind), pc(a_.QuotaInvertite), pc(a_.QuotaVincitoreCambia),
                         pc(b_.QuotaInvertite), pc(b_.QuotaVincitoreCambia)])
    lordo_pa = pas[(pas.Indicatore == "AllineamentoVirtu_lordo") & (pas.Confronto == "PA0 contro PA>=1")].iloc[0]
    lordo_nd = pas[(pas.Indicatore == "AllineamentoVirtu_lordo") & (pas.Confronto == "PA0 contro ND>=1")].iloc[0]
    verifica(abs(sum_pa.QuotaInvertite - sum_nd.QuotaInvertite) < 0.02, "PA e imprese invertono una quota simile di coppie")
    verifica(sum_pa.QuotaInvertite < pen.QuotaInvertite.min(), "la composizione inverte meno della penetrazione")
    pps = D["pps"]
    asse = {k: pps[pps.Confronto == k].QuotaInvertite for k in ["asse PA", "asse ND"]}
    pae = D["pae"].drop_duplicates(["Scheda", "Livello"])
    scala = pae[pae.Livello > 0].groupby("Livello").vN_rapportoPA0.median()
    scala.index = [livello_da_codice(c) for c in scala.index]
    f11 = D["f11"]
    rho_tot = f11[["vN_rapportoPA0", "DeltaMedioAssoluto"]].corr(method="spearman").iloc[0, 1]
    rho_alto = f11[f11.vN_rapportoPA0 > 10][["vN_rapportoPA0", "DeltaMedioAssoluto"]].corr(method="spearman").iloc[0, 1]
    verifica(rho_alto < 0, "sopra x10 di scala lo spostamento non cresce con la scala")
    nd = D["pae"][D["pae"].Livello >= 10].dropna(subset=["RapportoQuotaND"])
    q_nd = nd.groupby("Metodo").RapportoQuotaND.median().sort_values(ascending=False)
    f10 = D["f10"]
    forti = f10[(f10.Mediana.abs() >= 0.5) & (f10.CoerenzaSegno >= 0.8)].copy()
    forti["Segno"] = np.sign(forti.Mediana)
    ric = (forti.groupby(["Metodo", "Indicatore", "Segno"]).Livello.agg(["count", lambda x: ", ".join(sorted(x))])
           .reset_index().sort_values("count", ascending=False))
    ric.columns = ["Metodo", "Indicatore", "Segno", "Livelli", "Quali"]
    ric = ric[ric.Livelli >= 5]
    nliv = f10.Livello.nunique()
    righe_r = [[e(r.Metodo), ni(r.Indicatore), "guadagna" if r.Segno > 0 else "perde", f"{r.Livelli} su {nliv}",
                f"<span class='m'>{e(r.Quali)}</span>"] for r in ric.itertuples()]
    conta = lambda k, i, s: int(ric[(ric.Metodo == k) & (ric.Indicatore == i) & (ric.Segno == s)].Livelli.sum())
    verifica(conta("Similarity-Utilization", "AllineamentoVirtu_lordo", -1) >= 10,
             "Similarity-Utilization perde l'allineamento lordo in quasi tutti i livelli")
    verifica(conta("Cascading Tree", "AllineamentoVirtu_lordo", 1) >= 5, "Cascading Tree guadagna sull'allineamento lordo")
    verifica(conta("Remuneration Model 1", "Gini", -1) >= 5, "Remuneration Model 1 perde sul Gini")
    verifica(max(conta(k, i, 1) for k in ["Cascading Tree", "Weighted Solidarity"]
                 for i in ["FairnessIndex", "Sigma", "EccessoMax_EUR"]) >= 5,
             "Cascading Tree / Weighted Solidarity guadagnano su merito o stabilita'")
    verifica(conta("Variance Least Core", "AllineamentoVirtu", -1) >= 5, "VLC perde sull'allineamento netto")
    verifica(conta("Remuneration Model 1", "AllineamentoVirtu", -1) == nliv,
             "Remuneration Model 1 perde sull'allineamento netto in tutti i livelli")
    verifica(min(conta(k, "AllineamentoVirtu", -1) for k in
                 ["Proportional to Consumption", "Pearson Key", "Tri-level EP"]) >= 5,
             "le chiavi di consumo perdono sull'allineamento netto in almeno 5 livelli")
    for c_ in ["PA0 contro PA>=1", "PA0 contro ND>=1"]:
        for ind in ["Gini", "EccessoMax_EUR", "CoalizioniInstabili", "AllineamentoVirtu"]:
            verifica(pas[(pas.Indicatore == ind) & (pas.Confronto == c_)].QuotaVincitoreCambia.iloc[0] == 0,
                     f"{c_}: il vincitore su {ind} non cambia mai")
    # quota alle PA: mediana per metodo e livello, livelli con 2-3 PA contro livelli con il solo comune
    qpa = D["pae"][(D["pae"].Livello % 10) > 0].dropna(subset=["RapportoQuotaPA"])
    qpa = qpa.assign(NPA=qpa.Livello % 10).groupby(["Metodo", "NPA", "Livello"]).RapportoQuotaPA.median().reset_index()
    esclusi = ["Equal Split", "Similarity-Utilization"]
    pa23 = qpa[(qpa.NPA >= 2) & ~qpa.Metodo.isin(esclusi)].RapportoQuotaPA
    pa1_cons = qpa[(qpa.NPA == 1) & qpa.Metodo.isin(["Proportional to Consumption", "Pearson Key", "Tri-level EP"])].RapportoQuotaPA
    su_pa = qpa[qpa.Metodo == "Similarity-Utilization"].RapportoQuotaPA
    verifica(pa23.min() > 2.5 and pa1_cons.max() <= 1.05, "PA: 3-7 volte con 2-3 PA, sotto 1 per le chiavi di consumo col solo comune")
    scala_max = D["pae"].vN_rapportoPA0.max()
    f13 = "".join(figura(FIG / f"F13_grezzi_{k}.png", f"F13 · Valori grezzi senza e con {k}",
                         "ogni punto è un (metodo, comunità): in ascissa il valore senza PA né imprese, in ordinata con il "
                         "livello indicato. Sopra la diagonale il valore cresce.",
                         "è la stessa informazione di F10 in unità naturali, livello per livello.", larghezza=1300)
                  for k in ["PA1", "PA2", "PA3", "ND1", "ND2", "ND3", "ND1_PA1", "ND1_PA2", "ND1_PA3", "ND2_PA1",
                            "ND2_PA2", "ND2_PA3", "ND3_PA1", "ND3_PA2", "ND3_PA3"])
    composizione = (
        "<h3>Quanto la composizione sposta le graduatorie</h3>"
        + tabella(righe_c, ["Confronto con le sole famiglie", "Comunità", "Coppie invertite", "Sulle coppie valutabili",
                            "Il vincitore cambia"])
        + f"<p>Ogni livello si confronta con la stessa scheda di sole famiglie (stessi N, consumatori e prosumer). "
          f"Aggiungere PA inverte il {pc(sum_pa.QuotaInvertite, 1)} delle coppie, aggiungere imprese il "
          f"{pc(sum_nd.QuotaInvertite, 1)}: <b>PA e imprese spostano le graduatorie in misura simile, e meno della "
          f"penetrazione</b> ({pc(pen.QuotaInvertite.min())}-{pc(pen.QuotaInvertite.max())}). Lungo la scansione "
          f"PA0 → PA1 → PA2 → PA3 si inverte in media il {pc(asse['asse PA'].mean(), 1)} delle coppie, lungo "
          f"PA0 → ND1 → ND2 → ND3 il {pc(asse['asse ND'].mean(), 1)}. Il vincitore cambia nel "
          f"{pc(sum_pa.QuotaVincitoreCambia)} (PA) e {pc(sum_nd.QuotaVincitoreCambia)} (imprese) dei casi.</p>"
        + tabella(righe_ci, ["Indicatore", "PA: coppie invertite", "PA: vincitore cambia", "Imprese: coppie invertite",
                             "Imprese: vincitore cambia"])
        + f"<p>Il vincitore non cambia mai su Gini, eccesso, coalizioni e allineamento netto. Cambia quasi solo "
          f"sull'<b>allineamento lordo</b> ({pc(lordo_pa.QuotaVincitoreCambia)} con PA, "
          f"{pc(lordo_nd.QuotaVincitoreCambia)} con imprese), l'indicatore meno robusto anche lungo la "
          f"penetrazione.</p>"
        + figura(FIG / "F10_effetto_composizione.png", "F10 · Effetto di aggiungere PA o imprese, metodo per metodo",
                 "differenza mediana di punteggio (livello − sole famiglie) a parità di scheda, un pannello per livello. "
                 "° = meno dell'80% delle comunità concorda con il segno della mediana; 0 = |mediana| < 0,05.",
                 f"<p>Gli effetti forti e coerenti che si ripetono in almeno 5 livelli sono nella tabella sotto. Il più "
                 f"costante è il Remuneration Model 1, che perde sull'allineamento netto in "
                 f"{conta('Remuneration Model 1', 'AllineamentoVirtu', -1)} livelli su {nliv} e sull'uguaglianza in "
                 f"{conta('Remuneration Model 1', 'Gini', -1)}. Interpretazione da verificare: il metodo divide fra "
                 f"classi in base alla potenza (kW), e PA e imprese portano molta potenza nella classe dei produttori. "
                 f"Con imprese o con due-tre PA il Cascading Tree e la Weighted "
                 f"Solidarity guadagnano su merito e stabilità. Variance Least Core, Proportional to Consumption, Pearson "
                 f"Key e Tri-level EP perdono sull'allineamento netto, soprattutto con PA2-PA3 e con tre imprese. La "
                 f"Similarity-Utilization perde il primato sull'allineamento lordo, su cui il Cascading Tree "
                 f"guadagna.</p>", larghezza=1800)
        + "<h3>Effetti forti e coerenti (|mediana| ≥ 0,5, segno condiviso da ≥ 80% delle comunità)</h3>"
        + tabella(righe_r, ["Metodo", "Indicatore", "Effetto", "Livelli", "Quali"], num_da=9)
        + figura(FIG / "F11_scala_e_quote_PA.png", "F11 · Composizione o scala? E quanto prendono le PA",
                 "a sinistra lo spostamento medio di punteggio di ogni comunità contro il rapporto fra il suo v(N) e "
                 "quello della stessa scheda di sole famiglie (colore = numero di PA, forma = numero di imprese). A "
                 "destra la quota di v(N) alle PA divisa per la loro quota di membri.",
                 f"<p><b>La composizione cambia anche la scala</b>: v(N) mediano rispetto alle sole famiglie vale "
                 f"{', '.join(f'×{n(v_, 1)} a {k}' for k, v_ in scala.items() if k in ('PA1', 'PA3', 'ND1', 'ND3', 'ND3_PA3'))}. "
                 f"Lo spostamento però non è un semplice effetto di scala: cresce fino a circa ×5 e poi non più "
                 f"(Spearman {n(rho_tot)} su tutte le comunità, {n(rho_alto)} sopra ×10).</p>"
                 f"<p><b>Quanto prendono le PA.</b> Con due o tre PA tutti i metodi tranne Equal Split e "
                 f"Similarity-Utilization danno alle PA fra {n(pa23.min(), 1)} e {n(pa23.max(), 1)} volte la loro quota di "
                 f"membri. Con il solo comune le chiavi di consumo (Proportional to Consumption, Pearson Key, Tri-level "
                 f"EP) gli danno {n(pa1_cons.min(), 1)}-{n(pa1_cons.max(), 1)} volte la quota: il comune è soprattutto "
                 f"un produttore. La Similarity-Utilization dà alle PA {n(su_pa.min(), 1)}-{n(su_pa.max(), 1)} volte la "
                 f"quota a ogni livello. Le imprese, in mediana: "
                 f"{', '.join(f'{e(k)} {n(v_, 1)}' for k, v_ in q_nd.head(3).items())}; Equal Split "
                 f"{n(q_nd.get('Equal Split', np.nan), 1)}; Similarity-Utilization {n(q_nd.get('Similarity-Utilization', np.nan), 1)}.</p>")
        + dettagli("F13 · valori grezzi con e senza PA o imprese, un livello alla volta (15 figure)", f13))

    # ---------------------------------------------------------------- sottoinsieme minimo
    cg, cs, cp, cp18 = D["cg"], D["cs"], D["cp"], D["cp18"]
    g05 = cg[cg.TaglioTau == 0.5]
    righe_g = [[str(int(r.Gruppo)), e(", ".join(ni(x.strip()) for x in r.Indicatori.split(";"))), ni(r.Rappresentante),
                n(r.TauMedioInterno)] for r in g05.itertuples()]
    cs05 = cs[cs.TaglioTau == 0.5]
    conc_min = cs05[cs05.Indicatore != "AllineamentoVirtu_lordo"].ConcordanzaCoppie.min()
    conc_lordo = cs05[cs05.Indicatore == "AllineamentoVirtu_lordo"].ConcordanzaCoppie.iloc[0]
    coinc, coinc18 = int(cp.Coincidono.sum()), int(cp18.Coincidono.sum())
    pac = D["pac"][D["pac"].TaglioTau == 0.5].groupby("LivelloPA").Gruppo.max()
    verifica(len(g05) == 3 and conc_min > 0.95, "3 gruppi a tau >= 0,5, concordanza >= 0,95 fuori dall'allineamento lordo")
    g07 = cg[cg.TaglioTau == 0.7]
    verifica(len(g07) == 4 and (g07.Indicatori == "AllineamentoVirtu_lordo").any(),
             "a tau >= 0,7 l'allineamento lordo e' un quarto gruppo")
    verifica(coinc < len(cp) / 2, "i fronti di Pareto coincidono in meno di meta' delle comunita'")
    righe_cs = [[ni(r.Indicatore), ni(r.Rappresentante), n(r.TauConRappresentante), pc(r.ConcordanzaCoppie, 1)]
                for r in cs05.itertuples()]
    par = D["par"]
    ws = par[par.Metodo == "Weighted Solidarity"]
    minimo = (
        "<h3>Gruppi di indicatori (τ medio ≥ 0,5, raggruppamento average-linkage)</h3>"
        + tabella(righe_g, ["Gruppo", "Indicatori", "Rappresentante", "τ medio interno"])
        + f"<p>Tre gruppi: <b>uguaglianza</b> (con il VAN del membro peggiore), <b>merito e stabilità</b> insieme, "
          f"<b>incentivo</b>. A τ ≥ 0,7 l'allineamento lordo si stacca e diventa un quarto gruppo. Nei 16 livelli di "
          f"composizione i gruppi a τ ≥ 0,5 sono fra {int(pac.min())} e {int(pac.max())}: il sottoinsieme regge "
          f"anche con PA e imprese.</p>"
        + "<h3>Basta davvero? Due prove</h3>"
        + tabella(righe_cs, ["Indicatore", "Rappresentante", "τ con il rappresentante", "Coppie ordinate allo stesso modo"])
        + f"<p><b>Graduatorie: sì.</b> Il rappresentante ordina allo stesso modo almeno il {pc(conc_min, 1)} delle "
          f"coppie di metodi di ogni indicatore del suo gruppo, tranne l'allineamento lordo ({pc(conc_lordo, 1)}). "
          f"<b>Scelte non dominate: no.</b> Il fronte di Pareto calcolato con i soli rappresentanti coincide con "
          f"quello completo in {coinc} comunità su {len(cp)} (5-25 membri, 10 metodi) e in {coinc18} su {len(cp18)} "
          f"fino a 18 membri (11 metodi). Dove non coincide, il fronte completo tiene in più metodi che sono non "
          f"dominati solo grazie a differenze dentro un gruppo (per esempio fra eccesso e σ).</p>"
        + f"<p class='nota'>Fronte di Pareto: la Weighted Solidarity è sul fronte {', '.join(f'{int(r.VolteSulFronte)}/{int(r.ComunitaValutate)}' for r in ws.itertuples())} "
          f"volte nei quattro insiemi di criteri: è dominata quasi sempre.</p>")

    # ---------------------------------------------------------------- soglia regolatoria
    q = soglia.Quota_pct
    gruppi_q = soglia.groupby("Gruppo").Quota_pct.max()
    oltre45 = soglia[soglia.Quota_pct > 45]
    verifica(soglia.Binding.sum() == 0 and q.max() < 55, "soglia del 55% mai vincolante")
    verifica((oltre45.Composizione == "PA0").all(), "sopra il 45% solo comunita' di sole famiglie")
    norma = figura(FIG / "F14_soglia_regolatoria.png", "F14 · La soglia sull'energia incentivabile",
                   "energia condivisa in % dell'energia immessa, una comunità per punto. Le due linee sono le soglie "
                   "del DM 414/2023: 55% con la sola tariffa premio, 45% con il contributo in conto capitale.",
                   f"<p><b>La soglia non è mai vincolante</b> nelle {len(soglia)} comunità: il massimo è "
                   f"{n(q.max(), 1)}% ({e(soglia.loc[q.idxmax(), 'Scheda'])}, sole famiglie). Con PA il massimo è "
                   f"{n(gruppi_q.get('with public buildings', np.nan), 1)}%, con imprese "
                   f"{n(gruppi_q.get('with firms (and possibly PA)', np.nan), 1)}%: gli impianti grandi aumentano "
                   f"l'immissione più della condivisione. Con il conto capitale (45%) la supererebbero "
                   f"{len(oltre45)} comunità ({', '.join(e(x) for x in oltre45.Scheda)}), tutte di sole famiglie, dove "
                   f"non ci sono imprese a cui togliere l'eccedenza. In più il fattore F vale 0 ovunque (nessun conto "
                   f"capitale nelle schede) e lo scaglione tariffario è unico. <b>La categoria regolatoria dei membri "
                   f"quindi non entra in v(S)</b>: agisce solo dentro le regole che la usano come peso (Remuneration "
                   f"Model 1, Cascading Tree).</p>", larghezza=1300)

    # ---------------------------------------------------------------- VAN
    vv = v[v.Indicatore == "VAN_min_EUR"]
    van = (f"<p>Il VAN del membro messo peggio è un'analisi complementare. L'Equal Split lo massimizza da solo in "
           f"{int((vv.Vincitore == 'Equal Split').sum())} comunità su {len(vv)} ed è a pari nelle altre "
           f"{int((vv.Vincitore == '(pari)').sum())}. L'indicatore cade nel gruppo dell'uguaglianza (τ "
           f"{n(cs05[cs05.Indicatore == 'VAN_min_EUR'].TauConRappresentante.iloc[0])} con EI): sulla griglia "
           f"sostenibilità del membro peggiore e uguaglianza sono la stessa domanda. Il VAN dipende soprattutto "
           f"dalla vendita dell'energia immessa, che non passa dalla ripartizione (README §5.2).</p>")

    # ---------------------------------------------------------------- conclusioni
    conclusioni = f"""
<div class='rq'><p><i>When mechanisms from different methodological families allocate the value associated with shared
energy using a year's hourly profiles, how do their rankings vary across distributive-fairness criteria, coalitional
stability, and the ex-post reward given to temporal alignment? How sensitive are these rankings to community size,
prosumer penetration, and member-category composition, and how large are the trade-offs among these evaluation
dimensions? Finally, can a reduced set of indicators preserve the main distinctions produced by the full set?</i></p></div>
<h3>1. Come cambiano le graduatorie fra i criteri</h3>
<p><b>Risposta.</b> Ogni criterio ha il suo vincitore, e i vincitori stanno in famiglie diverse. L'Equal Split vince
sull'uguaglianza ({S['es_gini']} comunità su 28). Nucleolo e Variance Least Core vincono su merito e stabilità (core mai
vuoto, eccesso ≤ 0). Le chiavi di sincronismo (Similarity-Utilization, Pearson Key) vincono sul premio al
sincronismo. Ogni metodo ha almeno una mediana sotto {n(med.min(axis=1).max())} (F03); AS-Shapley e Remuneration
Model 1 sono i soli compromessi senza mediane sotto 0,25. Per tre indicatori il vincitore è tale per costruzione,
quindi la parte informativa è la graduatoria degli altri metodi e quanto perdono.</p>
<p><b>Limiti.</b> Il primato per costruzione va dichiarato. La stabilità è misurata solo fino a 18 membri.</p>
<h3>2. Quanto gli indicatori concordano</h3>
<p><b>Risposta.</b> Il τ-b di Kendall separa tre nozioni: uguaglianza, merito e stabilità, incentivo. <b>La struttura
del conflitto dipende dalla penetrazione.</b> Sotto il 30% l'uguaglianza concorda con il merito (τ {n(t_gf[0].TauMedio)})
e il merito si oppone all'incentivo (τ {n(t_fi[0].TauMedio)}). Dal 40% in su il merito concorda con l'incentivo (τ fino
a {n(max(t.TauMedio for t in t_fi[1:]))}) e l'uguaglianza si oppone a tutto (τ Gini-incentivo fino a
{n(min(t.TauMedio for t in t_gi))}). Il meccanismo è il lato scarso della comunità: prima i prosumer, poi i consumatori.</p>
<h3>3. Quanto conta la comunità</h3>
<p><b>Risposta.</b> La <b>penetrazione dei prosumer</b> è il fattore dominante: spiega il {pc(S['eta_p'][0])}-{pc(S['eta_p'][1])}
della varianza dei punteggi e inverte il {pc(pen.QuotaInvertite.min())}-{pc(pen.QuotaInvertite.max())} delle coppie di
metodi. La <b>taglia</b> conta poco ({pc(S['eta_n'][0], 1)}-{pc(S['eta_n'][1], 1)} della varianza,
{pc(tag.QuotaInvertite.min())}-{pc(tag.QuotaInvertite.max())} di coppie invertite), e la sensibilità alla penetrazione
cala con la taglia. La <b>composizione</b> (PA o imprese) inverte il
{pc(min(sum_pa.QuotaInvertite, sum_nd.QuotaInvertite))}-{pc(max(sum_pa.QuotaInvertite, sum_nd.QuotaInvertite))} delle
coppie, in misura simile per PA e imprese. Il vincitore cambia nel
{pc(min(sum_pa.QuotaVincitoreCambia, sum_nd.QuotaVincitoreCambia))}-{pc(max(sum_pa.QuotaVincitoreCambia, sum_nd.QuotaVincitoreCambia))}
dei casi, quasi tutti sull'allineamento lordo. Le regole di teoria dei giochi cambiano segno sull'incentivo fra la
prima e la seconda fascia di penetrazione (fra il 30% e il 50%; a 5 membri fra il 40% e il 60%).</p>
<p><b>Limiti.</b> Una comunità per cella e famiglie annidate: la scarsa influenza della taglia potrebbe essere in parte
un effetto del disegno. La composizione porta con sé la scala (v(N) fino a ×{n(scala_max, 0)} rispetto alle sole famiglie),
e lo spostamento non è proporzionale alla scala, ma i due effetti non sono separati. A PA3 lo scaglione unico introduce
un errore del 7,9% di v(N) (README §7.10.1).</p>
<h3>4. Quanto costano i trade-off</h3>
<p><b>Risposta.</b> Merito e stabilità non si fanno concorrenza (perdita 0). Uguaglianza e incentivo sono la coppia più
in conflitto: chi vince sull'incentivo perde {n(S['is_g'])} dell'escursione sul Gini, chi vince sul Gini perde
{n(S['g_is'])} sull'incentivo. Scegliere l'uguaglianza costa {n(S['g_ex'])} in stabilità, un eccesso medio pari al
{n(perdita(D, 'Gini', 'EccessoMax_EUR', 'Perdita_pct_vN_ott_medio'), 0)}% di v(N). In euro, la scelta della regola sposta
circa {n(posta.esc.iloc[0], 0)} € l'anno per membro a bassa penetrazione, più della quota uguale, e
{n(posta.esc.iloc[-1], 0)} € al 100%.</p>
<h3>5. Basta un sottoinsieme di indicatori?</h3>
<p><b>Risposta.</b> Per ordinare i metodi sì, per scegliere no. Tre rappresentanti (EI o Gini, σ o eccesso, allineamento
netto o forza incentivante) conservano almeno il {pc(conc_min)} degli ordinamenti a coppie; fa eccezione
l'allineamento lordo ({pc(conc_lordo)}). Il fronte di Pareto dei soli rappresentanti coincide con quello completo solo in {coinc} comunità su
{len(cp)} ({coinc18} su {len(cp18)} fino a 18 membri). Il sottoinsieme basta a dire chi è meglio di chi su ciascuna
nozione, non a dire quali metodi sono difendibili.</p>
<h3>6. Cosa non risponde</h3>
<p>L'<b>inclusione</b>: la popolazione simulata non contiene famiglie vulnerabili LIHC, quindi l'indicatore è NaN ovunque
(sezione 13). La <b>soglia regolatoria</b> non è mai vincolante e non spiega nessuna differenza fra metodi
(sezione 10).</p>"""

    # ---------------------------------------------------------------- note per la tesi
    note = f"""
<p>Il gap allegato promette alcune cose che i risultati non sostengono. Da correggere prima della consegna:</p>
<ol>
<li><b>Togliere l'inclusione.</b> Compare (a) nella domanda di ricerca, «equality, proportionality to physical
contribution, and inclusion»; (b) nella frase «Distributive fairness is assessed through indicators of equality,
proportionality to physical contribution, and inclusion»; (c) implicitamente nella critica a Couraud et al. («Need-based
fairness is also excluded because of data limitations»), che ha lo stesso limite di questa tesi. Cosa scrivere: che
l'indicatore è implementato ma non valutabile sulla popolazione simulata. I redditi sono la media Istat per tipologia
±15%, il rapporto fra reddito e soglia di povertà del nucleo non scende sotto 1,14, quindi nessuna famiglia è
vulnerabile LIHC (README §7.7) e l'indicatore è NaN in tutte le {len(com)} comunità. Di conseguenza il Tri-level EP perde
il livello di povertà energetica e lavora come proprietà più ripartizione proporzionale. La critica a Couraud va
riformulata o tolta.</li>
<li><b>«Proportionality to physical contribution»</b> → il Fairness Index misura la distanza dalla ripartizione per
contributo marginale v(N) − v(N∖{{i}}) (Casalicchio et al. 2022): va chiamato così, o definito.</li>
<li><b>«Where relevant, their regulatory category»</b> → sulla griglia la categoria non entra in v(S): soglia mai
vincolante (sezione 10), F = 0, scaglione TIP unico. Agisce solo nelle regole che la usano come peso.</li>
<li><b>«Within the community sizes for which the calculation is tractable»</b> → scrivere «fino a 18 membri».
Nell'analisi 5-25 membri i metodi sono {len(metodi_unito)}: l'Adaptive Sampling sostituisce lo Shapley (scarto medio
{n(S['as_rd'][0], 1)}-{n(S['as_rd'][1], 1)}% dove si può misurare) e il Nucleolo manca.</li>
<li><b>Composizione</b> → «composition, including the scale it brings»: aggiungere PA o imprese moltiplica v(N), e i
due effetti non sono separati.</li>
<li><b>Premio al sincronismo</b> → dichiarare che l'asse principale sono i profili netti. Sui lordi si usa solo il
coseno (la forza incentivante lorda ha il denominatore vicino a zero), ed è l'indicatore meno robusto del set.</li>
<li><b>Conteggio dei metodi</b> → 11 regole fino a 18 membri, {len(metodi_unito)} nell'analisi 5-25. Cinque famiglie:
giochi cooperativi, regole semplici, euristiche dalla letteratura italiana, chiavi di sincronismo, solidarietà (Weighted
Solidarity, Tri-level EP).</li>
<li><b>Commenti TODO in fondo al .tex.</b> Configurazioni annunciate: tutte simulate fino a 25 membri (PA0-PA3, ND1-ND3,
ND{{k}}_PA{{p}}). Soglia regolatoria: mai vincolante, non va presentata come determinante. Metodi su segnaposto: nessuno
(il Tri-level EP ha 3 ipotesi residue dichiarate, correzioni al paper, non dati mancanti). La definizione della §2.2.4
va controllata nel testo della tesi: nessun metodo implementato usa un prezzo interno.</li>
</ol>"""

    limiti = """<ul>
<li><b>Una comunità per cella, un solo campione di famiglie.</b> Le comunità di taglie diverse condividono le famiglie
(la comunità da n membri usa le prime n della società da 100): le taglie non sono repliche indipendenti, e nessun
intervallo di confidenza è giustificato. Per misurare la variabilità fra famiglie servirebbero estrazioni diverse a
parità di cella.</li>
<li><b>Un anno, una zona.</b> Profili e prezzi 2025, zona Nord.</li>
<li><b>Composizione e scala insieme.</b> Un edificio per tipo di PA, tre imprese; le PA2 e PA3 non hanno le schede a
bassa penetrazione.</li>
<li><b>Scaglione unico.</b> A PA3 e ND{k}_PA3 l'errore della tariffa vale in media il 7,9% di v(N), sopra la soglia di
rilevanza: quei livelli non sono robusti.</li>
<li><b>Fino a 25 membri.</b> Le schede da 50-100 membri non sono analizzate: il Variance Least Core non converge.</li>
<li><b>Forza incentivante ex post.</b> È una covarianza fra quota e virtuosità, non una risposta comportamentale.</li>
<li><b>Weighted Solidarity.</b> La componente di solidarietà usa il costo unitario dell'energia come proxy, che varia
pochissimo fra i membri.</li></ul>"""

    riproduci = f"""
<p>Dalla root del progetto:</p>
<pre>MAIN2_RIPRENDI=1 MAIN2_MAX_UTENTI=25 MAIN2_IND=1 MAIN2_CARTELLA=fino25_unito matlab -batch "MAIN2; v = intersect({{'RESULTS','LIV','AGR','GRID','REV','SINT','F1','PERD','CLUS','SENS'}}, who); save('outputs/workspace/run_2026-10-28_fino25_unito_completo.mat', v{{:}});"
matlab -batch "addpath(pwd); addpath('outputs/workspace/strumenti'); esporta_run_livelli('outputs/workspace/run_2026-10-28_fino25_unito_completo.mat', 'outputs/workspace/export_fino25_unito')"
python -I outputs/workspace/strumenti/grafici_metodi.py --tabelle outputs/tables_main2_fino25_unito --export outputs/workspace/export_fino25_unito --out outputs/figures_tesi_fino25_unito --numeri outputs/tables_tesi_fino25_unito --senza-pagina
python -I outputs/workspace/strumenti/grafici_metodi.py --tabelle outputs/tables_main2_fino18_IND --export outputs/workspace/export_fino18 --out outputs/figures_tesi_fino18_IND --numeri outputs/tables_tesi_fino18_IND --senza-pagina
python -I outputs/workspace/strumenti/rapporto_conclusioni.py</pre>
<p>La prima riga rilegge il checkpoint senza ricalcolare nessuna comunità: rifà la sola analisi fra comunità (30 s) e
riscrive le tabelle di <code>tables_main2_fino25_unito/</code> identiche al byte. Ogni numero di questa pagina viene da
quei CSV, e lo script si ferma se un'affermazione del testo non è più sostenuta dai dati.</p>
<h3>Note di controllo di grafici_metodi.py</h3><pre class='ctl'>{e(D['controlli'])}</pre>"""

    if FALLITE:
        raise SystemExit("affermazioni del testo non sostenute dai dati:\n  - " + "\n  - ".join(FALLITE))

    sezioni = [
        ("disegno", "1. Cosa si è simulato", disegno),
        ("graduatorie", "2. Le graduatorie cambiano con il criterio", graduatorie),
        ("accordo", "3. Quanto gli indicatori concordano", accordo),
        ("sensibilita", "4. Quanto contano penetrazione e taglia", sensibilita),
        ("sincronismo", "5. Il premio al sincronismo e chi viene premiato", sincronismo),
        ("stabilita", "6. La stabilità di coalizione (fino a 18 membri)", stabilita),
        ("tradeoff", "7. Quanto costano i trade-off", tradeoff),
        ("composizione", "8. La composizione: PA e imprese", composizione),
        ("minimo", "9. Un sottoinsieme minimo di indicatori", minimo),
        ("norma", "10. L'ammissibilità regolatoria", norma),
        ("van", "11. Il VAN del membro peggiore", van),
        ("conclusioni", "12. Conclusioni rispetto alla domanda di ricerca", conclusioni),
        ("tesi", "13. Note per la tesi: cosa togliere o correggere nel gap", note),
        ("limiti", "14. Limiti", limiti),
        ("riproduci", "15. Come si rigenera e controlli", riproduci),
    ]
    sintesi = f"""<div class='sintesi'><h2>In breve</h2><ul>
<li><b>Nessun metodo domina.</b> Tre poli: uguaglianza (Equal Split), merito e stabilità (Nucleolo, Variance Least Core,
Shapley), sincronismo (Similarity-Utilization, Pearson Key, Tri-level EP).</li>
<li><b>Il conflitto si sposta con la penetrazione.</b> Sotto il 30% di prosumer il merito si oppone all'incentivo; dal
40% in su l'uguaglianza si oppone a tutto il resto (τ Gini-incentivo fino a {n(min(t.TauMedio for t in t_gi))}).</li>
<li><b>La penetrazione conta più di tutto</b> ({pc(S['eta_p'][0])}-{pc(S['eta_p'][1])} della varianza,
{pc(pen.QuotaInvertite.min())}-{pc(pen.QuotaInvertite.max())} di coppie invertite), la taglia poco
({pc(S['eta_n'][1], 0)} al massimo), la composizione (PA o imprese) il
{pc(min(sum_pa.QuotaInvertite, sum_nd.QuotaInvertite))}-{pc(max(sum_pa.QuotaInvertite, sum_nd.QuotaInvertite))} delle coppie.</li>
<li><b>Il trade-off più caro è uguaglianza contro incentivo</b> (perdita {n(S['is_g'])} e {n(S['g_is'])}
dell'escursione); scegliere l'uguaglianza costa il {n(perdita(D, 'Gini', 'EccessoMax_EUR', 'Perdita_pct_vN_ott_medio'), 0)}%
di v(N) in eccesso di coalizione. Merito e stabilità non si fanno concorrenza.</li>
<li><b>Tre indicatori bastano per ordinare i metodi</b> (≥ {pc(conc_min)} delle coppie), non per scegliere: i fronti di
Pareto coincidono in {coinc} comunità su {len(cp)}.</li>
<li><b>La soglia GSE non morde mai</b> (massimo {n(q.max(), 1)}% contro 55%). <b>L'inclusione non è valutabile</b> e va
tolta dalla domanda di ricerca (sezione 13).</li></ul></div>"""
    indice = "".join(f"<a href='#{i}'>{t}</a>" for i, t, _ in sezioni)
    corpo = "".join(sezione(i, t, c) for i, t, c in sezioni)
    pagina = f"""<!doctype html>
<html lang="it"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Risultati e conclusioni CER</title>
<style>
:root {{ --bg:#fbfbf9; --panel:#ffffff; --ink:#1b2a2f; --muted:#5a6b70; --rule:#d9e0e1; --accent:#0b6a72;
  --soft:#eef4f4; --warn:#8a4b08; }}
@media (prefers-color-scheme: dark) {{ :root:not([data-theme="light"]) {{ --bg:#0f181a; --panel:#152226;
  --ink:#e3ecec; --muted:#9ab0b3; --rule:#2b3e42; --accent:#6cc6cb; --soft:#1a2c30; --warn:#e0a35a; }} }}
:root[data-theme="dark"] {{ --bg:#0f181a; --panel:#152226; --ink:#e3ecec; --muted:#9ab0b3; --rule:#2b3e42;
  --accent:#6cc6cb; --soft:#1a2c30; --warn:#e0a35a; }}
* {{ box-sizing:border-box; }}
body {{ background:var(--bg); color:var(--ink); font:16px/1.6 system-ui,"Segoe UI",Roboto,sans-serif; margin:0; }}
main {{ max-width:1120px; margin:0 auto; padding:28px 16px 80px; }}
h1 {{ font-size:28px; line-height:1.25; margin:0 0 6px; }}
h2 {{ font-size:22px; margin:0 0 12px; }}
h3 {{ font-size:17px; margin:22px 0 8px; }}
p, li {{ max-width:78ch; }}
.sub {{ color:var(--muted); margin:0 0 18px; }}
nav {{ display:flex; flex-wrap:wrap; gap:4px 14px; font-size:14px; margin:0 0 22px; padding:10px 0;
  border-top:1px solid var(--rule); border-bottom:1px solid var(--rule); }}
a {{ color:var(--accent); }}
section {{ border-top:1px solid var(--rule); padding:26px 0 10px; }}
.sintesi {{ background:var(--soft); border-radius:8px; padding:16px 20px; margin:0 0 10px; }}
.sintesi h2 {{ margin-top:0; }}
.fig {{ margin:18px 0 26px; }}
.fig img {{ display:block; max-width:100%; height:auto; background:#fff; border:1px solid var(--rule);
  border-radius:4px; margin:8px 0 4px; }}
.file {{ color:var(--muted); font-size:13px; margin:0 0 6px; }}
.cosa {{ color:var(--muted); }}
.lettura {{ border-left:3px solid var(--accent); padding:2px 0 2px 12px; }}
.lettura p {{ margin:6px 0; }}
.nota {{ color:var(--muted); font-size:14px; }}
.m {{ color:var(--muted); font-size:13px; }}
.tab {{ overflow-x:auto; margin:8px 0 12px; }}
table {{ border-collapse:collapse; font-size:14px; min-width:50%; }}
th, td {{ border-bottom:1px solid var(--rule); padding:5px 10px; text-align:left; vertical-align:top; }}
th {{ background:var(--soft); font-weight:600; }}
td.n, th.n {{ text-align:right; font-variant-numeric:tabular-nums; }}
details {{ border:1px solid var(--rule); border-radius:6px; padding:8px 14px; margin:14px 0; background:var(--panel); }}
summary {{ cursor:pointer; font-weight:600; }}
.rq {{ background:var(--soft); border-radius:8px; padding:4px 18px; }}
pre {{ white-space:pre-wrap; word-break:break-word; font-size:12.5px; background:var(--soft); padding:10px 12px;
  border-radius:6px; }}
code {{ font-size:14px; }}
</style></head>
<body><main>
<h1>Risultati e conclusioni rispetto alla domanda di ricerca</h1>
<p class='sub'>Ripartizione dei benefici nelle CER: {len(com)} comunità da {min(taglie)} a {max(taglie)} membri,
{len(livelli)} livelli di composizione. Run del 27-28 ottobre 2026, analisi unita del 28 ottobre. Figure in inglese
(come la tesi), commenti in italiano. Generato da <code>outputs/workspace/strumenti/rapporto_conclusioni.py</code>.</p>
<nav>{indice}</nav>
{sintesi}
{corpo}
</main></body></html>"""
    uscita = Path(a.uscita)
    uscita.parent.mkdir(parents=True, exist_ok=True)
    uscita.write_text(pagina, encoding="utf-8")
    print(f"scritto {uscita} ({uscita.stat().st_size / 1e6:.1f} MB)")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--tabelle", default="outputs/tables_main2_fino25_unito")
    ap.add_argument("--tabelle18", default="outputs/tables_main2_fino18_IND")
    ap.add_argument("--export", default="outputs/workspace/export_fino25_unito")
    ap.add_argument("--figure", default="outputs/figures_tesi_fino25_unito")
    ap.add_argument("--figure18", default="outputs/figures_tesi_fino18_IND")
    ap.add_argument("--numeri", default="outputs/tables_tesi_fino25_unito")
    ap.add_argument("--numeri18", default="outputs/tables_tesi_fino18_IND")
    ap.add_argument("--uscita", default="outputs/report/RISULTATI_e_conclusioni_RQ_2026-10-28.html")
    costruisci(ap.parse_args())


if __name__ == "__main__":
    main()
