"""Grafici metodo x metrica e analisi di scalabilita'.

Uso:
    python -I grafici_metodi.py <export_dir> [--out DIR] [--solo-completi]
                                [--bin-pen 25] [--n-escludi 1]

<export_dir> contiene tfair_lungo.csv (una riga per scheda e metodo) e, se c'e',
comunita.csv. Funziona sui run di ottobre (export_fino18, export_griglia25) e su
qualunque export successivo con lo stesso formato.

Definizioni (appunti della tesi)
    s = (n, d, p)   n = membri, d = eterogeneita' (composizione), p = penetrazione
    phi             uno dei 12 metodi di ripartizione
    m               una metrica; ogni metrica ha un verso (alto = meglio o basso = meglio)

Normalizzazione. Ogni scheda si normalizza da sola sui metodi che ci sono in quella scheda:
1 = il metodo migliore, 0 = il peggiore, con il verso della metrica. Solo dopo si calcolano
media e deviazione standard sulle schede. Se in una scheda tutti i metodi hanno lo stesso
valore, la scheda non discrimina quella metrica e si salta (NaN).

Grafici
    1) per ogni metrica:  barre = 12 metodi, valore GREZZO medio +- std sulle schede
    2) per ogni metodo:   barre = metriche, valore NORMALIZZATO medio +- std
    3) un grafico unico:  12 punti per metrica (uno per metodo), NORMALIZZATO medio +- std
    4) scalabilita':      si fissano due assi fra (n, d, p) e si fa variare il terzo

Schede senza tutti i metodi (Shapley e Nucleolo mancano sopra i 18 membri): di default si
tengono tutte e sotto ogni barra si scrive il numero di schede usate; con --solo-completi
si restringe S alle schede che hanno tutti i metodi.

Composizione d. Si legge, in ordine, dalla colonna `Composizione` di tfair_lungo.csv o di
comunita.csv, poi da un prefisso/suffisso PAk nel nome della scheda (es. PA2/CER_5_5_0);
altrimenti vale PA0 (solo domestici). Le etichette sono in ETICHETTE_D.
"""
import argparse
import re
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

# ------------------------------------------------------------------ configurazione
# metrica -> (gruppo, verso). verso +1 = piu' alto e' meglio, -1 = piu' basso e' meglio.
# Equita' contiene il solo Gini: EI_orig = 1 - Gini (stessa metrica), mentre InclusioneLIHC
# e VAN_min_EUR sono indicatori economici e vanno in un'analisi a parte.
# QuoteNulle (membri lasciati a quota nulla) e' una candidata a Equita': tolga il # per usarla.
METRICHE = {
    "Gini": ("Equità", -1),
    # "QuoteNulle": ("Equità", -1),
    "FairnessIndex": ("Merito", -1),
    "Sigma": ("Merito", -1),
    "EccessoMax_EUR": ("Stabilità", -1),
    "CoalizioniInstabili": ("Stabilità", -1),
    "ForzaIncentivante": ("Engagement", +1),
    "AllineamentoVirtu": ("Engagement", +1),
    "AllineamentoVirtu_lordo": ("Engagement", +1),
}
GRUPPI = ["Equità", "Merito", "Stabilità", "Engagement"]
COLORE_GRUPPO = {"Equità": "#4C78A8", "Merito": "#F58518", "Stabilità": "#54A24B", "Engagement": "#B279A2"}

METODI = [
    "Shapley", "Adaptive Sampling Shapley", "Nucleolo", "Variance Least Core", "Equal Split",
    "Proportional to Consumption", "Remuneration Model 1", "Cascading Tree",
    "Weighted Solidarity", "Pearson Key", "Similarity-Utilization", "Tri-level EP",
]
COLORE_METODO = dict(zip(METODI, plt.get_cmap("tab20")(np.arange(12) / 20)))

ETICHETTE_D = {
    "PA0": "solo domestici",
    "PA1": "dom. + comune",
    "PA2": "dom. + comune + scuola",
    "PA3": "dom. + comune + scuola + palazzetto",
}

