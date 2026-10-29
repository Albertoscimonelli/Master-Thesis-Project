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
  sintesi.md         i numeri principali, in chiaro

Uso:  python -I CER_repliche/aggrega_repliche.py --blocco fino15
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
INDICATORI = ["Gini", "FairnessIndex", "Sigma", "EccessoMax_EUR", "CoalizioniInstabili",
              "ForzaIncentivante", "AllineamentoVirtu", "AllineamentoVirtu_lordo"]
LIVELLO = re.compile(r"^(PA\d+|ND\d+(_PA\d+)?)$")


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
    return pd.concat(parti, ignore_index=True) if parti else pd.DataFrame()


def riassumi(df, chiave, col):
    """valore di r00, mediana, minimo, massimo e decili sulle repliche >= 1"""
    rep = df[df.Replica >= 1].groupby(chiave)[col]
    out = pd.DataFrame({"mediana": rep.median(), "min": rep.min(), "max": rep.max(),
                        "p10": rep.quantile(0.1), "p90": rep.quantile(0.9), "repliche": rep.count()})
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


# ---------------------------------------------------------------------------- sintesi
def pc(x):
    return "n.d." if pd.isna(x) else f"{100 * x:.0f}%"


def nn(x, d=2):
    return "n.d." if pd.isna(x) else f"{x:.{d}f}".replace(".", ",")


