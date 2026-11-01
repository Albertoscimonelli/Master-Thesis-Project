"""Aggrega le repliche dei partecipanti: quanto reggono i risultati quando cambiano le famiglie.

Legge le tabelle di MAIN2 di ogni replica (outputs/repliche/<blocco>/rNN/tables, scritte da
lancia_repliche.sh) e confronta:
  - le repliche r01..rNN fra loro: la variabilita' dovuta a QUALI famiglie entrano, a parita'
    di composizione ISTAT dichiarata;
  - le repliche con r00, l'identita': le schede di prima, con le famiglie di prima (tutte
    persone sole fino a 25 membri). La differenza misura quanto pesava quell'errore.

Per ogni risultato del rapporto si riporta il valore di r00, la mediana e l'intervallo sulle
repliche e, dove ha senso, in quante repliche regge (stesso vincitore, stesso segno del tau).

Uscite in outputs/repliche/<blocco>/aggregato/:
  vincitori.csv      vincitore per livello, indicatore, taglia e fascia
  tau.csv            tau-b medio fra coppie di indicatori, per fascia (livello base)
  inversioni.csv     quota di coppie di metodi invertite lungo penetrazione e taglia
  perdite.csv        perdita di trade-off fra criteri
  sufficienza.csv    insieme minimo di indicatori (rappresentante e concordanza)
  pareto.csv         quota di comunita' in cui un metodo sta sul fronte di Pareto
  composizione.csv   effetto di PA e imprese (inversioni e cambi di vincitore)
  varianza.csv       scomposizione della varianza dei punteggi: penetrazione, taglia,
                     interazione e partecipanti (variazione fra repliche dentro la cella)
  soglia.csv         soglia regolatoria (55% e 45%) su tutte le comunita' di tutte le repliche,
                     per gruppo (solo domestici, con PA, con imprese); soglia_per_replica.csv
  van.csv            VAN per metodo (analisi complementare): minimo, quota di membri sotto zero
  quote_prosumer.csv quota dell'incentivo ai prosumer per metodo, fascia e gruppo
  sensibilita.csv    quanto cambia il vincitore con la soglia di rilevanza
  fase1.csv          Shapley esatto contro Adaptive Sampling fino a 18 membri, per taglia
  esiti.csv          le conclusioni con un esito (segno di tau, vincitore, capovolgimento,
                     soglia) replica per replica
  robustezza.csv     per ogni conclusione: k/n, intervallo di Clopper-Pearson, verdetto
                     (regge >= 75%, si inverte <= 25%, altrimenti dipende dai partecipanti),
                     controllo a meta' (prima e seconda meta' delle repliche) e bootstrap
  sintesi.md         i numeri principali, in chiaro

Dal 1 novembre 2026 (versione B del piano, docs/analisi_finale/):
  - i metodi seguono stile_tesi.un_solo_shapley: niente Nucleolo, un solo "Shapley";
  - i risultati sono letti sulle repliche r01..rNN; r00 (persone sole) resta solo nei CSV,
    nella colonna r00, e in una sezione di confronto in fondo a sintesi.md;
  - le mediane hanno l'intervallo al 95% delle statistiche d'ordine (ic95_basso, ic95_alto).

Uso:  python -I CER_repliche/aggrega_repliche.py --blocco unito [--attese 21]
      python -I CER_repliche/aggrega_repliche.py --blocco unito --radice /tmp/banco   (prove)
"""
from __future__ import annotations

import argparse
import re
import sys
from math import comb
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
from stile_tesi import INDICATORI, gruppo_comunita, un_solo_shapley  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
LIVELLO = re.compile(r"^(PA\d+|ND\d+(_PA\d+)?)$")
REGGE, SI_INVERTE, FORTE = 0.75, 0.25, 0.85     # 15/20, 5/20, 17/20 (test del segno)
SOGLIE_REGOLATORIE = (0.55, 0.45)                # DM 414/2023: premio; premio + contributo


def repliche(cartella: Path) -> dict[int, Path]:
    out = {}
    for d in sorted(cartella.glob("r[0-9][0-9]")):
        if (d / "tables" / "sintesi").is_dir() and (d / "workspace.mat").exists():
            out[int(d.name[1:])] = d / "tables"
    return out


def livelli(tab: Path) -> dict[str, Path]:
    out = {"PA0": tab}
    for d in sorted(tab.iterdir()):
        if d.is_dir() and LIVELLO.match(d.name):
            out[d.name] = d
    return out


def leggi(tabs: dict[int, Path], rel: str, per_livello=False) -> pd.DataFrame:
    parti = []
    for r, t in tabs.items():
        sedi = livelli(t) if per_livello else {"PA0": t}
        for lv, d in sedi.items():
            f = d / rel
            if f.exists():
                parti.append(pd.read_csv(f).assign(Replica=r, Livello=lv))
    df = pd.concat(parti, ignore_index=True) if parti else pd.DataFrame()
    return un_solo_shapley(df, ("Replica", "Livello", "Scheda"))


def leggi_export(cart: Path, tabs, nome: str) -> pd.DataFrame:
    """Un CSV di export/ di tutte le repliche, con Replica, Gruppo e Fascia."""
    parti = [pd.read_csv(cart / f"r{r:02d}" / "export" / nome).assign(Replica=r) for r in tabs
             if (cart / f"r{r:02d}" / "export" / nome).exists()]
    if not parti:
        return pd.DataFrame()
    df = un_solo_shapley(pd.concat(parti, ignore_index=True))
    if "Composizione" in df:
        df["Gruppo"] = gruppo_comunita(df.Composizione)
    return df