plt.rcParams.update({"axes.spines.top": False, "axes.spines.right": False, "font.size": 9})


# ------------------------------------------------------------------ dati
def composizione_da_nome(scheda):
    m = re.search(r"PA\d", str(scheda))
    return m.group(0) if m else None


def leggi(export_dir):
    export_dir = Path(export_dir)
    tf = pd.read_csv(export_dir / "tfair_lungo.csv")
    com_path = export_dir / "comunita.csv"
    com = pd.read_csv(com_path) if com_path.exists() else None

    if "Composizione" not in tf.columns:
        if com is not None and "Composizione" in com.columns:
            tf = tf.merge(com[["Scheda", "Composizione"]].drop_duplicates(), on="Scheda", how="left")
        else:
            tf["Composizione"] = tf.Scheda.map(composizione_da_nome)
    tf["Composizione"] = tf["Composizione"].fillna("PA0")
    tf["Scheda"] = tf.Scheda.str.replace(r"^PA\d[/\\]", "", regex=True)

    mancanti = [m for m in METRICHE if m not in tf.columns]
    if mancanti:
        sys.exit(f"colonne mancanti in tfair_lungo.csv: {mancanti}")
    return tf


def normalizza(tf):
    """Aggiunge una colonna <m>_norm per metrica: 1 = miglior metodo della scheda, 0 = peggiore."""
    tf = tf.copy()
    chiave = ["Composizione", "Scheda"]
    for m, (_, verso) in METRICHE.items():
        g = tf.groupby(chiave)[m]
        lo, hi = g.transform("min"), g.transform("max")
        span = (hi - lo).where((hi - lo) > 1e-12)
        norm = (tf[m] - lo) / span if verso > 0 else (hi - tf[m]) / span
        tf[m + "_norm"] = norm
    return tf


def media_std(tf, colonne, per="Metodo"):
    """Media e std sulle schede, con il numero di schede che contano per ogni cella."""
    g = tf.groupby(per)[colonne]
    return g.mean(), g.std(ddof=1).fillna(0.0), g.count()


# ------------------------------------------------------------------ grafici 1-3
def etichette_metodi(metodi, conta):
    return [f"{m}\n(n={int(conta.loc[m])})" if m in conta.index else m for m in metodi]


def grafico_per_metrica(tf, m, out):
    mu, sd, n = media_std(tf, [m])
    metodi = [x for x in METODI if x in mu.index]
    fig, ax = plt.subplots(figsize=(10, 4.5))
    x = np.arange(len(metodi))
    ax.bar(x, mu.loc[metodi, m], yerr=sd.loc[metodi, m], capsize=3,
           color=[COLORE_METODO[k] for k in metodi], edgecolor="#333", linewidth=0.5)
    ax.set_xticks(x, etichette_metodi(metodi, n[m]), rotation=40, ha="right", fontsize=8)
    ax.set_ylabel(m)
    verso = "più basso = meglio" if METRICHE[m][1] < 0 else "più alto = meglio"
    ax.set_title(f"{m}  [{METRICHE[m][0]}, {verso}]  media ± std su S")
    ax.axhline(0, color="#888", linewidth=0.6)
    fig.tight_layout()
    fig.savefig(out / f"{m}.png", dpi=150)
    plt.close(fig)


