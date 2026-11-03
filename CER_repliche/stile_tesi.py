"""Stile comune delle figure della tesi: palette Polimi, nomi dei metodi, regole sui metodi.

Un solo posto per colori, etichette e regole di selezione dei metodi, usato da
aggrega_repliche.py, grafici_repliche.py e rapporto_repliche.py.

COLORI (validati con lo strumento di validazione della palette: daltonismo protan/deutan in
OKLab, contrasto sullo sfondo, separazione dei colori vicini). Il colore si sceglie dal compito
che fa nella figura:
  - ordine (fasce di penetrazione): rampa del blu Polimi, 4 passi, tutti i controlli passati;
  - ordine (taglie): rampa arancio, 7 passi, tutti i controlli passati;
  - intensita' 0-1: da bianco-azzurro al blu Polimi scuro;
  - polarita' (tau, differenze): arancio - grigio - blu Polimi;
  - identita' (famiglie di metodi, gruppi di comunita'): blu Polimi, arancio, verde, prugna.
    I 3 gruppi passano tutti i controlli; le 4 famiglie stanno nella fascia "ammessa con
    codifica secondaria" (blu-prugna Delta E 7,7 per i protanopi): hanno sempre marker diversi.
I 10 metodi NON hanno 10 colori: il nome del metodo sta sull'asse o accanto al punto, il
colore dice la famiglia. Il bluepoli del template (circa #5C8999) e' troppo grigio per i dati.
"""
from __future__ import annotations

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.colors import LinearSegmentedColormap

# ---------------------------------------------------------------------------- colori
BLU = "#005AA0"          # blu Polimi, ancora di tutte le figure
BLU_SCURO = "#00305A"
ARANCIO = "#D9731A"
VERDE = "#3BA272"
PRUGNA = "#A23B72"
GRIGIO = "#8C8C8C"
INCHIOSTRO = "#222222"   # testo, mediane, linee di riferimento
SFONDO = "#FCFCFB"

FASCE = ["#7FAACB", "#4A82AE", "#005AA0", "#00305A"]                      # fascia 1..4
TAGLIE = ["#E0A472", "#D9883F", "#C96F1C", "#A85A12", "#85460C", "#633307", "#402003"]
MAPPA = LinearSegmentedColormap.from_list("polimi_seq", ["#F4F8FB", "#7FAACB", BLU, BLU_SCURO])
DIVERGENTE = LinearSegmentedColormap.from_list("polimi_div", [ARANCIO, "#F2F2F2", BLU])

FAMIGLIE = {   # famiglia -> (colore, marker)
    "Cooperative game": (BLU, "o"),
    "Simple": (ARANCIO, "s"),
    "Synchrony-based": (VERDE, "^"),
    "Literature heuristics": (PRUGNA, "D"),
}
GRUPPI = {     # gruppo di comunita' -> (colore, marker)
    "households only": (BLU, "o"),
    "with public buildings": (ARANCIO, "s"),
    "with firms": (VERDE, "^"),
}

# ---------------------------------------------------------------------------- metodi
# Versione B del piano (1 novembre 2026): 10 metodi, gli stessi da 5 a 25 membri.
# Il Nucleolo e' escluso dal confronto; lo Shapley conta una volta sola (esatto fino a 18
# membri, Adaptive Sampling da 20 in su).
ESCLUSI = {"Nucleolo"}
AS = "Adaptive Sampling Shapley"
METODI = {   # nome nei dati -> (etichetta in inglese, famiglia)
    "Shapley": ("Shapley", "Cooperative game"),
    "Variance Least Core": ("Variance Least Core", "Cooperative game"),
    "Equal Split": ("Equal Split", "Simple"),
    "Proportional to Consumption": ("Prop. to Consumption", "Simple"),
    "Pearson Key": ("Pearson Key", "Synchrony-based"),
    "Similarity-Utilization": ("Similarity-Utilization", "Synchrony-based"),
    "Remuneration Model 1": ("Remuneration Model 1", "Literature heuristics"),
    "Cascading Tree": ("Cascading Tree", "Literature heuristics"),
    "Weighted Solidarity": ("Weighted Solidarity", "Literature heuristics"),
    "Tri-level EP": ("Tri-level EP", "Literature heuristics"),
}
ORDINE_METODI = list(METODI)
# Per le figure che devono distinguere i singoli metodi in un pannello (grafici_metodi.py,
# F08 e F13): tinta della famiglia, chiaro/scuro dentro la famiglia, piu' il nome in legenda.
COLORE_METODO = {
    "Shapley": BLU, "Variance Least Core": BLU_SCURO,
    "Equal Split": ARANCIO, "Proportional to Consumption": "#8F460B",
    "Pearson Key": VERDE, "Similarity-Utilization": "#1E6B47",
    "Remuneration Model 1": PRUGNA, "Cascading Tree": "#D17BAA",
    "Weighted Solidarity": "#6B1F4A", "Tri-level EP": "#C25591",
}

