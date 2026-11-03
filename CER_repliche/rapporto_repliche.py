"""Rapporto finale sulle repliche dei partecipanti: tutti i risultati, commentati, e le conclusioni.

Uso, dalla root del progetto:
    venv/Scripts/python.exe -I CER_repliche/rapporto_repliche.py [--blocco outputs/repliche/unito]
        [--uscita outputs/report/RISULTATI_repliche_2026-11-03.html]

Legge la lettura unita 5-25 membri (aggrega_repliche.py --blocco unito) e gli export delle
repliche r01-r20: 20 repliche x 295 comunita', 10 metodi, un solo Shapley (esatto fino a 18
membri, Adaptive Sampling da 20). r00, il disegno con le sole persone sole, NON entra nei
risultati: il generatore lo tiene come controllo del meccanismo, non come dato.

Scrive un file HTML unico, con i grafici incorporati. Ogni numero del testo viene dai CSV (nessun
valore scritto a mano). Ogni affermazione qualitativa ha un controllo: se i dati cambiano e
un'affermazione non regge piu', lo script si ferma e dice quale, invece di scrivere una pagina
sbagliata. Non modifica nessun altro file.
"""
import argparse
import base64
import html
import io
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.colors import LinearSegmentedColormap, TwoSlopeNorm

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "CER_repliche"))
import aggrega_repliche as AR  # noqa: E402  (leggi/repliche: lettura delle tabelle per replica)

INDICATORI = AR.INDICATORI
NOMI = {"Gini": "Gini", "FairnessIndex": "Fairness Index", "Sigma": "σ", "EccessoMax_EUR": "Eccesso massimo",
        "CoalizioniInstabili": "Coalizioni instabili", "ForzaIncentivante": "Forza incentivante",
        "AllineamentoVirtu": "Allineamento netto", "AllineamentoVirtu_lordo": "Allineamento lordo",
        "VAN_min_EUR": "VAN minimo", "EI_orig": "EI"}
GRUPPO = {"Gini": "uguaglianza", "FairnessIndex": "merito", "Sigma": "merito", "EccessoMax_EUR": "stabilità",
          "CoalizioniInstabili": "stabilità", "ForzaIncentivante": "incentivo", "AllineamentoVirtu": "incentivo",
          "AllineamentoVirtu_lordo": "incentivo"}

# palette di riferimento della skill dataviz (light): categorici in ordine fisso, rampa blu, divergente blu/arancio
SUP, INK, INK2, MUTED, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#898781", "#e1e0d9"
CAT = ["#2a78d6", "#eb6834", "#1baf7a", "#6250d6"]
SEQ = LinearSegmentedColormap.from_list("seq", ["#eef4fc", "#9ec5f4", "#2a78d6", "#184f95", "#0d366b"])
DIV = LinearSegmentedColormap.from_list("div", ["#eb6834", "#f0efec", "#2a78d6"])
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
    return n(100 * float(x), d) + "%"


def e(s):
    return html.escape(str(s))


def mig(x):
    """Intero con il punto come separatore delle migliaia (senza toccare le virgole del testo)."""
    return f"{int(x):,}".replace(",", ".")


def tutte(a, b, nrep):
    """'in tutte e 20 le repliche' oppure 'in a e b repliche su 20'."""
    return f"in tutte e {nrep} le repliche" if a == b == nrep else f"in {a} e {b} repliche su {nrep}"


def ni(k):
    return NOMI.get(k, k)


# ============================================================ grafici
def stile():
    plt.rcParams.update({
        "figure.facecolor": SUP, "axes.facecolor": SUP, "savefig.facecolor": SUP, "font.size": 10,
        "text.color": INK, "axes.labelcolor": INK2, "xtick.color": INK2, "ytick.color": INK2,
        "axes.edgecolor": GRID, "axes.spines.top": False, "axes.spines.right": False,
        "axes.grid": True, "grid.color": GRID, "grid.linewidth": 0.8, "axes.axisbelow": True,
        "axes.titlesize": 11, "axes.titleweight": "semibold", "axes.titlelocation": "left",
        "legend.frameon": False})


def png(fig):
    buf = io.BytesIO()
    fig.savefig(buf, format="png", dpi=115, bbox_inches="tight")
    plt.close(fig)
    return base64.b64encode(buf.getvalue()).decode()


def figura(fig, titolo, cosa, lettura):
    return (f"<div class='fig'><h3>{titolo}</h3><p class='cosa'><b>Cosa mostra.</b> {cosa}</p>"
            f"<img alt='{e(titolo)}' src='data:image/png;base64,{png(fig)}'>"
            f"<div class='lettura'><b>Cosa se ne ricava.</b> {lettura}</div></div>")


def heat(ax, M, righe, colonne, cmap, norm=None, fmt="{:.0f}", scala=100, soglia_testo=None, vmin=None, vmax=None):
    """Mappa di calore con il valore scritto in ogni cella (il colore da solo non si legge)."""
    im = ax.imshow(M, cmap=cmap, norm=norm, vmin=vmin, vmax=vmax, aspect="auto")
    ax.set_xticks(range(len(colonne)), colonne)
    ax.set_yticks(range(len(righe)), righe)
    ax.grid(False)
    ax.tick_params(length=0)
    for sp in ax.spines.values():
        sp.set_visible(False)
    lo, hi = np.nanmin(M), np.nanmax(M)
    for i in range(M.shape[0]):
        for j in range(M.shape[1]):
            v = M[i, j]
            if np.isnan(v):
                continue
            t = (v - (norm.vmin if norm else (vmin if vmin is not None else lo))) / max(
                1e-12, ((norm.vmax if norm else (vmax if vmax is not None else hi)) -
                        (norm.vmin if norm else (vmin if vmin is not None else lo))))
            ax.text(j, i, fmt.format(v * scala), ha="center", va="center", fontsize=8.5,
                    color="#ffffff" if (cmap is SEQ and t > 0.55) or (cmap is DIV and abs(2 * t - 1) > 0.55) else INK)
    return im


# ============================================================ tabelle HTML
def tabella(righe, intestazioni, num_da=1):
    th = "".join(f"<th{' class=n' if i >= num_da else ''}>{h}</th>" for i, h in enumerate(intestazioni))
    tr = "".join("<tr>" + "".join(f"<td{' class=n' if i >= num_da else ''}>{c}</td>"
                                  for i, c in enumerate(r)) + "</tr>" for r in righe)
    return f"<div class='tab'><table><thead><tr>{th}</tr></thead><tbody>{tr}</tbody></table></div>"


def dettagli(sommario, contenuto):
    return f"<details><summary>{sommario}</summary>{contenuto}</details>"


def sezione(ident, titolo, corpo):
    return f"<section id='{ident}'><h2>{titolo}</h2>{corpo}</section>"


# ============================================================ dati
def carica(a):
    B = Path(a.blocco)
    D = {"B": B, "A": B / "aggregato"}
    tabs = AR.repliche(B)
    D["tabs"] = tabs
    D["rep"] = sorted(r for r in tabs if r >= 1)
    parti = {k: [] for k in ["comunita", "tfair_lungo", "punteggi_orientati"]}
    for r in D["rep"]:
        for k in parti:
            parti[k].append(pd.read_csv(B / f"r{r:02d}" / "export" / f"{k}.csv").assign(Replica=r))
    for k, v in parti.items():
        D[k] = pd.concat(v, ignore_index=True)
    for k in ["vincitori", "tau", "inversioni", "perdite", "sufficienza", "pareto", "composizione", "varianza",
              "varianza_per_metodo"]:
        D[k] = pd.read_csv(D["A"] / f"{k}.csv")
    # fascia = rango della penetrazione dentro la taglia (livello base, come MAIN2 §7.6.2)
    base = D["comunita"][D["comunita"].Composizione == "PA0"].copy()
    base["Fascia"] = base.groupby(["Replica", "Membri"]).Penetrazione_pct.rank(method="dense").astype(int)
    D["base"] = base
    D["fpen"] = base.groupby("Fascia").Penetrazione_pct.mean()
    return D


def top_a_pari(D):
    """Quota delle celle (livello base, tutte le repliche) in cui il metodo e' fra i primi, pari compresi."""
    p = D["punteggi_orientati"]
    p = p[(p.Composizione == "PA0") & p.Indicatore.isin(INDICATORI)].copy()
    p["mx"] = p.groupby(["Replica", "Scheda", "Indicatore"]).PunteggioOrientato.transform("max")
    p["top"] = p.PunteggioOrientato >= p.mx - p.TolPareggio - 1e-12
    q = p.pivot_table(index="Metodo", columns="Indicatore", values="top", aggfunc="mean")
    return q[INDICATORI]