def grafico_per_metodo(tf, phi, out):
    sotto = tf[tf.Metodo == phi]
    cols = [m + "_norm" for m in METRICHE]
    mu, sd, n = sotto[cols].mean(), sotto[cols].std(ddof=1).fillna(0.0), sotto[cols].count()
    fig, ax = plt.subplots(figsize=(9, 4.5))
    x = np.arange(len(cols))
    ax.bar(x, mu.values, yerr=sd.values, capsize=3, edgecolor="#333", linewidth=0.5,
           color=[COLORE_GRUPPO[METRICHE[m][0]] for m in METRICHE])
    ax.set_xticks(x, [f"{m}\n(n={int(n[c])})" for m, c in zip(METRICHE, cols)],
                  rotation=40, ha="right", fontsize=8)
    ax.set_ylim(0, 1.1)
    ax.set_ylabel("1 = miglior metodo della scheda")
    ax.set_title(f"{phi}: media ± std su S (normalizzato per scheda)")
    ax.legend(handles=[plt.Rectangle((0, 0), 1, 1, color=COLORE_GRUPPO[g]) for g in GRUPPI],
              labels=GRUPPI, ncol=4, loc="upper center", bbox_to_anchor=(0.5, -0.38), frameon=False)
    fig.tight_layout()
    fig.savefig(out / (re.sub(r"[^\w-]+", "_", phi) + ".png"), dpi=150)
    plt.close(fig)


def grafico_sintesi(tf, out):
    cols = [m + "_norm" for m in METRICHE]
    mu, sd, _ = media_std(tf, cols)
    metodi = [x for x in METODI if x in mu.index]
    fig, ax = plt.subplots(figsize=(11, 5))
    off = np.linspace(-0.3, 0.3, len(metodi))
    for k, phi in enumerate(metodi):
        ax.errorbar(np.arange(len(cols)) + off[k], mu.loc[phi, cols], yerr=sd.loc[phi, cols],
                    fmt="o", ms=4, capsize=2, color=COLORE_METODO[phi], label=phi)
    ax.set_xticks(np.arange(len(cols)), list(METRICHE), rotation=30, ha="right")
    for i in range(len(cols) + 1):
        ax.axvline(i - 0.5, color="#ddd", linewidth=0.6)
    ax.set_ylim(-0.05, 1.1)
    ax.set_ylabel("1 = miglior metodo della scheda")
    ax.set_title("Metodi x metriche: media ± std su S (normalizzato per scheda)")
    ax.legend(ncol=2, fontsize=7, loc="center left", bbox_to_anchor=(1.01, 0.5), frameon=False)
    fig.tight_layout()
    fig.savefig(out / "sintesi_metodi_metriche.png", dpi=150)
    plt.close(fig)


# ------------------------------------------------------------------ scalabilita'
ASSI = {"n": "Membri", "d": "Composizione", "p": "PenBin"}


def aggiungi_assi(tf, bin_pen):
    tf = tf.copy()
    tf["PenBin"] = (np.round(tf.Penetrazione_pct / bin_pen) * bin_pen).astype(int)
    return tf


def etichetta_asse(asse, v):
    return ETICHETTE_D.get(v, v) if asse == "d" else (f"{v}%" if asse == "p" else str(v))


def grafico_scalabilita(tf, asse, fissi, valori_fissi, out):
    """Un pannello per metrica; x = valori dell'asse variabile, una linea per metodo."""
    sotto = tf
    for a, v in zip(fissi, valori_fissi):
        sotto = sotto[sotto[ASSI[a]] == v]
    col = ASSI[asse]
    livelli = sorted(sotto[col].unique(), key=lambda v: (str(v) if asse == "d" else v))
    if len(livelli) < 2:
        return False
    nsch = sotto.groupby(col).apply(lambda g: g[["Composizione", "Scheda"]].drop_duplicates().shape[0],
                                    include_groups=False)
    cols = [m + "_norm" for m in METRICHE]
    fig, assi = plt.subplots(2, 4, figsize=(15, 7), sharey=True)
    xs = np.arange(len(livelli))
    for ax, m, c in zip(assi.ravel(), METRICHE, cols):
        for phi in METODI:
            s = sotto[sotto.Metodo == phi]
            if s.empty:
                continue
            g = s.groupby(col)[c]
            mu, sd = g.mean().reindex(livelli), g.std(ddof=1).reindex(livelli).fillna(0)
            ax.errorbar(xs, mu.values, yerr=sd.values, marker="o", ms=3, capsize=2, linewidth=1,
                        color=COLORE_METODO[phi], label=phi, alpha=0.9)
        ax.set_xticks(xs, [f"{etichetta_asse(asse, v)}\n(s={nsch[v]})" for v in livelli], fontsize=7)
        ax.set_title(f"{m} [{METRICHE[m][0]}]", fontsize=9)
        ax.set_ylim(-0.05, 1.1)
    for ax in assi.ravel()[len(METRICHE):]:
        ax.axis("off")
    h, l = assi.ravel()[0].get_legend_handles_labels()
    fig.legend(h, l, ncol=6, loc="lower center", fontsize=7, frameon=False)
    fisso = ", ".join(f"{a}={etichetta_asse(a, v)}" for a, v in zip(fissi, valori_fissi))
    fig.suptitle(f"Scalabilità su {asse}: fissati {fisso}  (media ± std; s = schede per punto)")
    fig.tight_layout(rect=(0, 0.06, 1, 0.96))
    nome = f"var_{asse}__" + "_".join(f"{a}-{re.sub(r'[^\w.-]+', '', str(v))}" for a, v in zip(fissi, valori_fissi))
    fig.savefig(out / f"{nome}.png", dpi=130)
    plt.close(fig)
    return True