# indicatori del confronto (InclusioneLIHC non valutabile; VAN = analisi complementare)
INDICATORI = ["Gini", "FairnessIndex", "Sigma", "EccessoMax_EUR", "CoalizioniInstabili",
              "ForzaIncentivante", "AllineamentoVirtu", "AllineamentoVirtu_lordo"]
NOMI_INDICATORI = {
    "Gini": "Gini", "EI_orig": "Equality index", "FairnessIndex": "Fairness Index",
    "Sigma": "σ merit deviation", "EccessoMax_EUR": "Max coalition excess",
    "CoalizioniInstabili": "Blocking coalitions", "ForzaIncentivante": "Incentive strength",
    "AllineamentoVirtu": "Alignment (net)", "AllineamentoVirtu_lordo": "Alignment (gross)",
    "VAN_min_EUR": "Minimum NPV", "InclusioneLIHC": "LIHC inclusion",
}
GRUPPO_INDICATORE = {
    "Gini": "Equality", "EI_orig": "Equality", "FairnessIndex": "Merit", "Sigma": "Merit",
    "EccessoMax_EUR": "Stability", "CoalizioniInstabili": "Stability",
    "ForzaIncentivante": "Incentive", "AllineamentoVirtu": "Incentive",
    "AllineamentoVirtu_lordo": "Incentive",
}


def nome_metodo(m: str) -> str:
    return METODI.get(m, (m, None))[0]


def famiglia(m: str) -> str:
    return METODI.get(m, (None, "Other"))[1]


def stile_metodo(m: str):
    """(colore, marker) della famiglia del metodo."""
    return FAMIGLIE.get(famiglia(m), (GRIGIO, "x"))


def nome_indicatore(i: str) -> str:
    return NOMI_INDICATORI.get(i, i)


def ordina_metodi(presenti) -> list[str]:
    presenti = list(dict.fromkeys(presenti))
    return [m for m in ORDINE_METODI if m in presenti] + sorted(set(presenti) - set(ORDINE_METODI))


def un_solo_shapley(df: pd.DataFrame, chiave=("Replica", "Composizione", "Scheda")) -> pd.DataFrame:
    """Regola dei metodi della versione B, su qualunque tabella con la colonna Metodo:
    - toglie il Nucleolo;
    - dove c'e' lo Shapley esatto toglie l'AS (lo duplica);
    - dove non c'e' rinomina l'AS in "Shapley" (lo stesso che fa unisci_shapley_as.m).
    Senza le colonne della chiave lavora sulla tabella intera."""
    if df is None or "Metodo" not in df:
        return df
    df = df[~df.Metodo.isin(ESCLUSI)]
    k = [c for c in chiave if c in df]
    if k:
        esatto = df.groupby(k).Metodo.transform(lambda s: "Shapley" in set(s))
    else:
        esatto = pd.Series("Shapley" in set(df.Metodo), index=df.index)
    df = df[~(esatto & (df.Metodo == AS))].copy()
    df.loc[df.Metodo == AS, "Metodo"] = "Shapley"
    return df


def gruppo_comunita(composizione: pd.Series) -> pd.Series:
    c = composizione.astype(str)
    return pd.Series(
        ["households only" if x == "PA0" else "with firms" if x.startswith("ND") else "with public buildings"
         for x in c], index=composizione.index)


# ---------------------------------------------------------------------------- figure
def imposta():
    plt.rcParams.update({
        "font.size": 8, "axes.titlesize": 8.5, "axes.labelsize": 8, "legend.fontsize": 7,
        "xtick.labelsize": 7, "ytick.labelsize": 7, "axes.spines.top": False,
        "axes.spines.right": False, "axes.edgecolor": "#888888", "axes.grid": True,
        "grid.color": "#E8E8E8", "grid.linewidth": 0.5, "axes.axisbelow": True,
        "text.color": INCHIOSTRO, "axes.labelcolor": INCHIOSTRO, "xtick.color": "#444444",
        "ytick.color": "#444444", "legend.frameon": False, "pdf.fonttype": 42, "ps.fonttype": 42,
        "savefig.bbox": "tight", "savefig.dpi": 200, "figure.dpi": 100,
    })


def salva(fig, cartella: Path, nome: str):
    """PNG (per il rapporto) e PDF vettoriale (per LaTeX)."""
    cartella.mkdir(parents=True, exist_ok=True)
    for ext in ("png", "pdf"):
        fig.savefig(cartella / f"{nome}.{ext}")
    plt.close(fig)