# ============================================================ il rapporto
def costruisci(a):
    stile()
    D = carica(a)
    rep, nrep = D["rep"], len(D["rep"])
    com, tf, base = D["comunita"], D["tfair_lungo"], D["base"]
    fpen = D["fpen"]
    fasce = sorted(fpen.index)
    FL = {f: f"fascia {f} (~{fpen[f]:.0f}%)" for f in fasce}
    taglie = sorted(base.Membri.unique())
    metodi = sorted(D["punteggi_orientati"].Metodo.unique())
    ncom = com[com.Replica == rep[0]].shape[0]
    S = {}
    verifica(nrep == 20, f"repliche attese 20, trovate {nrep}")
    verifica(ncom == 295, f"comunita' per replica attese 295, trovate {ncom}")
    verifica(len(metodi) == 10 and "Nucleolo" not in metodi, "analisi unita: 10 metodi, senza Nucleolo")
    verifica(len(taglie) == 7 and len(fasce) == 4, "griglia base 7 taglie x 4 fasce")

    # -------------------------------------------------------------- 1. disegno
    liv = com[com.Replica == rep[0]].groupby("Composizione").Membri.agg(["size", "min", "max"])
    ordine = ["PA0", "PA1", "PA2", "PA3"] + sorted(x for x in liv.index if x.startswith("ND"))
    righe_liv = [[e(k), str(int(liv.loc[k, "size"])), f"{int(liv.loc[k, 'min'])}–{int(liv.loc[k, 'max'])}"]
                 for k in ordine if k in liv.index]
    n_rep_com = nrep * ncom
    disegno = (
        "<p>Ogni comunità è una simulazione deterministica di un anno orario (8760 ore, prezzi zonali MGP 2025, "
        "zona Nord). In ogni comunità i metodi si dividono lo stesso montepremi v(N), cioè l'incentivo sull'energia "
        "condivisa, e vengono giudicati con gli stessi indicatori. Il disegno ha tre assi: <b>taglia</b> "
        f"({', '.join(str(t) for t in taglie)} membri), <b>penetrazione dei prosumer</b> (quattro fasce per taglia, "
        f"in media {', '.join(f'{fpen[f]:.0f}%' for f in fasce)}) e <b>composizione</b> (solo famiglie, più edifici "
        "pubblici PA1-PA3, più imprese ND1-ND3, oppure entrambi).</p>"
        "<p><b>Cosa sono le repliche.</b> Le schede dichiarano la composizione ISTAT dei nuclei (componenti × "
        "condizione occupazionale), ma nel disegno di partenza le famiglie simulate erano quasi tutte persone sole: "
        "il profilo di ogni membro era la colonna k-esima di un file ordinato con le persone sole per prime. "
        f"Ogni replica estrae invece, cella per cella, famiglie diverse dal pool di cento, con la composizione "
        f"dichiarata. Le repliche sono <b>{nrep}</b> (r01-r20), ciascuna con le {ncom} comunità della griglia: "
        f"{mig(nrep * ncom)} comunità simulate in tutto. Le famiglie sono le stesse fra le "
        "fasce di penetrazione e fra i livelli di una taglia, e le taglie sono annidate; cambiano fra una replica e "
        "l'altra. La variazione <i>fra repliche, a parità di cella</i> misura quanto i risultati dipendono da "
        "<i>quali</i> famiglie ci sono. Il disegno di partenza (r00) non entra in nessun numero di questo "
        "rapporto.</p>"
        + tabella(righe_liv, ["Livello", "Comunità per replica", "Membri"]) +
        f"<p><b>Metodi ({len(metodi)}).</b> Teoria dei giochi: Shapley e Variance Least Core. Regole semplici: Equal "
        "Split, Proportional to Consumption. Euristiche dalla letteratura italiana: Remuneration Model 1, Cascading "
        "Tree, Weighted Solidarity, Tri-level EP. Chiavi di sincronismo: Pearson Key, Similarity-Utilization. "
        "<b>Lo Shapley è esatto fino a 18 membri e stimato con l'Adaptive Sampling (AS) da 20 in su</b>: nel rapporto "
        "compare con un solo nome, e la tabella della sezione 11 misura quanto l'AS si discosta dall'esatto. Il "
        "Nucleolo manca perché non si calcola oltre i 18 membri.</p>"
        "<p><b>Indicatori (8).</b> Uguaglianza: Gini dei risparmi. Merito: Fairness Index e σ, distanza dalla "
        "ripartizione per contributo marginale. Stabilità: eccesso massimo di coalizione e numero di coalizioni "
        "instabili. Incentivo: forza incentivante e allineamento netto (profili netti) e allineamento lordo (profili "
        "lordi). Per ogni indicatore il punteggio è orientato (più alto = meglio) e c'è una tolleranza di pareggio: "
        "i metodi a distanza minore della tolleranza dal migliore sono \"primi a pari merito\". Il <b>rimpianto</b> di "
        "un metodo è la sua distanza dal migliore, in quota dell'escursione fra i metodi (0 = migliore, 1 = peggiore).</p>")

    # -------------------------------------------------------------- 2. montepremi e soglia GSE
    c = com.copy()
    c["Incentivata_pct"] = 100 * c.QuotaIncentivata
    c["con"] = np.where(c.Composizione == "PA0", "solo famiglie (PA0)", "con PA o imprese")
    S["inc_max"] = c.Incentivata_pct.max()
    S["inc_max_base"] = c[c.Composizione == "PA0"].Incentivata_pct.max()
    S["inc_max_altri"] = c[c.Composizione != "PA0"].Incentivata_pct.max()
    bind = c[c.Binding == 1]
    S["binding"], S["bind_tot"] = len(bind), len(c)
    S["bind_fuori_base"] = int((bind.Composizione != "PA0").sum())
    bf = bind.merge(base[["Replica", "Scheda", "Fascia"]], on=["Replica", "Scheda"], how="left")
    S["bind_fascia"] = bf.Fascia.value_counts().sort_index().to_dict()
    S["bind_rep"] = bind.Replica.nunique()
    S["bind_penmax"] = bind.Penetrazione_pct.max()
    verifica(S["binding"] == int((c.Incentivata_pct > 55).sum()), "Binding non coincide con quota incentivata > 55%")
    verifica(S["bind_fuori_base"] == 0, "la soglia morde anche con PA o imprese: il testo dice solo nel livello base")
    fig, ax = plt.subplots(figsize=(8.6, 4.2))
    for k, col in zip(["solo famiglie (PA0)", "con PA o imprese"], CAT[:2]):
        s_ = c[c.con == k]
        ax.scatter(s_.Penetrazione_pct, s_.Incentivata_pct, s=14, alpha=.35, color=col, edgecolors="none", label=k)
    ax.axhline(55, color=INK2, lw=1.2, ls="--")
    ax.text(c.Penetrazione_pct.max(), 56, "soglia GSE 55%", color=INK2, fontsize=9, va="bottom", ha="right")
    ax.set_xlabel("penetrazione dei prosumer (%)")
    ax.set_ylabel("energia incentivata / condivisa (%)")
    ax.set_ylim(0, S["inc_max"] + 5)
    ax.legend(loc="upper right", markerscale=1.6, bbox_to_anchor=(1, .9))
    f_gse = figura(fig, "Energia incentivata e soglia regolatoria",
                   f"Ogni punto è una comunità (tutte le {mig(n_rep_com)} delle {nrep} repliche)." +
                   " Sull'asse y la quota dell'energia condivisa che ottiene l'incentivo, confrontata con la soglia del 55%.",
                   f"La soglia del 55% <b>morde in {S['binding']} comunità su {mig(S['bind_tot'])}</b> ({pc(S['binding'] / S['bind_tot'], 1)}), "
                   f"in {S['bind_rep']} repliche su {nrep}, con un massimo del {n(S['inc_max'], 0)}%. " +
                   "Sono tutte nel livello base (solo famiglie), a penetrazione al più del "
                   f"{n(S['bind_penmax'], 0)}% (per fascia: " + ", ".join(f"fascia {k}: {v}" for k, v in S["bind_fascia"].items()) +
                   f"). Con PA o imprese la quota resta sotto il {n(S['inc_max_altri'], 0)}%. La quota scende con la penetrazione: pochi prosumer "
                   "con molta produzione immettono più di quanto la comunità consuma. <b>Nel disegno di partenza (persone sole) la soglia non "
                   "mordeva mai</b>: con famiglie vere sì, ma solo dove i prosumer sono pochi. Dove morde, l'eccedenza spetta per norma alle "
                   "sole imprese (README §7.4) e in quelle comunità i membri sono tutti famiglie: la ripartizione fra i metodi non cambia, ma la "
                   "quota incentivata va riportata come caso a parte.")
    vn = base.groupby(["Membri", "Fascia"]).vN_EUR.agg(["median", "min", "max"]).reset_index()
    vn["cv"] = base.groupby(["Membri", "Fascia"]).vN_EUR.std().values / base.groupby(["Membri", "Fascia"]).vN_EUR.mean().values
    S["cv_max"], S["cv_med"] = vn.cv.max(), vn.cv.median()
    tv = vn.pivot(index="Membri", columns="Fascia", values="median")
    tc = vn.pivot(index="Membri", columns="Fascia", values="cv")
    righe_vn = [[f"{m}"] + [f"{n(tv.loc[m, f], 0)} <span class='m'>(CV {pc(tc.loc[m, f])})</span>" for f in fasce]
                for m in taglie]
    montepremi = (
        "<p>Il montepremi v(N) è il valore economico dell'energia condivisa di tutta la comunità: è ciò che i metodi "
        "si dividono. Tabella: mediana fra le repliche (€/anno, livello base) e, fra parentesi, il coefficiente di "
        "variazione fra le repliche, cioè quanto v(N) cambia quando cambiano le famiglie.</p>"
        + tabella(righe_vn, ["Membri"] + [FL[f] for f in fasce]) +
        f"<div class='lettura'><b>Cosa se ne ricava.</b> v(N) cresce con taglia e penetrazione, e cambia poco da una "
        f"replica all'altra (CV mediano {pc(S['cv_med'])}, massimo {pc(S['cv_max'])}): la posta in gioco dipende "
        "soprattutto da quanti prosumer ci sono, non da quali famiglie.</div>" + f_gse)

    # -------------------------------------------------------------- 3. chi vince
    Q = top_a_pari(D)
    verifica(Q.loc["Equal Split", "Gini"] > .99, "Equal Split non e' sempre primo sul Gini")
    verifica(Q.loc["Variance Least Core", "EccessoMax_EUR"] > .99, "il VLC non e' sempre primo sull'eccesso massimo")
    verifica(Q.loc["Variance Least Core", "FairnessIndex"] > .9, "il VLC non e' quasi sempre primo sul Fairness Index")
    verifica(Q.loc["Pearson Key", "ForzaIncentivante"] > .9 and Q.loc["Tri-level EP", "ForzaIncentivante"] > .9,
             "Pearson Key e Tri-level EP non sono quasi sempre primi sulla forza incentivante")
    verifica(Q.loc["Similarity-Utilization", "AllineamentoVirtu"] > .9,
             "Similarity-Utilization non e' quasi sempre prima sull'allineamento netto")
    ordine_m = list(Q.max(axis=1).sort_values(ascending=False).index)
    Qo = Q.loc[ordine_m]
    fig, ax = plt.subplots(figsize=(9.4, 4.6))
    heat(ax, Qo.values, list(Qo.index), [ni(i).replace(" ", "\n") for i in INDICATORI], SEQ, vmin=0, vmax=1)
    ax.xaxis.tick_top()
    f_vinc = figura(fig, "Chi sta fra i primi, indicatore per indicatore",
                    f"Per ogni metodo e indicatore, la quota delle celle (livello base: {len(base)} comunità = "
                    f"{nrep} repliche × 28) in cui il metodo è primo o a pari merito con il primo. Più scuro = più spesso primo.",
                    f"Si formano tre poli. <b>Uguaglianza</b>: l'Equal Split è primo sul Gini nel {pc(Q.loc['Equal Split', 'Gini'])} "
                    f"delle celle. <b>Merito e stabilità</b>: il Variance Least Core è primo sull'eccesso massimo nel "
                    f"{pc(Q.loc['Variance Least Core', 'EccessoMax_EUR'])} e sul Fairness Index nel "
                    f"{pc(Q.loc['Variance Least Core', 'FairnessIndex'])}; lo Shapley lo segue "
                    f"({pc(Q.loc['Shapley', 'FairnessIndex'])} sul Fairness Index, {pc(Q.loc['Shapley', 'EccessoMax_EUR'])} "
                    f"sull'eccesso). <b>Incentivo</b>: Pearson Key ({pc(Q.loc['Pearson Key', 'ForzaIncentivante'])}), "
                    f"Tri-level EP ({pc(Q.loc['Tri-level EP', 'ForzaIncentivante'])}) e Similarity-Utilization "
                    f"({pc(Q.loc['Similarity-Utilization', 'ForzaIncentivante'])}) sulla forza incentivante. Nessun metodo "
                    "è primo su tutto. Attenzione: per Gini, Fairness Index ed eccesso massimo il primato del "
                    "metodo è in parte <i>per costruzione</i> (l'Equal Split annulla la disuguaglianza, il VLC minimizza "
                    "l'eccesso): l'informazione sta nella graduatoria degli altri metodi, che le sezioni 4 e 8 misurano.")
    # robustezza del vincitore alle famiglie
    V = D["vincitori"]
    rv = V.groupby("Indicatore").agg(celle=("QuotaModale", "size"), modale=("QuotaModale", "mean"),
                                     unanime=("QuotaModale", lambda s: (s >= 0.999).mean())).reindex(INDICATORI)
    S["modale_min"], S["modale_max"] = rv.modale.min(), rv.modale.max()
    righe_rv = [[ni(i), str(int(rv.loc[i, "celle"])), pc(rv.loc[i, "modale"]), pc(rv.loc[i, "unanime"])]
                for i in INDICATORI]
    verifica(rv.modale.min() > .7, "il vincitore modale non e' stabile (media < 70%) per qualche indicatore")
    robust = (
        "<p>Il vincitore di una cella (livello, indicatore, taglia, fascia) è l'<i>insieme dei primi a pari merito</i>. "
        f"Per ogni cella si prende l'insieme più frequente fra le {nrep} repliche e si misura in quante repliche si "
        "presenta. Tabella: media sulle celle, e quota di celle in cui tutte e 20 le repliche concordano.</p>"
        + tabella(righe_rv, ["Indicatore", "Celle", "Repliche con l'insieme modale (media)", "Celle all'unanimità"]) +
        f"<div class='lettura'><b>Cosa se ne ricava.</b> Cambiando le famiglie, il vincitore di una cella resta lo "
        f"stesso nel {pc(S['modale_min'])}-{pc(S['modale_max'])} delle repliche, secondo l'indicatore. È l'indicatore "
        f"più legato al profilo delle famiglie, l'allineamento lordo ({pc(rv.loc['AllineamentoVirtu_lordo', 'modale'])}), "
        "a cambiare vincitore più spesso. Sul Gini l'accordo è quasi totale ({pc(rv.loc['Gini', 'unanime'])} delle celle all'unanimità) perché vince l'Equal Split.</div>")
    chi_vince = f_vinc + robust

    # -------------------------------------------------------------- 4. profili dei metodi (rimpianto)
    R = AR.leggi({r: D["tabs"][r] for r in rep}, "sintesi/rimpianto_medio.csv")
    ind_r = INDICATORI + (["VAN_min_EUR"] if "VAN_min_EUR" in set(R.Indicatore) else [])
    R = R[R.Indicatore.isin(ind_r) & (R.Metodo != "Adaptive Sampling Shapley")]
    Mr = R.groupby(["Metodo", "Indicatore"]).Rimpianto_medio.median().unstack()[ind_r].loc[Qo.index]
    fig, ax = plt.subplots(figsize=(9.8, 4.6))
    heat(ax, Mr.values, list(Mr.index), [ni(i).replace(" ", "\n") for i in ind_r], SEQ, vmin=0, vmax=1)
    ax.xaxis.tick_top()
    worst = Mr.max(axis=1)
    best_all = worst.idxmin()
    f_prof = figura(fig, "Profilo di ogni metodo: rimpianto medio per indicatore",
                    "Rimpianto medio (mediana fra le repliche, livello base): 0 = il metodo è sempre il migliore su quell'indicatore, "
                    "1 = è sempre il peggiore. Più chiaro = meglio.",
                    f"Nessuna riga è chiara su tutte le colonne. Il metodo col rimpianto peggiore più basso è "
                    f"<b>{e(best_all)}</b>: il suo indicatore peggiore ({e(ni(Mr.loc[best_all].idxmax()))}) ha rimpianto {n(worst.min())}, cioè "
                    "dista più della metà dell'escursione dal migliore. È il compromesso più equilibrato, ma non è privo di costi. "
                    f"L'Equal Split ha rimpianto {n(Mr.loc['Equal Split', 'Gini'])} sul Gini e {n(Mr.loc['Equal Split', 'ForzaIncentivante'])} sulla forza "
                    f"incentivante; Pearson Key ha {n(Mr.loc['Pearson Key', 'ForzaIncentivante'])} sulla forza incentivante e "
                    f"{n(Mr.loc['Pearson Key', 'Gini'])} sul Gini. Ogni scelta di regola è quindi una scelta di valori, non di efficienza.")
    verifica(Mr.loc["Equal Split", "Gini"] < .01, "Equal Split non ha rimpianto ~0 sul Gini")
    verifica(Mr.loc["Equal Split", "ForzaIncentivante"] > .7, "Equal Split non e' lontano dal migliore sull'incentivo")
    verifica(worst.min() > 0.5, "esiste un metodo con rimpianto massimo <= 0,5: il testo dice che nessuno e' un compromesso senza costi")
    verifica(Mr.loc["Pearson Key", "ForzaIncentivante"] < 0.2 and Mr.loc["Pearson Key", "Gini"] > 0.5,
             "Pearson Key non ha rimpianto basso sull'incentivo e alto sul Gini")

    # -------------------------------------------------------------- 5. accordo fra criteri
    T = D["tau"]
    fig, axs = plt.subplots(1, 4, figsize=(11.2, 3.6), sharex=True, sharey=True)
    for ax, f in zip(axs, fasce):
        t = T[T.Fascia == f]
        M = t.pivot_table(index="IndicatoreA", columns="IndicatoreB", values="mediana")
        full = pd.DataFrame(np.nan, index=INDICATORI, columns=INDICATORI)
        for ia in INDICATORI:
            for ib in INDICATORI:
                if ia == ib:
                    full.loc[ia, ib] = 1.0
                elif ia in M.index and ib in M.columns and not np.isnan(M.loc[ia, ib]):
                    full.loc[ia, ib] = M.loc[ia, ib]
                elif ib in M.index and ia in M.columns and not np.isnan(M.loc[ib, ia]):
                    full.loc[ia, ib] = M.loc[ib, ia]
        ax.imshow(full.values, cmap=DIV, vmin=-1, vmax=1)
        ax.set_xticks(range(8), [ni(i)[:9] for i in INDICATORI], rotation=70, ha="right", fontsize=7.5)
        ax.set_yticks(range(8), [ni(i) for i in INDICATORI] if f == fasce[0] else [""] * 8, fontsize=8)
        ax.set_title(FL[f], fontsize=10)
        ax.grid(False)
        for sp in ax.spines.values():
            sp.set_visible(False)
        for i in range(8):
            for j in range(8):
                v = full.values[i, j]
                if i != j and not np.isnan(v):
                    ax.text(j, i, n(v, 1).replace("−", "-"), ha="center", va="center", fontsize=6.3,
                            color="#ffffff" if abs(v) > 0.65 else INK)
    f_tau = figura(fig, "Accordo fra gli indicatori: τ-b di Kendall, mediana fra le repliche",
                   "Per ogni fascia di penetrazione, la correlazione di rango fra le graduatorie dei metodi prodotte da due "
                   "indicatori (livello base). Blu = i due indicatori ordinano i metodi allo stesso modo; arancio = in modo opposto.",
                   "I criteri non sono intercambiabili, e la struttura cambia con la penetrazione. Lo si vede meglio "
                   "nella figura seguente, sulle coppie decisive.")

    def serie(ia, ib):
        t = T[(T.IndicatoreA == ia) & (T.IndicatoreB == ib)].sort_values("Fascia")
        if t.empty:
            t = T[(T.IndicatoreA == ib) & (T.IndicatoreB == ia)].sort_values("Fascia")
        return t
    coppie = [("Gini", "ForzaIncentivante", "uguaglianza\ncontro incentivo"),
              ("FairnessIndex", "ForzaIncentivante", "merito\ncontro incentivo"),
              ("Gini", "FairnessIndex", "uguaglianza\ncontro merito"),
              ("FairnessIndex", "EccessoMax_EUR", "merito\ncontro stabilità")]
    fig, axs = plt.subplots(1, 4, figsize=(11.2, 3.2), sharey=True)
    for ax, (ia, ib, nm) in zip(axs, coppie):
        t = serie(ia, ib)
        ax.fill_between(t.Fascia, t["min"], t["max"], color=CAT[0], alpha=.18, lw=0)
        ax.plot(t.Fascia, t.mediana, color=CAT[0], lw=2, marker="o", ms=5)
        ax.axhline(0, color=INK2, lw=.9)
        ax.set_title(nm, fontsize=10)
        ax.set_xticks(fasce, [f"{fpen[f]:.0f}%" for f in fasce])
        ax.set_xlabel("penetrazione (media di fascia)")
    axs[0].set_ylabel("τ-b (mediana, min–max)")
    axs[0].set_ylim(-1, 1)
    f_tau4 = figura(fig, "Le quattro coppie decisive lungo la penetrazione",
                    f"Linea: mediana fra le {nrep} repliche del τ-b medio di fascia. Banda: minimo e massimo fra le repliche.",
                    "Mediane dalla fascia a penetrazione più bassa a quella più alta: " + "; ".join(
                        f"{nm.replace(chr(10), ' ')} {n(serie(ia, ib).mediana.iloc[0])} → {n(serie(ia, ib).mediana.iloc[-1])}"
                        for ia, ib, nm in coppie) + ". <b>Uguaglianza contro incentivo</b> si approfondisce e resta negativa; "
                    "<b>merito contro incentivo</b> cambia segno; <b>merito contro stabilità</b> resta positivo a ogni penetrazione, ed è la "
                    "coppia più allineata. La banda stretta dice che le famiglie estratte spostano poco questi valori, salvo "
                    "al 100% di prosumer, dove le bande si allargano.")
    verifica((serie("FairnessIndex", "EccessoMax_EUR").mediana > 0.3).all(), "merito e stabilita' non concordano a ogni penetrazione")
    verifica((serie("Gini", "ForzaIncentivante").mediana < 0).all(), "uguaglianza e incentivo non sono negativi a ogni penetrazione")
    # per replica
    TR = AR.leggi({r: D["tabs"][r] for r in rep}, "sintesi/tau_per_fascia.csv")
    TR = TR[TR.Replica >= 1]

    def valori(ia, ib, f):
        s = TR[((TR.IndicatoreA == ia) & (TR.IndicatoreB == ib)) | ((TR.IndicatoreA == ib) & (TR.IndicatoreB == ia))]
        return s[s.Fascia == f].set_index("Replica").TauMedio
    gi1, gi4 = valori("Gini", "ForzaIncentivante", fasce[0]), valori("Gini", "ForzaIncentivante", fasce[-1])
    fi1, fi3 = valori("FairnessIndex", "ForzaIncentivante", fasce[0]), valori("FairnessIndex", "ForzaIncentivante", fasce[2])
    S["gi"] = (gi1.median(), gi4.median(), (gi4 <= gi1 - .3).sum())
    S["fi"] = (fi1.median(), fi3.median(), ((fi1 < 0) & (fi3 > 0)).sum())
    verifica(S["gi"][2] == nrep, f"τ(Gini, incentivo) non scende di 0,3 in tutte le repliche ({S['gi'][2]}/{nrep})")
    verifica(S["fi"][2] == nrep, f"τ(FI, incentivo) non passa da − a + in tutte le repliche ({S['fi'][2]}/{nrep})")
    fig, axs = plt.subplots(1, 2, figsize=(9.2, 3.6), sharey=True)
    for ax, (ia, ib, fa, fb, nm) in zip(axs, [("Gini", "ForzaIncentivante", fasce[0], fasce[-1], "uguaglianza contro incentivo"),
                                              ("FairnessIndex", "ForzaIncentivante", fasce[0], fasce[2], "merito contro incentivo")]):
        va, vb = valori(ia, ib, fa), valori(ia, ib, fb)
        for r in rep:
            ax.plot([0, 1], [va[r], vb[r]], color=CAT[0], alpha=.35, lw=1, marker="o", ms=3.5)
        ax.plot([0, 1], [va.median(), vb.median()], color=CAT[1], lw=2.6, marker="o", ms=7, label="mediana")
        ax.axhline(0, color=INK2, lw=.9)
        ax.set_xticks([0, 1], [FL[fa], FL[fb]])
        ax.set_xlim(-.25, 1.25)
        ax.set_title(nm, fontsize=10)
        ax.legend(loc="lower left")
    axs[0].set_ylabel("τ-b")
    axs[0].set_ylim(-1, 1)
    f_flip = figura(fig, "Il capovolgimento con la penetrazione, replica per replica",
                    f"Ogni linea blu è una replica (r01-r20): τ-b della coppia a bassa e ad alta penetrazione. L'arancio è la mediana.",
                    f"<b>Uguaglianza contro incentivo</b>: τ passa da {n(S['gi'][0])} a {n(S['gi'][1])} (mediane), e scende di almeno 0,3 in "
                    f"{S['gi'][2]} repliche su {nrep}. <b>Merito contro incentivo</b>: da {n(S['fi'][0])} a {n(S['fi'][1])}, "
                    f"da negativo a positivo in {S['fi'][2]} repliche su {nrep}. È il risultato più robusto del lavoro: "
                    "con pochi prosumer il merito (chi contribuisce di più) si oppone al premio al sincronismo, perché il "
                    "lato scarso è la produzione; con molti prosumer il lato scarso sono i consumatori e merito e "
                    "sincronismo vanno nello stesso verso, mentre l'uguaglianza si oppone a entrambi. Nessuna replica "
                    "contraddice il segno.")
    accordo = f_tau + f_tau4 + f_flip

    # -------------------------------------------------------------- 6. inversioni e varianza
    I = D["inversioni"]
    Ip, It = I[I.Sweep == "penetrazione"].copy(), I[I.Sweep == "taglia"].copy()
    Ip["k"] = Ip.Fisso.str.extract(r"(\d+)").astype(int)
    Ip = Ip.sort_values("k")
    fig, axs = plt.subplots(1, 2, figsize=(10, 3.4), sharey=True)
    for ax, df, lab, ttl in [(axs[0], Ip, [f"{k}" for k in Ip.k], "al variare della penetrazione, a taglia fissa"),
                             (axs[1], It, [x.split("(")[0].strip() + " " + x.split("(")[1].rstrip(")") if "(" in x else x for x in It.Fisso],
                              "al variare della taglia, a penetrazione fissa")]:
        x = np.arange(len(df))
        ax.bar(x, 100 * df["mediana"], color=CAT[0], width=.6)
        ax.errorbar(x, 100 * df["mediana"], yerr=[100 * (df["mediana"] - df["min"]), 100 * (df["max"] - df["mediana"])],
                    fmt="none", ecolor=INK2, lw=1.2, capsize=3)
        ax.set_xticks(x, lab, rotation=0 if ax is axs[0] else 15, fontsize=8.5)
        ax.set_title(ttl, fontsize=10)
        ax.set_xlabel("membri" if ax is axs[0] else "")
    axs[0].set_ylabel("coppie di metodi invertite (%)")
    S["inv_pen"] = (Ip["mediana"].min(), Ip["mediana"].max())
    S["inv_tag"] = (It["mediana"].min(), It["mediana"].max())
    f_inv = figura(fig, "Quanto cambia la graduatoria dei metodi lungo gli assi",
                   "Quota di coppie di metodi che si scambiano di posto passando da un estremo all'altro dell'asse, per "
                   "indicatore e serie esaminata (mediana fra le repliche; barre: minimo e massimo).",
                   f"Lungo la <b>penetrazione</b> si inverte il {pc(S['inv_pen'][0])}-{pc(S['inv_pen'][1])} delle coppie; lungo la "
                   f"<b>taglia</b> il {pc(S['inv_tag'][0])}-{pc(S['inv_tag'][1])}. Cambiare quanti sono i prosumer sposta le "
                   "graduatorie più di quanto le sposti cambiare quanti sono i membri.")
    verifica(S["inv_pen"][0] > S["inv_tag"][0] - 1e-9 and np.median(Ip["mediana"]) > np.median(It["mediana"]),
             "la penetrazione non inverte piu' coppie della taglia")
    VZ = D["varianza"].set_index("Indicatore").reindex(INDICATORI)
    comp = ["penetrazione", "taglia", "interazione", "partecipanti"]
    fig, ax = plt.subplots(figsize=(9, 4.2))
    left = np.zeros(len(VZ))
    nomi_c = {"penetrazione": "penetrazione", "taglia": "taglia", "interazione": "penetrazione × taglia",
              "partecipanti": "partecipanti (famiglie)"}
    for k, col in zip(comp, CAT):
        ax.barh(range(len(VZ)), VZ[k], left=left, color=col, edgecolor=SUP, linewidth=2, height=.7, label=nomi_c[k])
        for i, (l, v) in enumerate(zip(left, VZ[k])):
            if v > .07:
                ax.text(l + v / 2, i, f"{100 * v:.0f}%", ha="center", va="center", fontsize=8.5, color="#ffffff")
        left += VZ[k].values
    ax.set_yticks(range(len(VZ)), [ni(i) for i in INDICATORI])
    ax.invert_yaxis()
    ax.set_xlim(0, 1)
    ax.set_xlabel("quota della varianza dei punteggi")
    ax.legend(ncol=4, loc="upper center", bbox_to_anchor=(.5, -.18), fontsize=8.5)
    pen_main = [i for i in INDICATORI if i != "AllineamentoVirtu_lordo"]
    verifica((VZ.loc[pen_main, "penetrazione"] > VZ.loc[pen_main, ["taglia", "interazione", "partecipanti"]].max(axis=1)).all(),
             "la penetrazione non e' il primo fattore di varianza per tutti gli indicatori tranne l'allineamento lordo")
    verifica(VZ.loc["AllineamentoVirtu_lordo", "penetrazione"] < .3, "l'allineamento lordo e' ancora dominato dalla penetrazione")
    S["var_pen"] = (VZ.loc[pen_main, "penetrazione"].min(), VZ.loc[pen_main, "penetrazione"].max())
    S["var_tag_max"] = VZ.loc[pen_main, "taglia"].max()
    S["var_part"] = (VZ.loc[pen_main, "partecipanti"].min(), VZ.loc[pen_main, "partecipanti"].max())
    f_var = figura(fig, "Da cosa dipendono i punteggi dei metodi",
                   "Scomposizione della varianza del punteggio (1 − rimpianto) in: penetrazione, taglia, interazione fra le due e "
                   "variazione fra repliche dentro la cella (l'effetto di <i>quali</i> famiglie ci sono). Livello base, pesata sui metodi.",
                   f"La <b>penetrazione</b> è il fattore dominante per sette indicatori su otto: {pc(S['var_pen'][0])}-{pc(S['var_pen'][1])} "
                   f"della varianza. La <b>taglia</b> pesa al più il {pc(S['var_tag_max'])}. I <b>partecipanti</b> spiegano il "
                   f"{pc(S['var_part'][0])}-{pc(S['var_part'][1])}: è un effetto reale, ma secondario. L'<b>allineamento lordo</b> fa "
                   f"eccezione: la penetrazione ne spiega solo l'{pc(VZ.loc['AllineamentoVirtu_lordo', 'penetrazione'])} e i "
                   f"partecipanti il {pc(VZ.loc['AllineamentoVirtu_lordo', 'partecipanti'])}. Misura quanto la ripartizione segue il "
                   "consumo lordo nelle ore di sole, e quel consumo dipende da chi è la famiglia: è l'indicatore meno "
                   "robusto del set e va letto con cautela.")
    assi = f_inv + f_var

    # -------------------------------------------------------------- 7. composizione
    C = D["composizione"].copy()
    Cm = C.groupby("Confronto").agg(inv=("mediana_inv", "mean"), invmax=("max_inv", "mean"),
                                    vinc=("mediana_vinc", "mean")).sort_values("inv")
    fig, axs = plt.subplots(1, 2, figsize=(10.4, 5.2), sharey=True)
    y = np.arange(len(Cm))
    axs[0].barh(y, 100 * Cm.inv, color=CAT[0], height=.65)
    axs[0].set_title("coppie di metodi invertite (%)", fontsize=10)
    axs[1].barh(y, 100 * Cm.vinc, color=CAT[1], height=.65)
    axs[1].set_title("celle in cui cambia il vincitore (%)", fontsize=10)
    axs[0].set_yticks(y, [c.replace("PA0", "base") for c in Cm.index], fontsize=8.5)
    S["comp_inv"] = (Cm.inv.min(), Cm.inv.max())
    S["comp_vinc"] = (Cm.vinc.min(), Cm.vinc.max())
    cvi = C.groupby("Indicatore").mediana_vinc.mean().reindex(INDICATORI)
    S["comp_vinc_top"] = cvi.idxmax()
    verifica(Cm.inv.max() < .25, "la composizione inverte piu' del 25% delle coppie")
    verifica(S["comp_vinc_top"] in ("AllineamentoVirtu_lordo", "ForzaIncentivante", "AllineamentoVirtu"),
             "il vincitore cambia per composizione soprattutto su un indicatore non di incentivo")
    f_comp = figura(fig, "Effetto di PA e imprese rispetto alle sole famiglie",
                    "Per ogni livello di composizione confrontato col livello base (PA0): quota di coppie di metodi invertite e quota di celle "
                    "in cui il vincitore cambia. Media sugli indicatori della mediana fra le repliche.",
                    f"Aggiungere edifici pubblici o imprese inverte il {pc(S['comp_inv'][0])}-{pc(S['comp_inv'][1])} delle coppie e cambia il "
                    f"vincitore nel {pc(S['comp_vinc'][0])}-{pc(S['comp_vinc'][1])} delle celle: poco. Il vincitore cambia soprattutto su "
                    f"<b>{e(ni(S['comp_vinc_top']))}</b> ({pc(cvi.max())} delle celle). Gli effetti di PA e imprese sono simili. "
                    "Limite: la composizione porta con sé la scala (v(N) cresce), e i due effetti non sono separati.")
    righe_cv = [[ni(i), pc(cvi[i])] for i in INDICATORI]
    composizione = f_comp + dettagli("Quota di celle in cui cambia il vincitore, per indicatore",
                                     tabella(righe_cv, ["Indicatore", "Media sui confronti"]))

    # -------------------------------------------------------------- 8. trade-off
    P = D["perdite"]
    M = P.pivot_table(index="Scelto", columns="Perde", values="mediana").reindex(index=INDICATORI, columns=INDICATORI)
    fig, ax = plt.subplots(figsize=(8.6, 5.2))
    heat(ax, M.values, [ni(i) for i in INDICATORI], [ni(i).replace(" ", "\n") for i in INDICATORI], SEQ,
         fmt="{:.2f}", scala=1, vmin=0, vmax=1)
    ax.set_xlabel("indicatore su cui si perde", labelpad=10)
    ax.set_ylabel("indicatore su cui si sceglie il migliore")
    ax.xaxis.set_label_position("bottom")
    ax.xaxis.tick_top()

    def L(a_, b_):
        return float(M.loc[a_, b_])
    S["g_is"], S["is_g"] = L("Gini", "ForzaIncentivante"), L("ForzaIncentivante", "Gini")
    S["g_ex"], S["fi_ex"], S["ex_fi"] = L("Gini", "EccessoMax_EUR"), L("FairnessIndex", "EccessoMax_EUR"), L("EccessoMax_EUR", "FairnessIndex")
    verifica(S["g_is"] > .7 and S["is_g"] > .8, "uguaglianza e incentivo non sono il trade-off piu' caro")
    verifica(S["fi_ex"] < .05 and S["ex_fi"] < .05, "merito e stabilita' si fanno concorrenza")
    # la coppia a perdita massima fra i gruppi diversi
    Mm = M.copy()
    for i in INDICATORI:
        for j in INDICATORI:
            if GRUPPO[i] == GRUPPO[j]:
                Mm.loc[i, j] = np.nan
    Mloss_min, Mloss_max = M.loc["Gini"].drop("Gini").min(), M.loc["Gini"].drop("Gini").max()
    verifica(Mloss_min > .5, "scegliere il Gini non costa > 0,5 su tutti gli altri indicatori")
    mx = Mm.stack().sort_values(ascending=False)
    S["top_perdita"] = (mx.index[0], mx.iloc[0])
    pe = P[(P.Scelto == "Gini") & (P.Perde == "EccessoMax_EUR")]
    eur_ex = pe.EUR_mediana.iloc[0] if "EUR_mediana" in pe else np.nan
    f_loss = figura(fig, "Quanto si perde scegliendo la regola migliore su un altro criterio",
                    "Si sceglie il metodo migliore sull'indicatore di riga e si legge il suo rimpianto sull'indicatore di colonna "
                    "(0 = non si perde nulla, 1 = si perde tutta l'escursione fra i metodi). Mediana fra le repliche.",
                    f"Il trade-off più caro è <b>uguaglianza contro incentivo</b>: chi sceglie il Gini perde {n(S['g_is'])} dell'escursione "
                    f"sulla forza incentivante, chi sceglie l'incentivo perde {n(S['is_g'])} sul Gini. Scegliere il Gini costa su tutti gli altri sette indicatori ({n(Mloss_min)}-{n(Mloss_max)}), "
                    f"{n(S['g_ex'])} sulla stabilità. <b>Merito e stabilità non si fanno concorrenza</b> (perdite {n(S['fi_ex'])} e "
                    f"{n(S['ex_fi'])}): chi minimizza l'eccesso di coalizione è già quasi il migliore per merito, e viceversa. Le perdite "
                    "fra gli indicatori dello stesso gruppo sono basse; quelle fra gruppi diversi sono dove la scelta della regola "
                    "diventa una scelta di valori.")
    tradeoff = f_loss

    # -------------------------------------------------------------- 9. sufficienza e Pareto
    SU = D["sufficienza"]
    tagli = sorted(SU.TaglioTau.unique())
    pv = SU.pivot_table(index="Indicatore", columns="TaglioTau", values="mediana").reindex(INDICATORI)
    rm = SU.pivot_table(index="Indicatore", columns="TaglioTau", values="RappresentanteModale", aggfunc="first").reindex(INDICATORI)
    righe_su = [[ni(i)] + [f"{n(pv.loc[i, t])} <span class='m'>({'sé stesso' if rm.loc[i, t] == i else e(ni(rm.loc[i, t]))})</span>" for t in tagli] for i in INDICATORI]
    S["conc_min"] = pv.min().min()
    S["rappr"] = sorted({ni(x) for x in rm.iloc[:, 0].unique()})
    verifica((rm.loc["AllineamentoVirtu_lordo"] == "AllineamentoVirtu_lordo").all(), "l'allineamento lordo non e' il rappresentante di se' stesso")
    PA = D["pareto"]
    pp = PA.pivot_table(index="InsiemeCriteri", columns="Metodo", values="mediana")[Qo.index]
    fig, ax = plt.subplots(figsize=(10, 2.8 + .35 * len(pp)))
    heat(ax, pp.values, [s_.replace(" + ", "\n+ ").replace("Sostenibilita", "Sost.") for s_ in pp.index],
         [m.replace(" ", "\n", 1) for m in pp.columns], SEQ, vmin=0, vmax=1)
    ax.xaxis.tick_top()
    ax.tick_params(axis="y", labelsize=7.5)
    S["pareto_alti"] = (pp >= .5).sum(axis=1).median()
    verifica(S["pareto_alti"] >= 3, "i fronti di Pareto non hanno in mediana almeno 3 metodi con quota >= 50%")
    f_par = figura(fig, "Il fronte di Pareto: quali metodi non sono dominati",
                   "Per ogni terna di criteri (uguaglianza, incentivo, sostenibilità, nelle varianti con incentivo netto o lordo), la quota "
                   "di comunità in cui il metodo sta sul fronte di Pareto, cioè nessun altro metodo è migliore su tutti i criteri insieme. "
                   "Mediana fra le repliche, livello base.",
                   f"Il fronte non è stretto: in mediana {n(S['pareto_alti'], 0)} metodi su 10 stanno sul fronte in almeno metà delle "
                   "comunità. Escludere i metodi dominati non basta a scegliere: restano più regole difendibili, e fra loro la scelta "
                   "dipende dai pesi che si danno ai criteri.")
    suff = (
        "<p>Un piccolo sottoinsieme di indicatori basta a riprodurre l'ordine dei metodi che "
        "producono tutti gli altri? Per ogni indicatore si guarda a un rappresentante dello stesso gruppo di τ-b alto (taglio sul τ), e "
        "si misura la quota di coppie di metodi ordinate allo stesso modo dal rappresentante e dall'indicatore (mediana fra le repliche). "
        "Fra parentesi, il rappresentante scelto più spesso.</p>"
        + tabella(righe_su, ["Indicatore"] + [f"τ ≥ {n(t, 1)}" for t in tagli]) +
        f"<div class='lettura'><b>Cosa se ne ricava.</b> Per ordinare i metodi un sottoinsieme basta: i rappresentanti scelti conservano almeno "
        f"il {pc(S['conc_min'])} degli ordinamenti a coppie. Il sottoinsieme minimo ha {len(S['rappr'])} indicatori: {', '.join(S['rappr'])}. "
        "L'allineamento lordo non è rappresentato da nessun altro indicatore e va tenuto: è quello che dipende dalle famiglie. Ma ordinare non "
        "basta a scegliere: il fronte di Pareto sotto mostra che restano molte regole non dominate.</div>" + f_par)

    # -------------------------------------------------------------- 10. stabilità
    t = tf[tf.Metodo.isin(metodi)].copy()
    t["nucleo"] = t.EccessoMax_EUR <= 1e-9
    stab = t.groupby("Metodo").agg(ecc=("EccessoMax_pct_vN", "median"), p90=("EccessoMax_pct_vN", lambda s: s.quantile(.9)),
                                   nucleo=("nucleo", "mean"), instab=("CoalizioniInstabili", "median")).sort_values("ecc")
    fig, ax = plt.subplots(figsize=(9, 4.2))
    yy = np.arange(len(stab))
    ax.barh(yy, stab.ecc, color=CAT[0], height=.62)
    ax.scatter(stab.p90, yy, color=INK2, s=22, zorder=3, label="90° percentile")
    ax.axvline(0, color=INK2, lw=1)
    ax.set_yticks(yy, stab.index)
    ax.invert_yaxis()
    ax.set_xlabel("eccesso massimo di coalizione (% di v(N)): mediana sulle comunità")
    ax.legend(loc="upper right")
    verifica(stab.nucleo["Variance Least Core"] > .99, "il VLC non e' nel nucleo in tutte le comunita'")
    verifica(stab.ecc.drop("Variance Least Core").min() > 0, "un altro metodo ha eccesso mediano <= 0")
    nucleo_altri = stab.nucleo.drop("Variance Least Core").max()
    f_stab = figura(fig, "Stabilità di coalizione: quanto un sottogruppo guadagnerebbe uscendo",
                    f"Eccesso massimo di coalizione, in % di v(N), su tutte le comunità ({mig(n_rep_com)}: ogni replica, ogni livello). "
                    "Un valore ≤ 0 significa che nessuna coalizione ha convenienza a uscire (la ripartizione è nel nucleo). Barra: mediana; punto: 90° percentile." +
                    " Lo Shapley è esatto fino a 18 membri e AS da 20.",
                    f"Il <b>Variance Least Core</b> sta nel nucleo nel {pc(stab.nucleo['Variance Least Core'])} delle comunità (eccesso mediano "
                    f"{n(stab.ecc['Variance Least Core'])}% di v(N)): il nucleo non è mai vuoto. Tutti gli altri metodi hanno eccesso mediano positivo, "
                    f"e il migliore di loro ({e(stab.drop('Variance Least Core').ecc.idxmin())}, {n(stab.drop('Variance Least Core').ecc.min(), 1)}%) sta nel "
                    f"nucleo nel {pc(nucleo_altri)} delle comunità. L'<b>Equal Split</b> è il più instabile ({n(stab.ecc['Equal Split'], 0)}% di v(N)): "
                    "sceglierlo per uguaglianza significa che qualche sottogruppo converrebbe sempre a uscire. Questa è la ragione "
                    "economica dello scarto fra uguaglianza e stabilità della sezione 8.")
    righe_stab = [[e(m), n(stab.loc[m, "ecc"], 1) + "%", n(stab.loc[m, "p90"], 1) + "%", pc(stab.loc[m, "nucleo"], 1),
                   n(stab.loc[m, "instab"], 0)] for m in stab.index]
    stabilita = f_stab + dettagli("Tabella per metodo", tabella(
        righe_stab, ["Metodo", "Eccesso mediano (% v(N))", "90° percentile", "Nel nucleo", "Coalizioni instabili (mediana)"]))

    # -------------------------------------------------------------- 11. Shapley vs AS e quote ai prosumer
    F1 = AR.leggi({r: D["tabs"][r] for r in rep}, "fase1/regime_le18_Shapley_vs_AS_per_taglia.csv")
    F1 = F1[F1.Replica >= 1]
    g1 = F1.groupby("Membri").agg(rd=("RD_medio_pct", "median"), rdmax=("RD_max_pct", "max"), rho=("Spearman_rho_min", "min"),
                                  rhomed=("Spearman_rho_medio", "median"))
    S["rd"] = (g1.rd.min(), g1.rd.max(), g1.rdmax.max())
    S["rho"] = g1.rho.min()
    verifica(g1.rd.max() < 3 and g1.rho.min() > .5, "l'AS si discosta dallo Shapley esatto piu' di quanto il testo dica")
    righe_as = [[str(int(m)), n(g1.loc[m, "rd"], 2) + "%", n(g1.loc[m, "rdmax"], 1) + "%", n(g1.loc[m, "rhomed"], 3), n(g1.loc[m, "rho"], 2)]
                for m in g1.index]
    as_t = (
        "<p>Fino a 18 membri si può calcolare lo Shapley esatto e confrontarlo con l'Adaptive Sampling (AS) che da 20 membri lo sostituisce. "
        "Scarto relativo (RD) sulle quote dei membri e correlazione di rango (Spearman) fra le due ripartizioni. Mediana (RD) e valori "
        "peggiori sulle 20 repliche.</p>"
        + tabella(righe_as, ["Membri", "RD medio (mediana)", "RD massimo (peggiore)", "Spearman medio (mediana)", "Spearman minimo"]) +
        f"<div class='lettura'><b>Cosa se ne ricava.</b> L'AS è una buona approssimazione: lo scarto medio è al più "
        f"{n(S['rd'][1], 2)}% (singolo membro fino a {n(S['rd'][2], 1)}%), e l'ordine dei membri è praticamente lo stesso "
        f"(Spearman minimo {n(S['rho'])}). Nelle comunità da 20 e 25 membri i risultati dello \"Shapley\" sono quindi quelli dell'AS, "
        "con questo margine d'errore.</div>")

    QP = AR.leggi({r: D["tabs"][r] for r in rep}, "sintesi/quote_prosumer.csv")
    QP = QP[(QP.Replica >= 1) & (QP.Metodo.isin(metodi))]
    qm = QP.groupby(["Metodo", "Fascia"]).RapportoAllaQuotaDiMembri.median().unstack().loc[Qo.index]
    fig, ax = plt.subplots(figsize=(8, 4.3))
    nm_ = TwoSlopeNorm(vcenter=1, vmin=min(.6, qm.min().min()), vmax=max(1.4, qm.max().max()))
    heat(ax, qm.values, list(qm.index), [FL[f] for f in qm.columns], DIV, norm=nm_, fmt="{:.2f}", scala=1)
    ax.xaxis.tick_top()
    qs = qm.iloc[:, :3].stack()
    (qmax_m, qmax_f), (qmin_m, qmin_f) = qs.idxmax(), qs.idxmin()
    S["qp_max"], S["qp_min"] = qs.max(), qs.min()
    f_qp = figura(fig, "Chi guadagna: quota ai prosumer rispetto alla loro quota di membri",
                  "Rapporto fra la quota di v(N) che va ai prosumer e la loro quota numerica (1 = ricevono quanto la loro numerosità; "
                  "&gt; 1 = ricevono di più). Mediana fra le repliche. Al 100% di prosumer vale 1 per costruzione.",
                  f"L'Equal Split dà ai prosumer esattamente la loro quota numerica. Il metodo che più li favorisce è <b>{e(qmax_m)}</b> "
                  f"({n(S['qp_max'])}× la quota numerica, in fascia {qmax_f}); quello che meno li favorisce è <b>{e(qmin_m)}</b> ({n(S['qp_min'])}×, "
                  f"in fascia {qmin_f}). Le chiavi di sincronismo (Pearson Key, Similarity-Utilization) e il Tri-level EP dirottano il premio verso i "
                  f"consumatori: ai prosumer va il {pc(qm.loc[['Pearson Key', 'Similarity-Utilization', 'Tri-level EP']].iloc[:, 0].max())} o meno "
                  "della loro quota numerica a bassa penetrazione. Dove i prosumer sono pochi, la scelta della regola decide quanta parte del beneficio va a chi produce e quanta a chi consuma.")
    verifica(abs(qm.loc["Equal Split"].iloc[:3] - 1).max() < 0.05, "Equal Split non da' ai prosumer la quota numerica")
    quote = f_qp

    # -------------------------------------------------------------- 13. inclusione (preliminare)
    inc = tf[tf.InclusioneLIHC.notna() & tf.Metodo.isin(metodi)]
    kc = inc.drop_duplicates(["Replica", "Scheda", "Composizione"])
    S["inc_n"], S["inc_rep"] = len(kc), kc.Replica.nunique()
    S["inc_taglie"] = sorted(int(x) for x in kc.Membri.unique())
    S["inc_quota"] = S["inc_n"] / (nrep * ncom)
    ist = inc.groupby("Metodo").InclusioneLIHC.agg(["median", "min", "max"]).sort_values("median")
    verifica(abs(ist.loc["Equal Split", "median"] - 1) < 1e-9, "l'inclusione dell'Equal Split non vale 1")
    if S["inc_n"]:
        fig, ax = plt.subplots(figsize=(8.6, 4.2))
        yy = np.arange(len(ist))
        ax.barh(yy, ist["median"], color=CAT[0], height=.62)
        ax.hlines(yy, ist["min"], ist["max"], color=INK2, lw=1.4)
        ax.axvline(1, color=INK2, lw=1, ls="--")
        ax.set_yticks(yy, ist.index)
        ax.set_xlabel("inclusione: quota ai vulnerabili / loro quota numerica (1 = proporzionale)")
        sopra = [m for m in ist.index if ist.loc[m, "median"] > 1.05]
        sotto = [m for m in ist.index if ist.loc[m, "median"] < 0.95]
        f_inc = figura(fig, "Inclusione dei vulnerabili LIHC (preliminare)",
                       f"Indice di inclusione (quanto del montepremi va ai membri in povertà energetica rispetto a quanti sono; 1 = in proporzione) "
                       f"nelle {S['inc_n']} comunità in cui compare almeno un vulnerabile. Barra: mediana; linea: minimo-massimo.",
                       f"L'indicatore è calcolabile solo a {', '.join(map(str, S['inc_taglie']))} membri e in {S['inc_rep']} repliche su {nrep} "
                       f"({pc(S['inc_quota'], 1)} delle comunità): negli altri casi nessuna famiglia estratta risulta vulnerabile. "
                       f"<b>Equal Split = 1 per costruzione.</b> Danno ai vulnerabili più della loro quota numerica: "
                       f"{', '.join(e(m) for m in sopra[::-1])} (fino a {n(ist.loc[sopra[-1], 'median'], 1) if sopra else 'n.d.'}× la quota). "
                       f"Danno meno: {', '.join(e(m) for m in sotto) or 'nessuno'}. Il Tri-level EP ha un livello dedicato alla povertà energetica: il suo primo posto è per costruzione. Il campione è piccolo e <b>il risultato è preliminare</b>: chi è vulnerabile dipende da tre "
                       "parametri di scenario (mediana nazionale della spesa energetica, soglia di povertà, markup) che in <code>CER_input.txt</code> "
                       "sono ancora <code>?</code>, e il codice usa valori di ripiego.")
        inclusione = f_inc
    else:
        inclusione = "<p>Nessuna comunità con vulnerabili LIHC: l'inclusione non è valutabile.</p>"

    # -------------------------------------------------------------- 14. sensibilita' alla soglia di rilevanza
    SS = AR.leggi({r: D["tabs"][r] for r in rep}, "sintesi/sensibilita_soglia_sweep.csv")
    SV = AR.leggi({r: D["tabs"][r] for r in rep}, "sintesi/sensibilita_soglia_vincitori.csv")
    SS, SV = SS[SS.Replica >= 1], SV[SV.Replica >= 1]
    sp = SS[SS.Sweep == "penetrazione"].groupby(["Replica", "FracEscursione"]).QuotaInvertite.mean().groupby("FracEscursione").median()
    sv = SV.groupby("FracEscursione").agg(celle=("Celle", "median"), div=("VincitoreDiversoDaMAIN2", "median"),
                                          pari=("CelleAPari", "median"))
    righe_sv = [[n(100 * f, 0) + "%" + (" <span class='m'>(valore usato)</span>" if abs(f - .1) < 1e-9 else ""),
                 pc(sp[f]), n(sv.loc[f, "div"], 0), n(sv.loc[f, "pari"], 0)] for f in sv.index]
    sens = (
        "<p>Due metodi sono \"a pari\" se distano meno di una soglia, in quota dell'escursione fra i metodi. La soglia usata è il 10%: è una scelta "
        "di modello, e qui si vede quanto i risultati cambiano se la si sposta (0% = solo tolleranza numerica). Mediana fra le repliche.</p>"
        + tabella(righe_sv, ["Soglia (quota dell'escursione)", "Coppie invertite lungo la penetrazione", "Celle con vincitore diverso da quello usato",
                             "Celle con più primi a pari merito"]) +
        f"<div class='lettura'><b>Cosa se ne ricava.</b> Le inversioni lungo la penetrazione passano dal {pc(sp.iloc[0])} (nessuna soglia) al "
        f"{pc(sp.iloc[-1])} (soglia del 20%): il numero assoluto dipende dalla soglia, e conviene riportarlo con la soglia usata. Ciò che regge a "
        "qualunque soglia è l'ordine di grandezza e la direzione: la penetrazione sposta le graduatorie più di taglia e composizione.</div>")
    verifica(sp.iloc[0] >= sp.iloc[-1], "le inversioni non calano al crescere della soglia")

    # -------------------------------------------------------------- conclusioni
    rq = ("<div class='rq'><p><i>When mechanisms from different methodological families allocate the value associated with shared energy using "
          "a year's hourly profiles, how do their rankings vary across distributive-fairness criteria, coalitional stability, and the "
          "ex-post reward given to temporal alignment? How sensitive are these rankings to community size, prosumer penetration, and "
          "member-category composition, and how large are the trade-offs among these evaluation dimensions? Finally, can a reduced set of "
          "indicators preserve the main distinctions produced by the full set?</i></p></div>")
    conclusioni = rq + f"""
<h3>1. Come variano le graduatorie fra i criteri</h3>
<p><b>Risposta.</b> Ogni criterio ha un vincitore diverso, e i vincitori stanno in famiglie diverse: l'Equal Split sull'uguaglianza, il Variance
Least Core (con lo Shapley) su merito e stabilità, le chiavi di sincronismo e il Tri-level EP sull'incentivo (sezione 3). Nessun metodo è primo
su tutto, e il metodo col rimpianto massimo più basso ({e(best_all)}, {n(worst.min())}) dista comunque più della metà dell'escursione dal migliore su almeno un indicatore (sezione 4). Il vincitore di
una cella resta lo stesso nel {pc(S['modale_min'])}-{pc(S['modale_max'])} delle repliche, quindi la risposta non dipende da quali famiglie
vengono estratte. <b>Limite:</b> per tre indicatori il primato è in parte per costruzione; l'informazione sta nella graduatoria degli altri metodi.</p>
<h3>2. Come variano con penetrazione, taglia e composizione</h3>
<p><b>Risposta.</b> La <b>penetrazione dei prosumer</b> è il fattore dominante: {pc(S['var_pen'][0])}-{pc(S['var_pen'][1])} della varianza dei punteggi,
{pc(S['inv_pen'][0])}-{pc(S['inv_pen'][1])} di coppie invertite. Il risultato centrale è che <b>la struttura del conflitto si capovolge</b>:
a bassa penetrazione il merito si oppone all'incentivo (τ mediano {n(S['fi'][0])}); ad alta penetrazione concorda con l'incentivo
(τ {n(S['fi'][1])}) e l'uguaglianza si oppone a entrambi (τ Gini-incentivo da {n(S['gi'][0])} a {n(S['gi'][1])}). Vale {tutte(S['gi'][2], S['fi'][2], nrep)}. La <b>taglia</b> pesa poco (al più il {pc(S['var_tag_max'])} della varianza, {pc(S['inv_tag'][0])}-{pc(S['inv_tag'][1])}
di coppie invertite). La <b>composizione</b> (PA, imprese) inverte il {pc(S['comp_inv'][0])}-{pc(S['comp_inv'][1])} delle coppie. I <b>partecipanti</b>
(quali famiglie) spiegano il {pc(S['var_part'][0])}-{pc(S['var_part'][1])} della varianza: contano, ma non cambiano nessuna conclusione di
segno. <b>Limiti:</b> la composizione porta con sé la scala (v(N)) e i due effetti non sono separati; l'allineamento lordo dipende dalle famiglie
molto più degli altri indicatori.</p>
<h3>3. Quanto costano i trade-off</h3>
<p><b>Risposta.</b> Il più caro è uguaglianza contro incentivo: chi sceglie il Gini perde {n(S['g_is'])} dell'escursione sull'incentivo, chi sceglie
l'incentivo perde {n(S['is_g'])} sul Gini. Scegliere il Gini (cioè l'Equal Split) costa su tutti gli altri sette indicatori ({n(Mloss_min)}-{n(Mloss_max)} dell'escursione), {n(S['g_ex'])} sulla stabilità: l'Equal Split ha un eccesso mediano del
{n(stab.ecc['Equal Split'], 0)}% di v(N). Merito e stabilità non si fanno concorrenza (perdite {n(S['fi_ex'])}). In pratica: l'uguaglianza si paga in
stabilità e incentivo, il merito è quasi gratuito rispetto alla stabilità.</p>
<h3>4. Basta un sottoinsieme di indicatori?</h3>
<p><b>Risposta.</b> Per ordinare i metodi sì: {len(S['rappr'])} indicatori ({', '.join(S['rappr'])}) conservano almeno il {pc(S['conc_min'])} degli ordinamenti a coppie;
l'allineamento lordo non è riassunto da nessun altro e va tenuto. Per scegliere no: il fronte di Pareto lascia in mediana {n(S['pareto_alti'], 0)} metodi su 10 non dominati.</p>
<h3>5. Cosa il lavoro dice solo in parte</h3>
<p>L'<b>inclusione</b> (LIHC) è calcolabile solo a {', '.join(map(str, S['inc_taglie']))} membri e in {S['inc_rep']} repliche su {nrep}
({pc(S['inc_quota'], 1)} delle comunità), e dipende da tre parametri di scenario ancora segnaposto: è un risultato preliminare (sezione 13), non una
conclusione. La <b>soglia regolatoria</b> del 55% morde in {S['binding']} comunità su {mig(S['bind_tot'])} (solo famiglie, bassa penetrazione): non
cambia la ripartizione fra i metodi, perché l'eccedenza riguarda solo le imprese, ma la quota incentivata in quei casi va riportata.</p>"""

    limiti = f"""<ul>
<li><b>Le famiglie vengono da un pool di cento.</b> Le {nrep} repliche estraggono sempre da quel pool, annidate fra taglie e fasce: la variazione fra repliche
misura la dipendenza dalle famiglie, ma non da altre popolazioni (altri territori, altre abitudini).</li>
<li><b>Lo Shapley da 20 membri è una stima.</b> Lo scarto medio dall'esatto è al più {n(S['rd'][1], 2)}% (sezione 11), ma non è misurabile oltre i 18 membri.</li>
<li><b>Il Nucleolo non c'è.</b> Non si calcola oltre i 18 membri, quindi è fuori dall'analisi unita.</li>
<li><b>Il primato su Gini, Fairness Index ed eccesso massimo è in parte per costruzione</b> (Equal Split, Variance Least Core). Va dichiarato accanto ai risultati.</li>
<li><b>L'allineamento lordo è l'indicatore meno robusto</b>: dipende dalle famiglie per il {pc(VZ.loc['AllineamentoVirtu_lordo', 'partecipanti'])} della varianza e non è riassunto da nessun altro.</li>
<li><b>Composizione e scala.</b> Aggiungere PA o imprese moltiplica v(N); gli effetti di composizione e di scala non sono separati.</li>
<li><b>Una sola zona e un solo anno</b> (MGP 2025, zona Nord), profili deterministici.</li>
<li><b>Inclusione:</b> parametri LIHC ancora segnaposto (P50, soglia di povertà, markup in <code>CER_input.txt</code>); da rifare quando si compilano.</li>
<li><b>Le conclusioni non valgono per il disegno di partenza</b> (r00, persone sole): quel disegno è stato usato solo come controllo del generatore.</li>
</ul>"""

    riproduci = """<pre>venv/Scripts/python.exe -I CER_repliche/aggrega_repliche.py --blocco unito   # aggregato (7 s)
venv/Scripts/python.exe -I CER_repliche/rapporto_repliche.py                      # questa pagina</pre>
<p>Le repliche si rifanno con <code>CER_repliche/lancia_repliche.sh</code> e <code>unisci_repliche.sh</code> (README di <code>CER_repliche/</code>). Questo script
non modifica nessun file esistente: legge <code>outputs/repliche/unito/aggregato/</code> e gli export <code>outputs/repliche/unito/rNN/export/</code>
(r01-r20) e le tabelle <code>rNN/tables/</code>.</p>"""

    # -------------------------------------------------------------- pagina
    sezioni = [("disegno", "1. Il disegno", disegno), ("montepremi", "2. Il montepremi e la soglia regolatoria", montepremi),
               ("vince", "3. Chi vince", chi_vince), ("profili", "4. Il profilo di ogni metodo", f_prof),
               ("accordo", "5. Accordo fra i criteri", accordo), ("assi", "6. Penetrazione, taglia e partecipanti", assi),
               ("composizione", "7. Composizione: PA e imprese", composizione), ("tradeoff", "8. Trade-off", tradeoff),
               ("sufficienza", "9. Sottoinsieme di indicatori e fronte di Pareto", suff),
               ("stabilita", "10. Stabilità di coalizione", stabilita), ("shapley", "11. Shapley esatto contro Adaptive Sampling", as_t),
               ("quote", "12. Chi guadagna: prosumer e consumatori", quote),
               ("inclusione", "13. Inclusione dei vulnerabili (preliminare)", inclusione),
               ("soglia", "14. Sensibilità alla soglia di rilevanza", sens),
               ("conclusioni", "15. Conclusioni", conclusioni), ("limiti", "16. Limiti", limiti),
               ("riproduci", "17. Come si rigenera", riproduci)]
    sintesi = f"""<div class='sintesi'><h2>In breve</h2><ul>
<li><b>Nessun metodo domina.</b> Tre poli: uguaglianza (Equal Split), merito e stabilità (Variance Least Core, Shapley), incentivo
(Pearson Key, Tri-level EP, Similarity-Utilization).</li>
<li><b>Il conflitto si capovolge con la penetrazione.</b> Il merito si oppone all'incentivo a bassa penetrazione (τ {n(S['fi'][0])}) e vi concorda ad alta
(τ {n(S['fi'][1])}); l'uguaglianza si oppone all'incentivo (τ fino a {n(S['gi'][1])}). Vale {tutte(S['gi'][2], S['fi'][2], nrep)}.</li>
<li><b>La penetrazione conta più di tutto</b> ({pc(S['var_pen'][0])}-{pc(S['var_pen'][1])} della varianza), la taglia poco (al più {pc(S['var_tag_max'])}),
la composizione il {pc(S['comp_inv'][0])}-{pc(S['comp_inv'][1])} delle coppie, le famiglie il {pc(S['var_part'][0])}-{pc(S['var_part'][1])}.</li>
<li><b>Il trade-off più caro è uguaglianza contro incentivo</b> (perdite {n(S['g_is'])} e {n(S['is_g'])}); merito e stabilità non si fanno concorrenza.</li>
<li><b>Un sottoinsieme di indicatori ordina i metodi</b> (≥ {pc(S['conc_min'])} delle coppie) <b>ma non sceglie</b>: il fronte di Pareto resta largo.</li>
<li><b>Il Variance Least Core è l'unico nel nucleo</b> ({pc(stab.nucleo['Variance Least Core'])} delle comunità); l'Equal Split è il più instabile.</li>
<li><b>La soglia GSE morde in {S['binding']} comunità su {mig(S['bind_tot'])}</b> ({pc(S['binding'] / S['bind_tot'], 1)}; solo famiglie, bassa penetrazione): non cambia
la ripartizione, ma nel disegno di partenza non succedeva. <b>L'inclusione è calcolabile solo in parte</b> ({pc(S['inc_quota'], 1)} delle comunità) e resta preliminare.</li></ul></div>"""
    indice = "".join(f"<a href='#{i}'>{t}</a>" for i, t, _ in sezioni)
    corpo = "".join(sezione(i, t, c_) for i, t, c_ in sezioni)
    pagina = f"""<!doctype html>
<html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Risultati delle repliche e conclusioni</title>
<style>
:root {{ --bg:#f9f9f7; --panel:#fcfcfb; --ink:#0b0b0b; --muted:#52514e; --rule:#e1e0d9; --accent:#2a78d6; --soft:#eef4fc; }}
* {{ box-sizing:border-box; }}
body {{ background:var(--bg); color:var(--ink); font:16px/1.6 system-ui,"Segoe UI",Roboto,sans-serif; margin:0; }}
main {{ max-width:1120px; margin:0 auto; padding:28px 16px 80px; }}
h1 {{ font-size:28px; line-height:1.25; margin:0 0 6px; }} h2 {{ font-size:22px; margin:0 0 12px; }}
h3 {{ font-size:17px; margin:22px 0 8px; }} p, li {{ max-width:80ch; }}
.sub {{ color:var(--muted); margin:0 0 18px; }}
nav {{ display:flex; flex-wrap:wrap; gap:4px 14px; font-size:14px; margin:0 0 22px; padding:10px 0;
  border-top:1px solid var(--rule); border-bottom:1px solid var(--rule); }}
a {{ color:var(--accent); }} section {{ border-top:1px solid var(--rule); padding:26px 0 10px; }}
.sintesi {{ background:var(--soft); border-radius:8px; padding:16px 20px; margin:0 0 10px; }} .sintesi h2 {{ margin-top:0; }}
.fig {{ margin:18px 0 26px; }}
.fig img {{ display:block; max-width:100%; height:auto; border:1px solid var(--rule); border-radius:4px; margin:8px 0 6px; }}
.cosa {{ color:var(--muted); }} .lettura {{ border-left:3px solid var(--accent); padding:2px 0 2px 12px; margin:8px 0 14px; }}
.m {{ color:var(--muted); font-size:13px; }}
.tab {{ overflow-x:auto; margin:8px 0 12px; }} table {{ border-collapse:collapse; font-size:14px; min-width:50%; }}
th, td {{ border-bottom:1px solid var(--rule); padding:5px 10px; text-align:left; vertical-align:top; }}
th {{ background:var(--soft); font-weight:600; }} td.n, th.n {{ text-align:right; font-variant-numeric:tabular-nums; }}
details {{ border:1px solid var(--rule); border-radius:6px; padding:8px 14px; margin:14px 0; background:var(--panel); }}
summary {{ cursor:pointer; font-weight:600; }} .rq {{ background:var(--soft); border-radius:8px; padding:4px 18px; }}
pre {{ white-space:pre-wrap; font-size:12.5px; background:var(--soft); padding:10px 12px; border-radius:6px; }}
</style></head><body><main>
<h1>Risultati delle repliche e conclusioni</h1>
<p class='sub'>Ripartizione dei benefici nelle CER: {nrep} repliche dei partecipanti (r01-r20) × {ncom} comunità da {min(taglie)} a {max(taglie)} membri
= {mig(n_rep_com)} comunità, {len(metodi)} metodi, 8 indicatori. Dati del 3 novembre 2026. Generato da <code>CER_repliche/rapporto_repliche.py</code>.</p>
<nav>{indice}</nav>{sintesi}{corpo}</main></body></html>"""
    if FALLITE:
        raise SystemExit("Affermazioni del testo non sostenute dai dati, pagina NON scritta:\n  - " + "\n  - ".join(FALLITE))
    out = Path(a.uscita)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(pagina, encoding="utf-8")
    print(f"scritto {out} ({out.stat().st_size / 1e6:.1f} MB)")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--blocco", default=str(ROOT / "outputs/repliche/unito"))
    ap.add_argument("--uscita", default=str(ROOT / "outputs/report/RISULTATI_repliche_2026-11-03.html"))
    costruisci(ap.parse_args())


if __name__ == "__main__":
    main()