def scalabilita(tf, out):
    out.mkdir(parents=True, exist_ok=True)
    fatti = 0
    for asse, fissi in (("n", ("d", "p")), ("p", ("n", "d")), ("d", ("n", "p"))):
        combos = tf[[ASSI[a] for a in fissi]].drop_duplicates().itertuples(index=False)
        for valori in combos:
            fatti += grafico_scalabilita(tf, asse, fissi, tuple(valori), out)
    return fatti


# ------------------------------------------------------------------ main
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("export_dir")
    ap.add_argument("--out", default=None, help="cartella dei grafici (default: <export_dir>/grafici)")
    ap.add_argument("--solo-completi", action="store_true",
                    help="tiene solo le schede in cui ci sono tutti i metodi")
    ap.add_argument("--bin-pen", type=float, default=25.0,
                    help="passo in punti percentuali per raggruppare la penetrazione (default 25)")
    ap.add_argument("--n-escludi", type=int, nargs="*", default=[1],
                    help="taglie da escludere (default: 1, dove tutti i metodi coincidono)")
    a = ap.parse_args()

    out = Path(a.out) if a.out else Path(a.export_dir) / "grafici"
    tf = leggi(a.export_dir)
    tf = tf[~tf.Membri.isin(a.n_escludi)]

    tutti = tf.Metodo.nunique()
    if a.solo_completi:
        ok = tf.groupby(["Composizione", "Scheda"]).Metodo.transform("nunique") == tutti
        print(f"--solo-completi: {tf[ok].groupby(['Composizione', 'Scheda']).ngroups} schede su "
              f"{tf.groupby(['Composizione', 'Scheda']).ngroups}")
        tf = tf[ok]

    tf = aggiungi_assi(normalizza(tf), a.bin_pen)
    print(f"{tf.groupby(['Composizione', 'Scheda']).ngroups} schede, {tf.Metodo.nunique()} metodi, "
          f"{len(METRICHE)} metriche")

    for sub in ("1_per_metrica", "2_per_metodo"):
        (out / sub).mkdir(parents=True, exist_ok=True)
    for m in METRICHE:
        grafico_per_metrica(tf, m, out / "1_per_metrica")
    for phi in METODI:
        if phi in set(tf.Metodo):
            grafico_per_metodo(tf, phi, out / "2_per_metodo")
    grafico_sintesi(tf, out)
    nscal = scalabilita(tf, out / "3_scalabilita")

    cols = list(METRICHE) + [m + "_norm" for m in METRICHE]
    mu, sd, n = media_std(tf, cols)
    tab = pd.concat({"media": mu, "std": sd, "n_schede": n}, axis=1)
    tab.to_csv(out / "riepilogo_metodo_metrica.csv")
    print(f"grafici in {out}  (1_per_metrica: {len(METRICHE)}, 2_per_metodo: "
          f"{tf.Metodo.nunique()}, sintesi: 1, scalabilita': {nscal})")


if __name__ == "__main__":
    main()