def con_fascia(df: pd.DataFrame, com: pd.DataFrame) -> pd.DataFrame:
    """Fascia = rango della penetrazione dentro la taglia nel livello base (come MAIN2), portata
    alle varianti per nome di scheda, replica per replica."""
    base = com[com.Composizione == "PA0"][["Replica", "Scheda", "Membri", "Penetrazione_pct"]]
    base = base.assign(Fascia=base.groupby(["Replica", "Membri"]).Penetrazione_pct
                       .rank(method="dense").astype(int))
    out = df.merge(base[["Replica", "Scheda", "Fascia"]], on=["Replica", "Scheda"], how="left")
    out["Fascia"] = out.Fascia.astype("Int64").astype(str)     # "1".."4"; "tutte" nei riepiloghi
    return out


def ic_mediana(n: int, livello=0.95):
    """Ranghi (a, b) delle statistiche d'ordine che danno l'intervallo della mediana con
    copertura >= livello (binomiale con p = 1/2); None se n e' troppo piccolo."""
    best = None
    for a in range(1, n // 2 + 1):
        cop = sum(comb(n, j) for j in range(a, n - a + 1)) / 2 ** n
        if cop >= livello:
            best = (a, n + 1 - a)
    return best


def clopper_pearson(k: int, n: int, livello=0.95):
    """Intervallo esatto di una proporzione k/n (bisezione sulla binomiale, senza scipy)."""
    def cdf(x, p):
        return sum(comb(n, j) * p ** j * (1 - p) ** (n - j) for j in range(0, x + 1))
    a = (1 - livello) / 2
    def bis(f):
        lo, hi = 0.0, 1.0
        for _ in range(60):
            m = (lo + hi) / 2
            lo, hi = (lo, m) if f(m) else (m, hi)
        return (lo + hi) / 2
    basso = 0.0 if k == 0 else bis(lambda p: 1 - cdf(k - 1, p) >= a)
    alto = 1.0 if k == n else bis(lambda p: cdf(k, p) <= a)
    return basso, alto


def riassumi(df, chiave, col):
    """valore di r00, mediana, minimo, massimo e decili sulle repliche >= 1"""
    rep = df[df.Replica >= 1].groupby(chiave)[col]
    out = pd.DataFrame({"mediana": rep.median(), "min": rep.min(), "max": rep.max(),
                        "p10": rep.quantile(0.1), "p90": rep.quantile(0.9), "repliche": rep.count()})
    def ic(v, lato):
        v = np.sort(v.dropna().values)
        r = ic_mediana(len(v))
        return np.nan if r is None else v[r[lato] - 1]
    out["ic95_basso"] = rep.apply(lambda v: ic(v, 0))
    out["ic95_alto"] = rep.apply(lambda v: ic(v, 1))
    r0 = df[df.Replica == 0].set_index(chiave)[col].rename("r00")
    return out.join(r0, how="left").reset_index()


def moda(s):
    v = s.dropna()
    return v.mode().iloc[0] if len(v) else np.nan


# ---------------------------------------------------------------------------- blocchi
def insieme_vincitori(V):
    """'Vincitore' vale '(pari)' quando piu' metodi sono primi entro la tolleranza: il
    vincitore si confronta come INSIEME dei primi a pari merito (PrimiAPari), ordinato."""
    s = V.PrimiAPari.where(V.PrimiAPari.notna(), V.Vincitore)
    return s.map(lambda x: x if pd.isna(x) else " = ".join(sorted(str(x).split(" = "))))


def vincitori(tabs):
    V = leggi(tabs, "confronto/griglia_vincitori.csv", per_livello=True)
    V = V[V.Indicatore.isin(INDICATORI)].assign(Primi=lambda d: insieme_vincitori(d))
    chiave = ["Livello", "Indicatore", "Membri", "Fascia"]
    rep = V[V.Replica >= 1]
    g = rep.groupby(chiave).Primi
    out = pd.DataFrame({"Modale": g.agg(moda), "repliche": g.count()})
    out["QuotaModale"] = rep.groupby(chiave).apply(
        lambda d: (d.Primi == moda(d.Primi)).mean(), include_groups=False)
    r0 = V[V.Replica == 0].set_index(chiave).Primi.rename("Primi_r00")
    out = out.join(r0, how="left")
    j = rep.join(r0, on=chiave)
    out["QuotaUgualeR00"] = j.groupby(chiave).apply(
        lambda d: (d.Primi == d.Primi_r00).mean(), include_groups=False)
    # meno severo: almeno un metodo in comune fra i primi della replica e quelli di r00
    out["QuotaInComuneR00"] = j.groupby(chiave).apply(lambda d: np.mean([
        bool(set(str(a).split(" = ")) & set(str(b).split(" = "))) for a, b in zip(d.Primi, d.Primi_r00)]),
        include_groups=False)
    out["ModaleUgualeR00"] = out.Modale == out.Primi_r00
    return out.reset_index()


def tau(tabs):
    T = leggi(tabs, "sintesi/tau_per_fascia.csv")
    T = T[T.IndicatoreA.isin(INDICATORI) & T.IndicatoreB.isin(INDICATORI)]
    chiave = ["IndicatoreA", "IndicatoreB", "Fascia"]
    out = riassumi(T, chiave, "TauMedio")
    rep = T[T.Replica >= 1].merge(out[chiave + ["mediana", "r00"]], on=chiave)
    q = rep.groupby(chiave).apply(lambda d: pd.Series({
        "QuotaSegnoMediana": (np.sign(d.TauMedio) == np.sign(d.mediana)).mean(),
        "QuotaSegnoR00": (np.sign(d.TauMedio) == np.sign(d.r00)).mean()}), include_groups=False)
    return out.merge(q.reset_index(), on=chiave)


def inversioni(tabs):
    I = leggi(tabs, "confronto/inversioni_per_sweep.csv")
    return riassumi(I, ["Sweep", "Fisso"], "QuotaInvertite")


def perdite(tabs):
    P = leggi(tabs, "sintesi/perdite_tradeoff.csv")
    P = P[P.Scelto.isin(INDICATORI) & P.Perde.isin(INDICATORI)]
    a = riassumi(P, ["Scelto", "Perde"], "PerditaOttimistica_medio")
    b = riassumi(P, ["Scelto", "Perde"], "Perdita_EUR_ott_medio")[["Scelto", "Perde", "mediana", "r00"]]
    return a.merge(b.rename(columns={"mediana": "EUR_mediana", "r00": "EUR_r00"}), on=["Scelto", "Perde"])


def sufficienza(tabs):
    S = leggi(tabs, "sintesi/cluster_sufficienza.csv")
    chiave = ["TaglioTau", "Indicatore"]
    out = riassumi(S, chiave, "ConcordanzaCoppie")
    r0 = S[S.Replica == 0].set_index(chiave).Rappresentante.rename("Rappresentante_r00")
    rep = S[S.Replica >= 1].join(r0, on=chiave)
    q = rep.groupby(chiave).apply(lambda d: pd.Series({
        "RappresentanteModale": moda(d.Rappresentante),
        "QuotaRappresentanteR00": (d.Rappresentante == d.Rappresentante_r00).mean()}),
        include_groups=False)
    return out.merge(r0.reset_index(), on=chiave, how="left").merge(q.reset_index(), on=chiave)


def pareto(tabs):
    P = leggi(tabs, "sintesi/pareto_conteggi.csv")
    return riassumi(P, ["InsiemeCriteri", "Metodo"], "QuotaSulFronte")


def composizione(tabs):
    C = leggi(tabs, "confronto_PA/pa_sommario.csv")
    C = C[C.Indicatore.isin(INDICATORI)]
    a = riassumi(C, ["Indicatore", "Confronto"], "QuotaInvertite")
    b = riassumi(C, ["Indicatore", "Confronto"], "QuotaVincitoreCambia")
    return a.merge(b, on=["Indicatore", "Confronto"], suffixes=("_inv", "_vinc"))


def varianza(tabs):
    """Punteggio = 1 - rimpianto (come F06 di grafici_metodi.py), livello base.
    Con le repliche la cella (fascia x taglia) ha piu' osservazioni: si separano
    penetrazione, taglia, la loro interazione e la variazione dentro la cella, che e'
    l'effetto dei partecipanti. Quote della somma dei quadrati, pesate per SST sui metodi."""
    R = leggi(tabs, "sintesi/rimpianto_per_comunita.csv")
    R = R[R.Indicatore.isin(INDICATORI)].assign(Punteggio=lambda d: 1 - d.Rimpianto)
    # come grafici_metodi: dove c'e' lo Shapley esatto l'AS e' un duplicato
    R = R[R.Metodo != "Adaptive Sampling Shapley"]
    righe = []
    for (m, i), s in R[R.Replica >= 1].groupby(["Metodo", "Indicatore"]):
        y = s.pivot_table(index=["Fascia", "Membri"], columns="Replica", values="Punteggio")
        if y.isna().any().any() or y.shape[1] < 2:
            continue
        gm = y.values.mean()
        sst = ((y.values - gm) ** 2).sum()
        if sst < 1e-12:
            continue
        nr = y.shape[1]
        cel = y.mean(axis=1).unstack("Membri")          # medie di cella: fascia x taglia
        if cel.isna().any().any():
            continue
        ssf = nr * cel.shape[1] * ((cel.mean(axis=1) - gm) ** 2).sum()
        ssn = nr * cel.shape[0] * ((cel.mean(axis=0) - gm) ** 2).sum()
        sscel = nr * ((cel.values - gm) ** 2).sum()
        ssw = ((y.values - y.values.mean(axis=1, keepdims=True)) ** 2).sum()
        righe.append((m, i, ssf / sst, ssn / sst, (sscel - ssf - ssn) / sst, ssw / sst, sst))
    V = pd.DataFrame(righe, columns=["Metodo", "Indicatore", "penetrazione", "taglia",
                                     "interazione", "partecipanti", "SST"])
    pes = V.groupby("Indicatore").apply(lambda d: pd.Series(
        {c: np.average(d[c], weights=d.SST) for c in ["penetrazione", "taglia", "interazione", "partecipanti"]}),
        include_groups=False).reindex(INDICATORI)
    # r00 da sola: two-way senza repliche, come F06 (l'interazione resta nel residuo)
    r0 = []
    for (m, i), s in R[R.Replica == 0].groupby(["Metodo", "Indicatore"]):
        y = s.pivot_table(index="Fascia", columns="Membri", values="Punteggio")
        if y.isna().any().any():
            continue
        gm = y.values.mean(); sst = ((y.values - gm) ** 2).sum()
        if sst < 1e-12:
            continue
        r0.append((m, i, y.shape[1] * ((y.mean(axis=1) - gm) ** 2).sum() / sst,
                   y.shape[0] * ((y.mean(axis=0) - gm) ** 2).sum() / sst, sst))
    V0 = pd.DataFrame(r0, columns=["Metodo", "Indicatore", "penetrazione", "taglia", "SST"])
    p0 = V0.groupby("Indicatore").apply(lambda d: pd.Series(
        {f"{c}_r00": np.average(d[c], weights=d.SST) for c in ["penetrazione", "taglia"]}),
        include_groups=False).reindex(INDICATORI)
    return pes.join(p0).reset_index().rename(columns={"index": "Indicatore"}), V


# ---------------------------------------------------------------------------- analisi aggiunte
def soglia(com):
    """Soglia sull'energia incentivata (QuotaIncentivata = condivisa / immessa), su tutte le
    comunita' di tutte le repliche >= 1, per gruppo. La soglia conta per le IMPRESE: nelle
    comunita' senza imprese superarla non sposta nulla, e va detto separatamente."""
    c = com[com.Replica >= 1]
    righe = []
    for g, s in c.groupby("Gruppo"):
        r = {"Gruppo": g, "Comunita": len(s), "Repliche": s.Replica.nunique(),
             "QuotaMax": s.QuotaIncentivata.max(), "QuotaMediana": s.QuotaIncentivata.median(),
             "Binding": int(s.Binding.sum())}
        for t in SOGLIE_REGOLATORIE:
            sopra = s[s.QuotaIncentivata > t]
            r[f"Sopra{int(100 * t)}"] = len(sopra)
            r[f"RepliceConAlmenoUnaSopra{int(100 * t)}"] = sopra.Replica.nunique()
            r[f"TaglieSopra{int(100 * t)}"] = " ".join(map(str, sorted(sopra.Membri.unique())))
        righe.append(r)
    per_rep = (c.groupby(["Replica", "Gruppo"])
                .agg(Comunita=("Scheda", "size"), QuotaMax=("QuotaIncentivata", "max"),
                     Sopra55=("QuotaIncentivata", lambda v: int((v > 0.55).sum())))
                .reset_index())
    return pd.DataFrame(righe), per_rep


def van(qm, com):
    """VAN per metodo (analisi complementare): per comunita' e metodo il VAN minimo fra i membri,
    la quota di membri con VAN negativo e il VAN mediano; poi la distribuzione fra comunita'
    e repliche per metodo, gruppo e fascia (fascia solo nel livello base)."""
    q = qm[(qm.Replica >= 1) & qm.VAN_EUR.notna()]
    per = (q.groupby(["Replica", "Composizione", "Gruppo", "Scheda", "Membri", "Metodo"])
             .agg(VAN_min=("VAN_EUR", "min"), QuotaNegativi=("VAN_EUR", lambda v: (v < 0).mean()),
                  VAN_mediano=("VAN_EUR", "median")).reset_index())
    per = con_fascia(per, com)
    def dist(d, chiave):
        g = d.groupby(chiave)
        return pd.DataFrame({
            "Comunita": g.size(), "VAN_min_mediana": g.VAN_min.median(),
            "VAN_min_p10": g.VAN_min.quantile(0.1), "VAN_min_p90": g.VAN_min.quantile(0.9),
            "QuotaComunitaConNegativi": g.VAN_min.apply(lambda v: (v < 0).mean()),
            "QuotaNegativi_mediana": g.QuotaNegativi.median()}).reset_index()
    a = dist(per, ["Metodo", "Gruppo"]).assign(Fascia="tutte")
    b = dist(per[per.Composizione == "PA0"], ["Metodo", "Fascia"]).assign(Gruppo="households only")
    return pd.concat([a, b], ignore_index=True), per


def quote_prosumer(qm, com):
    """Quota dell'incentivo che va ai prosumer, e rapporto con la loro quota di membri (1 = in
    proporzione al numero), per metodo; nel livello base anche per fascia."""
    q = qm[qm.Replica >= 1].assign(QP=lambda d: d.Quota_EUR * d.Prosumer)
    per = (q.groupby(["Replica", "Composizione", "Gruppo", "Scheda", "Membri", "Metodo"])
             .agg(QP=("QP", "sum"), Tot=("Quota_EUR", "sum"), NP=("Prosumer", "sum"),
                  N=("Prosumer", "size")).reset_index())
    per = per.assign(QuotaProsumer=per.QP / per.Tot, Rapporto=(per.QP / per.Tot) / (per.NP / per.N))
    per = con_fascia(per, com)
    def dist(d, chiave):
        g = d.groupby(chiave)
        return pd.DataFrame({"Comunita": g.size(), "QuotaProsumer_mediana": g.QuotaProsumer.median(),
                             "QuotaProsumer_p10": g.QuotaProsumer.quantile(0.1),
                             "QuotaProsumer_p90": g.QuotaProsumer.quantile(0.9),
                             "Rapporto_mediana": g.Rapporto.median()}).reset_index()
    base = per[(per.Composizione == "PA0") & (per.NP < per.N)]     # al 100% la quota vale 1
    return pd.concat([dist(base, ["Metodo", "Fascia"]).assign(Gruppo="households only"),
                      dist(per[per.NP < per.N], ["Metodo", "Gruppo"]).assign(Fascia="tutte")],
                     ignore_index=True)


def sensibilita(tabs):
    """Soglia di rilevanza (pareggi): quota di celle in cui il vincitore cambia rispetto alla
    soglia di MAIN2, e celle in cui un metodo diverso prende il primo posto."""
    S = leggi(tabs, "sintesi/sensibilita_soglia_vincitori.csv")
    if not len(S):
        return pd.DataFrame()
    S = S.assign(QuotaCambiata=S.VincitoreDiversoDaMAIN2 / S.Celle)
    a = riassumi(S, ["FracEscursione", "FracVN"], "QuotaCambiata")
    b = S[S.Replica >= 1].groupby(["FracEscursione", "FracVN"]).AltroMetodoPrimo.max().rename(
        "AltroMetodoPrimo_max")
    return a.merge(b.reset_index(), on=["FracEscursione", "FracVN"])


def fase1(tabs):
    F = leggi(tabs, "fase1/regime_le18_Shapley_vs_AS_per_taglia.csv")
    if not len(F):
        return pd.DataFrame()
    parti = [riassumi(F, ["Membri"], c).assign(Misura=c)
             for c in ("RD_medio_pct", "RD_max_pct", "L1_su_vN_pct", "Spearman_rho_min")]
    return pd.concat(parti, ignore_index=True)


# ---------------------------------------------------------------------------- robustezza
def esiti(A, com):
    """Le conclusioni che hanno un esito (vero/falso) in ogni replica >= 1, in formato lungo:
    Tipo, Conclusione, Replica, Esito. L'esito atteso e' fissato dalle repliche stesse (segno
    della mediana, vincitore piu' frequente), non da r00."""
    righe = []
    # 1. segno del tau medio per coppia di indicatori e fascia (livello base)
    T = A["tau_grezzo"]
    T = T[(T.Replica >= 1) & T.IndicatoreA.isin(INDICATORI) & T.IndicatoreB.isin(INDICATORI)]
    for (a, b, f), s in T.groupby(["IndicatoreA", "IndicatoreB", "Fascia"]):
        med = s.TauMedio.median()
        if abs(med) < 0.05:          # nessun legame: non e' una conclusione con un segno
            continue
        segno = "positivo" if med > 0 else "negativo"
        for _, r in s.iterrows():
            righe.append(("tau", f"tau({a}, {b}) {segno} in fascia {f}", r.Replica,
                          bool(np.sign(r.TauMedio) == np.sign(med))))
    # 2. vincitore piu' frequente di ogni cella (livello base, pari compresi)
    V = A["vincitori_grezzo"]
    V = V[(V.Replica >= 1) & (V.Livello == "PA0") & V.Indicatore.isin(INDICATORI)]
    V = V.assign(Primi=insieme_vincitori(V)).dropna(subset=["Primi"])
    for (i, n, f), s in V.groupby(["Indicatore", "Membri", "Fascia"]):
        m = s.Primi.str.split(" = ").explode().value_counts().index[0]
        for _, r in s.iterrows():
            righe.append(("vincitore", f"{m} fra i primi su {i}, {n} membri, fascia {f}", r.Replica,
                          m in r.Primi.split(" = ")))
    # 3. il capovolgimento con la penetrazione (risultato centrale del rapporto del 28/10)
    def tau_rep(a, b, fascia):
        s = T[(((T.IndicatoreA == a) & (T.IndicatoreB == b)) | ((T.IndicatoreA == b) & (T.IndicatoreB == a)))
              & (T.Fascia == fascia)]
        return s.groupby("Replica").TauMedio.first()
    if len(T):
        fmax = int(T.Fascia.max())
        g1, g4 = tau_rep("Gini", "ForzaIncentivante", 1), tau_rep("Gini", "ForzaIncentivante", fmax)
        m1, m3 = tau_rep("FairnessIndex", "ForzaIncentivante", 1), tau_rep("FairnessIndex", "ForzaIncentivante", 3)
        for r in g1.index.intersection(g4.index):
            righe.append(("capovolgimento", f"tau(Gini, IS) scende di almeno 0,3 dalla fascia 1 alla {fmax}",
                          r, bool(g4[r] - g1[r] <= -0.3)))
        for r in m1.index.intersection(m3.index):
            righe.append(("capovolgimento", "tau(FI, IS) negativo in fascia 1 e positivo in fascia 3",
                          r, bool(m1[r] < 0 and m3[r] > 0)))
    # 4. soglia regolatoria: mai superata dove ci sono imprese
    c = com[com.Replica >= 1]
    for r, s in c.groupby("Replica"):
        imp = s[s.Gruppo == "with firms"]
        if len(imp):
            righe.append(("soglia", "nessuna comunita' con imprese sopra il 55%", r,
                          bool((imp.QuotaIncentivata <= 0.55).all())))
    return pd.DataFrame(righe, columns=["Tipo", "Conclusione", "Replica", "Esito"])


def verdetto(k, n):
    if n == 0:
        return "n.d."
    q = k / n
    return "regge" if q >= REGGE else "si inverte" if q <= SI_INVERTE else "dipende dai partecipanti"


def robustezza(E, n_boot=1000, seme=20261101):
    """Per ogni conclusione: k/n, intervallo di Clopper-Pearson, verdetto (soglie REGGE e
    SI_INVERTE), 'forte' se k/n >= FORTE; controllo a meta' (prima e seconda meta' delle
    repliche in ordine di numero) e quota dei ricampionamenti bootstrap con lo stesso verdetto."""
    rng = np.random.default_rng(seme)
    righe = []
    for (t, c), s in E.groupby(["Tipo", "Conclusione"], sort=False):
        s = s.sort_values("Replica")
        x = s.Esito.values.astype(int)
        n, k = len(x), int(x.sum())
        lo, hi = clopper_pearson(k, n)
        v = verdetto(k, n)
        h = n // 2
        v1, v2 = verdetto(int(x[:h].sum()), h), verdetto(int(x[h:].sum()), n - h)
        if n_boot and n:
            kb = x[rng.integers(0, n, size=(n_boot, n))].sum(axis=1)
            boot = np.mean([verdetto(int(b), n) == v for b in kb])
        else:
            boot = np.nan
        righe.append({"Tipo": t, "Conclusione": c, "k": k, "n": n, "Quota": k / n if n else np.nan,
                      "IC95_basso": lo, "IC95_alto": hi, "Verdetto": v, "Forte": bool(n and k / n >= FORTE),
                      "Verdetto_prima_meta": v1, "Verdetto_seconda_meta": v2,
                      "MetaConcordi": v1 == v2, "Bootstrap_stesso_verdetto": boot})
    return pd.DataFrame(righe)


# ---------------------------------------------------------------------------- sintesi
def pc(x, d=0):
    return "n.d." if pd.isna(x) else f"{100 * x:.{d}f}%".replace(".", ",")


def nn(x, d=2):
    return "n.d." if pd.isna(x) else f"{x:.{d}f}".replace(".", ",")


def kn(r):
    """'18/20 (68-99%)' da una riga di robustezza.csv"""
    return f"{int(r.k)}/{int(r.n)} ({pc(r.IC95_basso)}-{pc(r.IC95_alto)})"


def mic(r):
    """'0,42 [0,31; 0,50]': mediana e intervallo al 95% della mediana"""
    return f"{nn(r.mediana)} [{nn(r.ic95_basso)}; {nn(r.ic95_alto)}]"


def scrivi_sintesi(blocco, tabs, A, dest):
    rep = sorted(r for r in tabs if r >= 1)
    R = A["robustezza"]
    L = [f"# Repliche dei partecipanti, blocco {blocco}", "",
         f"Repliche analizzate: {len(rep)} ({', '.join(f'r{r:02d}' for r in rep)}). "
         "r00 (persone sole) non entra nei risultati: e' solo nell'ultima sezione, come confronto.", "",
         f"Regola di lettura: una conclusione **regge** se vale in almeno il {pc(REGGE)} delle repliche "
         f"(15/20, test del segno a due code p = 0,041), **si inverte** se vale in al piu' il {pc(SI_INVERTE)}, "
         f"altrimenti **dipende dai partecipanti**. **Forte**: almeno il {pc(FORTE)} (17/20). "
         "Fra parentesi l'intervallo esatto di Clopper-Pearson al 95%; per le mediane, fra quadre, "
         "l'intervallo al 95% delle statistiche d'ordine.", ""]

    # ---- quante repliche bastano
    if len(R):
        L += ["## Il numero di repliche basta?", "",
              "| Tipo di conclusione | Conclusioni | Reggono | Forti | Dipendono | Si invertono | Meta' concordi | Bootstrap: stesso verdetto (mediana) |",
              "|---|---|---|---|---|---|---|---|"]
        for t, s in R.groupby("Tipo", sort=False):
            L.append(f"| {t} | {len(s)} | {(s.Verdetto == 'regge').sum()} | {s.Forte.sum()} | "
                     f"{(s.Verdetto == 'dipende dai partecipanti').sum()} | {(s.Verdetto == 'si inverte').sum()} | "
                     f"{s.MetaConcordi.sum()}/{len(s)} | {pc(s.Bootstrap_stesso_verdetto.median())} |")
        L.append(f"| **tutte** | {len(R)} | {(R.Verdetto == 'regge').sum()} | {R.Forte.sum()} | "
                 f"{(R.Verdetto == 'dipende dai partecipanti').sum()} | {(R.Verdetto == 'si inverte').sum()} | "
                 f"{R.MetaConcordi.sum()}/{len(R)} | {pc(R.Bootstrap_stesso_verdetto.median())} |")

    # ---- risultato centrale
    c = R[R.Tipo.isin(["capovolgimento", "soglia"])] if len(R) else R
    if len(c):
        L += ["", "## Capovolgimento con la penetrazione e soglia regolatoria", "",
              "| Conclusione | Repliche | Verdetto | Meta' concordi |", "|---|---|---|---|"]
        for _, r in c.iterrows():
            L.append(f"| {r.Conclusione} | {kn(r)} | {r.Verdetto}{' (forte)' if r.Forte else ''} | "
                     f"{'si' if r.MetaConcordi else 'no'} |")

    # ---- poli
    V = A["vincitori_grezzo"]
    V0 = V[(V.Livello == "PA0") & (V.Replica >= 1)].assign(Primi=lambda d: insieme_vincitori(d))
    L += ["", "## Chi vince (livello base: quota delle celle in cui il metodo e' fra i primi, pari compresi)", "",
          "| Indicatore | Primi tre metodi, tutte le celle di tutte le repliche |", "|---|---|"]
    for i in INDICATORI:
        s = V0[V0.Indicatore == i].dropna(subset=["Primi"])
        if len(s):
            q = s.Primi.str.split(" = ").explode().value_counts().div(len(s)).head(3)
            L.append(f"| {i} | {', '.join(f'{k} {pc(v)}' for k, v in q.items())} |")
    v = A["vincitori"]
    L += ["", "| Indicatore | Celle | Repliche col vincitore modale (media) |", "|---|---|---|"]
    for i in INDICATORI:
        s = v[v.Indicatore == i]
        if len(s):
            L.append(f"| {i} | {len(s)} | {pc(s.QuotaModale.mean())} |")

    # ---- tau
    t = A["tau"]
    L += ["", "## Accordo fra criteri (tau-b medio per fascia, livello base)", "",
          "| Coppia | Fascia | Mediana [IC 95%] | Min / max | Repliche col segno della mediana |",
          "|---|---|---|---|---|"]
    for a, b in [("Gini", "ForzaIncentivante"), ("FairnessIndex", "ForzaIncentivante"),
                 ("Gini", "FairnessIndex"), ("FairnessIndex", "EccessoMax_EUR")]:
        s = t[((t.IndicatoreA == a) & (t.IndicatoreB == b)) | ((t.IndicatoreA == b) & (t.IndicatoreB == a))]
        for _, r in s.sort_values("Fascia").iterrows():
            L.append(f"| {a} - {b} | {r.Fascia} | {mic(r)} | {nn(r['min'])} / {nn(r['max'])} | "
                     f"{pc(r.QuotaSegnoMediana)} |")

    # ---- inversioni, varianza, composizione, perdite
    iv = A["inversioni"]
    L += ["", "## Inversioni di graduatoria lungo gli assi", "",
          "| Asse | Fisso | Mediana [IC 95%] | Min-max |", "|---|---|---|---|"]
    for _, r in iv.iterrows():
        L.append(f"| {r.Sweep} | {r.Fisso} | {pc(r.mediana)} [{pc(r.ic95_basso)}; {pc(r.ic95_alto)}] | "
                 f"{pc(r['min'])}-{pc(r['max'])} |")
    va = A["varianza"]
    L += ["", "## Da cosa dipendono i punteggi (quota della varianza, livello base)", "",
          "| Indicatore | Penetrazione | Taglia | Interazione | Partecipanti |", "|---|---|---|---|---|"]
    for _, r in va.iterrows():
        L.append(f"| {r.Indicatore} | {pc(r.penetrazione)} | {pc(r.taglia)} | {pc(r.interazione)} | "
                 f"{pc(r.partecipanti)} |")
    co = A["composizione"]
    if len(co):
        L += ["", "## Composizione (PA e imprese) rispetto al livello base", "",
              "| Confronto | Coppie invertite (mediana) | Vincitore cambia (mediana) |", "|---|---|---|"]
        for cc, s in co.groupby("Confronto"):
            L.append(f"| {cc} | {pc(s.mediana_inv.mean())} | {pc(s.mediana_vinc.mean())} |")
    pe = A["perdite"]
    L += ["", "## Perdite di trade-off principali (perdita ottimistica media)", "",
          "| Si sceglie | Si perde | Mediana [IC 95%] | Min-max |", "|---|---|---|---|"]
    for a, b in [("Gini", "EccessoMax_EUR"), ("Gini", "ForzaIncentivante"), ("ForzaIncentivante", "Gini"),
                 ("FairnessIndex", "EccessoMax_EUR"), ("EccessoMax_EUR", "FairnessIndex")]:
        for _, r in pe[(pe.Scelto == a) & (pe.Perde == b)].iterrows():
            L.append(f"| {a} | {b} | {mic(r)} | {nn(r['min'])}-{nn(r['max'])} |")

    # ---- insieme ridotto e Pareto
    su = A["sufficienza"]
    if len(su):
        L += ["", "## Insieme ridotto di indicatori", "",
              "| Taglio di tau | Indicatore | Rappresentante modale | Concordanza delle coppie (mediana, min) |",
              "|---|---|---|---|"]
        for _, r in su.sort_values(["TaglioTau", "Indicatore"], ascending=[False, True]).iterrows():
            L.append(f"| {r.TaglioTau} | {r.Indicatore} | {r.RappresentanteModale} | "
                     f"{nn(r.mediana)}, {nn(r['min'])} |")
    pa = A["pareto"]
    if len(pa):
        L += ["", "## Fronte di Pareto (quota di comunita' in cui il metodo non e' dominato, mediana)", "",
              "| Insieme di criteri | Metodi con quota mediana >= 50% |", "|---|---|"]
        for k, s in pa.groupby("InsiemeCriteri"):
            m = s[s.mediana >= 0.5].sort_values("mediana", ascending=False)
            L.append(f"| {k} | {', '.join(f'{x} {pc(y)}' for x, y in zip(m.Metodo, m.mediana)) or '-'} |")

    # ---- soglia, VAN, quote ai prosumer, sensibilita', fase 1
    so = A["soglia"]
    if len(so):
        L += ["", "## Soglia regolatoria (energia condivisa / immessa)", "",
              "| Gruppo | Comunita' | Max | Mediana | Sopra 55% | Repliche con almeno una sopra 55% | Taglie sopra 55% |",
              "|---|---|---|---|---|---|---|"]
        for _, r in so.iterrows():
            L.append(f"| {r.Gruppo} | {r.Comunita} | {pc(r.QuotaMax, 1)} | {pc(r.QuotaMediana, 1)} | {r.Sopra55} | "
                     f"{r.RepliceConAlmenoUnaSopra55} | {r.TaglieSopra55 or '-'} |")
    vn = A["van"]
    if len(vn):
        s = vn[vn.Fascia == "tutte"]
        L += ["", "## VAN per metodo (analisi complementare, tutte le comunita')", "",
              "| Metodo | Gruppo | VAN minimo, mediana [p10; p90] EUR | Comunita' con almeno un VAN negativo |",
              "|---|---|---|---|"]
        for _, r in s.iterrows():
            L.append(f"| {r.Metodo} | {r.Gruppo} | {nn(r.VAN_min_mediana, 0)} [{nn(r.VAN_min_p10, 0)}; "
                     f"{nn(r.VAN_min_p90, 0)}] | {pc(r.QuotaComunitaConNegativi)} |")
    qp = A["quote_prosumer"]
    if len(qp):
        s = qp[(qp.Gruppo == "households only") & (qp.Fascia != "tutte")]
        L += ["", "## Quota dell'incentivo ai prosumer (livello base, mediana per fascia)", "",
              "| Metodo | " + " | ".join(f"Fascia {f}" for f in sorted(s.Fascia.unique())) + " |",
              "|---|" + "---|" * s.Fascia.nunique()]
        for m, x in s.groupby("Metodo"):
            L.append(f"| {m} | " + " | ".join(pc(y) for y in x.sort_values("Fascia").QuotaProsumer_mediana) + " |")
    se = A["sensibilita"]
    if len(se):
        L += ["", "## Sensibilita' alla soglia di rilevanza (livello base)", "",
              "| Escursione | Frazione di v(N) | Celle col vincitore cambiato (mediana, max) | Altro metodo primo (max) |",
              "|---|---|---|---|"]
        for _, r in se.iterrows():
            L.append(f"| {r.FracEscursione} | {r.FracVN} | {pc(r.mediana)}, {pc(r['max'])} | {int(r.AltroMetodoPrimo_max)} |")
    f1 = A["fase1"]
    if len(f1):
        L += ["", "## Shapley esatto contro Adaptive Sampling (fino a 18 membri)", "",
              "| Membri | Scarto relativo medio % (mediana) | Scarto massimo % (max) | Spearman minimo (min) |",
              "|---|---|---|---|"]
        p = f1.pivot_table(index="Membri", columns="Misura", values=["mediana", "max", "min"])
        for n_, r in p.iterrows():
            L.append(f"| {n_} | {nn(r[('mediana', 'RD_medio_pct')])} | {nn(r[('max', 'RD_max_pct')])} | "
                     f"{nn(r[('min', 'Spearman_rho_min')])} |")

    # ---- appendice: r00
    L += ["", "## Appendice: confronto con r00 (assegnazione originale, persone sole)", "",
          "Non e' un risultato: dice solo cosa cambiava con l'errore di assegnazione delle famiglie.", "",
          "| Coppia | Fascia | r00 | Mediana delle repliche |", "|---|---|---|---|"]
    for a, b in [("Gini", "ForzaIncentivante"), ("FairnessIndex", "ForzaIncentivante")]:
        s = t[((t.IndicatoreA == a) & (t.IndicatoreB == b)) | ((t.IndicatoreA == b) & (t.IndicatoreB == a))]
        for _, r in s.sort_values("Fascia").iterrows():
            L.append(f"| {a} - {b} | {r.Fascia} | {nn(r.r00)} | {nn(r.mediana)} |")
    dest.write_text("\n".join(L) + "\n", encoding="utf-8")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--blocco", required=True)
    ap.add_argument("--radice", default=str(ROOT / "outputs" / "repliche"),
                    help="cartella che contiene <blocco>/rNN (per le prove: quella di banco_prova.py)")
    ap.add_argument("--attese", type=int, default=None,
                    help="numero di repliche atteso, r00 compresa: si ferma se ne mancano (21 a run finito)")
    ap.add_argument("--bootstrap", type=int, default=1000)
    a = ap.parse_args(argv)
    cart = Path(a.radice) / a.blocco
    tabs = repliche(cart)
    if a.attese is not None and len(tabs) < a.attese:
        manca = sorted(set(range(a.attese)) - set(tabs))
        raise SystemExit(f"{cart}: {len(tabs)} repliche complete su {a.attese}; mancano "
                         + ", ".join(f"r{r:02d}" for r in manca))
    assert any(r >= 1 for r in tabs), f"nessuna replica completa in {cart}"
    dest = cart / "aggregato"
    dest.mkdir(exist_ok=True)
    com = leggi_export(cart, tabs, "comunita.csv")
    qm = leggi_export(cart, tabs, "quote_membri.csv")
    A = {"vincitori": vincitori(tabs), "tau": tau(tabs), "inversioni": inversioni(tabs),
         "perdite": perdite(tabs), "sufficienza": sufficienza(tabs), "pareto": pareto(tabs),
         "composizione": composizione(tabs), "sensibilita": sensibilita(tabs), "fase1": fase1(tabs)}
    A["varianza"], dettaglio = varianza(tabs)
    if len(com):
        A["soglia"], soglia_rep = soglia(com)
        soglia_rep.to_csv(dest / "soglia_per_replica.csv", index=False)
        com.to_csv(dest / "comunita_tutte.csv", index=False)
    else:
        A["soglia"] = pd.DataFrame()
    if len(qm):
        A["van"], van_per = van(qm, com)
        van_per.to_csv(dest / "van_per_comunita.csv", index=False)
        A["quote_prosumer"] = quote_prosumer(qm, com)
    else:
        A["van"] = A["quote_prosumer"] = pd.DataFrame()
    A["tau_grezzo"] = leggi(tabs, "sintesi/tau_per_fascia.csv")
    A["vincitori_grezzo"] = leggi(tabs, "confronto/griglia_vincitori.csv", per_livello=True)
    # dati replica per replica, per le figure (grafici_repliche.py)
    V0 = A["vincitori_grezzo"]
    V0 = V0[(V0.Livello == "PA0") & (V0.Replica >= 1) & V0.Indicatore.isin(INDICATORI)]
    V0 = V0.assign(Primi=insieme_vincitori(V0)).dropna(subset=["Primi"])
    celle = V0.groupby(["Replica", "Indicatore", "Membri"]).size().rename("Celle")
    poli = (V0.assign(Metodo=V0.Primi.str.split(" = ")).explode("Metodo")
              .groupby(["Replica", "Indicatore", "Membri", "Metodo"]).size().rename("CelleFraIPrimi")
              .reset_index().join(celle, on=["Replica", "Indicatore", "Membri"]))
    poli.to_csv(dest / "poli_per_replica.csv", index=False)
    T0 = A["tau_grezzo"]
    T0[(T0.Replica >= 1) & T0.IndicatoreA.isin(INDICATORI) & T0.IndicatoreB.isin(INDICATORI)].to_csv(
        dest / "tau_per_replica.csv", index=False)
    leggi(tabs, "confronto/inversioni_per_sweep.csv").query("Replica >= 1").to_csv(
        dest / "inversioni_per_replica.csv", index=False)
    E = esiti(A, com if len(com) else pd.DataFrame(columns=["Replica", "Gruppo", "QuotaIncentivata"]))
    A["esiti"] = E
    A["robustezza"] = robustezza(E, a.bootstrap) if len(E) else pd.DataFrame()
    for k, df in A.items():
        if k not in ("tau_grezzo", "vincitori_grezzo"):
            df.to_csv(dest / f"{k}.csv", index=False)
    dettaglio.to_csv(dest / "varianza_per_metodo.csv", index=False)
    scrivi_sintesi(a.blocco, tabs, A, dest / "sintesi.md")
    print(f"{len(tabs)} repliche lette (r00 {'presente' if 0 in tabs else 'assente'}); uscite in {dest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