def scrivi_sintesi(blocco, tabs, A, dest):
    rep = sorted(r for r in tabs if r >= 1)
    L = [f"# Repliche dei partecipanti, blocco {blocco}", "",
         f"Repliche analizzate: {len(rep)} ({', '.join(f'r{r:02d}' for r in rep)})"
         + ("; r00 = identita' (schede di prima)." if 0 in tabs else "; r00 mancante."), ""]
    v = A["vincitori"]
    L += ["## Vincitori", "",
          "Per ogni livello, indicatore, taglia e fascia: il vincitore piu' frequente fra le repliche,",
          "in quante repliche vince lui, e se coincide con quello del disegno di prima (r00).", "",
          "I vincitori si confrontano come insieme dei primi a pari merito.", "",
          "| Indicatore | Celle | Repliche col vincitore modale (media) | Celle con modale = r00 | Repliche con almeno un primo in comune con r00 |",
          "|---|---|---|---|---|"]
    for i in INDICATORI:
        s = v[v.Indicatore == i]
        if len(s):
            L.append(f"| {i} | {len(s)} | {pc(s.QuotaModale.mean())} | {pc(s.ModaleUgualeR00.mean())} | "
                     f"{pc(s.QuotaInComuneR00.mean())} |")
    t = A["tau"]
    L += ["", "## Accordo fra criteri (tau-b medio per fascia, livello base)", "",
          "| Coppia | Fascia | r00 | Mediana repliche | Min-max | Repliche con il segno della mediana |",
          "|---|---|---|---|---|---|"]
    for a, b in [("Gini", "ForzaIncentivante"), ("FairnessIndex", "ForzaIncentivante"),
                 ("Gini", "FairnessIndex"), ("FairnessIndex", "EccessoMax_EUR")]:
        s = t[((t.IndicatoreA == a) & (t.IndicatoreB == b)) | ((t.IndicatoreA == b) & (t.IndicatoreB == a))]
        for _, r in s.sort_values("Fascia").iterrows():
            L.append(f"| {a} - {b} | {r.Fascia} | {nn(r.r00)} | {nn(r.mediana)} | "
                     f"{nn(r['min'])} / {nn(r['max'])} | {pc(r.QuotaSegnoMediana)} |")
    # il risultato centrale del rapporto del 28/10: la struttura del conflitto si capovolge
    # con la penetrazione. Si conta in quante repliche regge, replica per replica.
    T = A["tau_grezzo"]
    def tau_rep(a, b, fascia):
        s = T[(((T.IndicatoreA == a) & (T.IndicatoreB == b)) | ((T.IndicatoreA == b) & (T.IndicatoreB == a)))
              & (T.Fascia == fascia)]
        return s.groupby("Replica").TauMedio.first()
    fmax = int(T.Fascia.max())
    g1, g4 = tau_rep("Gini", "ForzaIncentivante", 1), tau_rep("Gini", "ForzaIncentivante", fmax)
    m1, m3 = tau_rep("FairnessIndex", "ForzaIncentivante", 1), tau_rep("FairnessIndex", "ForzaIncentivante", 3)
    d = pd.DataFrame({"g1": g1, "g4": g4, "m1": m1, "m3": m3})
    dr = d[d.index >= 1]
    L += ["", "## Il capovolgimento con la penetrazione, replica per replica", "",
          f"- tau(Gini, forza incentivante) diventa piu' negativo di almeno 0,3 dalla fascia 1 alla {fmax}: "
          f"{int(((dr.g4 - dr.g1) <= -0.3).sum())} repliche su {len(dr)}"
          + (f" (r00: {nn(d.g1.get(0))} -> {nn(d.g4.get(0))})" if 0 in d.index else "") + ";",
          f"- tau(Fairness Index, forza incentivante) passa da negativo (fascia 1) a positivo (fascia 3): "
          f"{int(((dr.m1 < 0) & (dr.m3 > 0)).sum())} repliche su {len(dr)}"
          + (f" (r00: {nn(d.m1.get(0))} -> {nn(d.m3.get(0))})" if 0 in d.index else "") + ".",
          "", "| Replica | Gini-IS f1 | Gini-IS f" + str(fmax) + " | FI-IS f1 | FI-IS f3 |", "|---|---|---|---|---|"]
    for r, x in d.iterrows():
        L.append(f"| r{r:02d} | {nn(x.g1)} | {nn(x.g4)} | {nn(x.m1)} | {nn(x.m3)} |")

    # i poli: chi vince piu' spesso ogni indicatore, livello base
    V = A["vincitori_grezzo"]
    V0 = V[V.Livello == "PA0"]
    L += ["", "## Chi vince (livello base: quota delle celle in cui il metodo e' fra i primi, pari compresi)", "",
          "| Indicatore | r00 | Repliche (tutte le celle di tutte le repliche) |", "|---|---|---|"]
    V0 = V0.assign(Primi=lambda d: insieme_vincitori(d))
    for i in INDICATORI:
        s = V0[V0.Indicatore == i].dropna(subset=["Primi"])
        if not len(s):
            continue
        def top(x):          # quota di celle in cui il metodo e' fra i primi (pari compresi)
            q = x.Primi.str.split(" = ").explode().value_counts().div(len(x)).head(3)
            return ", ".join(f"{k} {pc(v)}" for k, v in q.items())
        a0 = s[s.Replica == 0]
        L.append(f"| {i} | {top(a0) if len(a0) else 'n.d.'} | {top(s[s.Replica >= 1])} |")

    iv = A["inversioni"]
    L += ["", "## Inversioni di graduatoria lungo gli assi", "",
          "| Asse | Fisso | r00 | Mediana | Min-max |", "|---|---|---|---|---|"]
    for _, r in iv.iterrows():
        L.append(f"| {r.Sweep} | {r.Fisso} | {pc(r.r00)} | {pc(r.mediana)} | {pc(r['min'])}-{pc(r['max'])} |")
    va = A["varianza"]
    L += ["", "## Da cosa dipendono i punteggi (quota della varianza, livello base)", "",
          "| Indicatore | Penetrazione | Taglia | Interazione | Partecipanti | r00: penetrazione | r00: taglia |",
          "|---|---|---|---|---|---|---|"]
    for _, r in va.iterrows():
        L.append(f"| {r.Indicatore} | {pc(r.penetrazione)} | {pc(r.taglia)} | {pc(r.interazione)} | "
                 f"{pc(r.partecipanti)} | {pc(r.penetrazione_r00)} | {pc(r.taglia_r00)} |")
    co = A["composizione"]
    if len(co):
        L += ["", "## Composizione (PA e imprese): coppie invertite rispetto al livello base", "",
              "| Confronto | r00 (media sugli indicatori) | Mediana repliche |", "|---|---|---|"]
        for c, s in co.groupby("Confronto"):
            L.append(f"| {c} | {pc(s.r00_inv.mean())} | {pc(s.mediana_inv.mean())} |")
    pe = A["perdite"]
    L += ["", "## Perdite di trade-off principali (perdita ottimistica media)", "",
          "| Si sceglie | Si perde | r00 | Mediana | Min-max |", "|---|---|---|---|---|"]
    for a, b in [("Gini", "EccessoMax_EUR"), ("Gini", "ForzaIncentivante"), ("ForzaIncentivante", "Gini"),
                 ("FairnessIndex", "EccessoMax_EUR"), ("EccessoMax_EUR", "FairnessIndex")]:
        s = pe[(pe.Scelto == a) & (pe.Perde == b)]
        for _, r in s.iterrows():
            L.append(f"| {a} | {b} | {nn(r.r00)} | {nn(r.mediana)} | {nn(r['min'])}-{nn(r['max'])} |")
    dest.write_text("\n".join(L) + "\n", encoding="utf-8")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--blocco", required=True)
    a = ap.parse_args(argv)
    cart = ROOT / "outputs" / "repliche" / a.blocco
    tabs = repliche(cart)
    assert any(r >= 1 for r in tabs), f"nessuna replica completa in {cart}"
    dest = cart / "aggregato"
    dest.mkdir(exist_ok=True)
    A = {"vincitori": vincitori(tabs), "tau": tau(tabs), "inversioni": inversioni(tabs),
         "perdite": perdite(tabs), "sufficienza": sufficienza(tabs), "pareto": pareto(tabs),
         "composizione": composizione(tabs)}
    A["varianza"], dettaglio = varianza(tabs)
    for k, df in A.items():
        df.to_csv(dest / f"{k}.csv", index=False)
    dettaglio.to_csv(dest / "varianza_per_metodo.csv", index=False)
    A["tau_grezzo"] = leggi(tabs, "sintesi/tau_per_fascia.csv")
    A["vincitori_grezzo"] = leggi(tabs, "confronto/griglia_vincitori.csv", per_livello=True)
    scrivi_sintesi(a.blocco, tabs, A, dest / "sintesi.md")
    print(f"{len(tabs)} repliche lette (r00 {'presente' if 0 in tabs else 'assente'}); uscite in {dest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
