"""Rapporto finale sulle repliche, numeri per LaTeX e tabelle della tesi (passo 6 del piano).

Legge outputs/repliche/<blocco>/aggregato/ (aggrega_repliche.py) e le figure di
grafici_repliche.py e grafici_metodi.py, e scrive in --out (default outputs/tesi_finale/):

  rapporto.html      figure con didascalia, conclusioni chiave con il loro verdetto sulle
                     repliche, tabelle; un file unico da aprire con un doppio clic
  numeri_tesi.tex    macro LaTeX (\\newcommand) con i numeri citati nel testo: si include con
                     \\input{numeri_tesi} e i numeri non si copiano piu' a mano
  tabelle/*.tex      tabelle booktabs (solo l'ambiente tabular: didascalia ed etichetta nella tesi)
  tabelle/*.csv      gli stessi numeri in CSV
  conclusioni.csv    le conclusioni chiave del rapporto del 28/10, rilette sulle repliche

DUE TIPI DI CONTROLLO
  - di integrita' (si ferma, codice 1): numero di repliche e di comunita', i 10 metodi della
    versione B, nessun Nucleolo, stabilita' a tutte le taglie, nessun metodo escluso dalle figure
    descrittive. Se uno fallisce i numeri non sono quelli della tesi;
  - sulle conclusioni (non si ferma): ogni affermazione del rapporto del 28/10 e' ricalcolata e
    marcata "confermata", "non confermata" o "dipende dai partecipanti", con il suo numero. Le
    affermazioni non si scrivono a mano: il testo della tesi va adeguato a cio' che esce qui.

Uso:  python -I CER_repliche/rapporto_repliche.py [--radice ...] [--blocco unito] [--out ...]
"""
from __future__ import annotations

import argparse
import base64
import html
import io
import re
import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
import stile_tesi as st  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
ERRORI: list[str] = []
MACRO: dict[str, str] = {}


# ---------------------------------------------------------------------------- utilita'
def integrita(cond, msg):
    if not bool(cond):
        ERRORI.append(msg)


def f(x, d=2):
    return "n.d." if x is None or pd.isna(x) else f"{float(x):.{d}f}"


def p(x, d=0):
    return "n.d." if x is None or pd.isna(x) else f"{100 * float(x):.{d}f}"


def nome_macro(*parti) -> str:
    """\\TauGiniForzaIncentivanteBandOne: solo lettere, come vuole LaTeX."""
    cifre = {"0": "Zero", "1": "One", "2": "Two", "3": "Three", "4": "Four", "5": "Five", "6": "Six",
             "7": "Seven", "8": "Eight", "9": "Nine"}
    s = "".join(str(x) for x in parti)
    s = "".join(cifre.get(c, c) for c in s)
    return re.sub(r"[^A-Za-z]", "", s)


def macro(valore, *nome):
    MACRO[nome_macro(*nome)] = str(valore)


def scrivi_macro(dest: Path):
    righe = ["% Numeri della tesi generati da CER_repliche/rapporto_repliche.py: non modificare a mano.",
             "% Uso: \\input{numeri_tesi} nel preambolo, poi \\NomeMacro{} nel testo.", ""]
    righe += [f"\\newcommand{{\\{k}}}{{{v}}}" for k, v in sorted(MACRO.items())]
    dest.write_text("\n".join(righe) + "\n", encoding="utf-8")


def tex(df: pd.DataFrame, dest: Path, allinea: str | None = None):
    """Tabella booktabs (solo tabular). Il testo e' gia' formattato."""
    allinea = allinea or "l" + "r" * (df.shape[1] - 1)
    def esc(s):
        s = str(s)
        if "$" in s:          # gia' scritto in LaTeX (formule)
            return s
        return s.replace("&", "\\&").replace("%", "\\%").replace("_", "\\_").replace("#", "\\#")
    righe = [f"\\begin{{tabular}}{{{allinea}}}", "\\toprule",
             " & ".join(esc(c) for c in df.columns) + " \\\\", "\\midrule"]
    righe += [" & ".join(esc(v) for v in r) + " \\\\" for r in df.astype(str).values]
    righe += ["\\bottomrule", "\\end{tabular}"]
    dest.with_suffix(".tex").write_text("\n".join(righe) + "\n", encoding="utf-8")
    df.to_csv(dest.with_suffix(".csv"), index=False)


def img(path: Path, larghezza=1500) -> str:
    from PIL import Image
    im = Image.open(path).convert("RGB")
    if im.width > larghezza:
        im = im.resize((larghezza, round(im.height * larghezza / im.width)), Image.LANCZOS)
    buf = io.BytesIO()
    im.quantize(colors=256, method=Image.Quantize.MEDIANCUT).save(buf, "PNG", optimize=True)
    return base64.b64encode(buf.getvalue()).decode()


def tab_html(df: pd.DataFrame) -> str:
    th = "".join(f"<th>{html.escape(str(c))}</th>" for c in df.columns)
    tr = "".join("<tr>" + "".join(f"<td>{html.escape(str(v))}</td>" for v in r) + "</tr>"
                 for r in df.astype(str).values)
    return f"<div class='tab'><table><thead><tr>{th}</tr></thead><tbody>{tr}</tbody></table></div>"


# ---------------------------------------------------------------------------- dati
def carica(agg: Path) -> dict:
    A = {}
    for k in ["robustezza", "esiti", "tau", "perdite", "varianza", "composizione", "sufficienza", "pareto",
              "soglia", "van", "quote_prosumer", "sensibilita", "fase1", "inversioni", "poli_per_replica",
              "comunita_tutte"]:
        q = agg / f"{k}.csv"
        A[k] = pd.read_csv(q, dtype={"Fascia": str} if k in ("van", "quote_prosumer") else None) \
            if q.exists() else pd.DataFrame()
    return A


def quota_poli(A) -> pd.DataFrame:
    """quota di celle in cui il metodo e' fra i primi, per replica e indicatore (tutte le taglie)"""
    pp = A["poli_per_replica"].copy()
    pp["Metodo"] = pp.Metodo.replace(st.AS, "Shapley")
    tot = pp.drop_duplicates(["Replica", "Indicatore", "Membri"]).groupby(["Replica", "Indicatore"]).Celle.sum()
    q = pp.groupby(["Replica", "Indicatore", "Metodo"]).CelleFraIPrimi.sum().div(tot).clip(upper=1)
    return q.rename("Q").reset_index()


# ---------------------------------------------------------------------------- conclusioni
def conclusioni(A) -> pd.DataFrame:
    """Le affermazioni del rapporto del 28/10, ricalcolate replica per replica dove possibile.
    Esito replica per replica -> k/n e verdetto con le stesse soglie di aggrega_repliche.py."""
    righe = []
    Q = quota_poli(A)
    n_rep = Q.Replica.nunique()

    def per_replica(nome, esiti, numero):
        k, n = int(np.sum(esiti)), len(esiti)
        v = "confermata" if n and k / n >= 0.75 else "non confermata" if n and k / n <= 0.25 else \
            "dipende dai partecipanti"
        righe.append({"Conclusione": nome, "Repliche": f"{k}/{n}", "Verdetto": v, "Numero": numero})

    def polo(ind, metodi, soglia=0.5):
        s = Q[(Q.Indicatore == ind) & Q.Metodo.isin(metodi)].groupby("Replica").Q.max()
        s = s.reindex(sorted(Q.Replica.unique()), fill_value=0)
        return s >= soglia, s.median()

    for ind, metodi, testo in [
            ("Gini", ["Equal Split"], "Equal Split e' primo su Gini nella maggioranza delle celle"),
            ("FairnessIndex", ["Variance Least Core"], "il Variance Least Core e' primo sul merito (FI)"),
            ("EccessoMax_EUR", ["Variance Least Core"], "il Variance Least Core e' primo sulla stabilita' (eccesso)"),
            ("ForzaIncentivante", ["Pearson Key", "Tri-level EP"],
             "Pearson Key o Tri-level EP sono primi sulla forza incentivante")]:
        e, med = polo(ind, metodi)
        per_replica(testo, e.values, f"mediana {p(med)}% delle celle")

    R = A["robustezza"]
    for _, r in R[R.Tipo.isin(["capovolgimento", "soglia"])].iterrows():
        righe.append({"Conclusione": r.Conclusione, "Repliche": f"{int(r.k)}/{int(r.n)}",
                      "Verdetto": {"regge": "confermata", "si inverte": "non confermata"}.get(
                          r.Verdetto, "dipende dai partecipanti"),
                      "Numero": f"IC 95% {p(r.IC95_basso)}-{p(r.IC95_alto)}%"})

    P = A["perdite"]
    if len(P):
        top = P.sort_values("mediana", ascending=False).iloc[0]
        coppia = {top.Scelto, top.Perde}
        ok = coppia == {"Gini", "ForzaIncentivante"}
        righe.append({"Conclusione": "il trade-off piu' caro e' uguaglianza contro incentivo",
                      "Repliche": "mediane", "Verdetto": "confermata" if ok else "non confermata",
                      "Numero": f"piu' caro: {top.Scelto} -> {top.Perde} {f(top.mediana)}"})
        fe = P[(P.Scelto == "FairnessIndex") & (P.Perde == "EccessoMax_EUR")]
        if len(fe):
            v = fe.iloc[0]
            righe.append({"Conclusione": "merito e stabilita' non si fanno concorrenza (perdita <= 0,10)",
                          "Repliche": "mediana", "Verdetto": "confermata" if v.mediana <= 0.10 else "non confermata",
                          "Numero": f"FI -> eccesso {f(v.mediana)} [{f(v.ic95_basso)}; {f(v.ic95_alto)}]"})
    C = A["composizione"]
    if len(C):
        c = C[C.Confronto.str.startswith("PA0-")]
        m = c.mediana_inv.median()
        righe.append({"Conclusione": "la composizione pesa poco (coppie invertite <= 15%)", "Repliche": "mediana",
                      "Verdetto": "confermata" if m <= 0.15 else "non confermata",
                      "Numero": f"{p(m)}% (livelli {p(c.mediana_inv.min())}-{p(c.mediana_inv.max())}%)"})
    V = A["varianza"].dropna(subset=["penetrazione"])
    if len(V):
        primo = (V.penetrazione >= V[["taglia", "interazione", "partecipanti"]].max(axis=1))
        righe.append({"Conclusione": "la penetrazione e' il primo fattore della varianza per ogni indicatore",
                      "Repliche": "-", "Verdetto": "confermata" if primo.all() else "non confermata",
                      "Numero": f"{int(primo.sum())}/{len(V)} indicatori; eccezioni: "
                                + (", ".join(V.Indicatore[~primo]) or "nessuna")})
    return pd.DataFrame(righe)


# ---------------------------------------------------------------------------- numeri e tabelle
def numeri_e_tabelle(A, out: Path, n_rep: int):
    T = out / "tabelle"
    T.mkdir(parents=True, exist_ok=True)
    macro(n_rep, "NumReplicas")
    com = A["comunita_tutte"]
    if len(com):
        c1 = com[com.Replica >= 1]
        macro(c1.groupby("Replica").size().iloc[0], "NumCommunitiesPerReplica")
        macro(len(c1), "NumCommunitiesAllReplicas")

    # robustezza
    R = A["robustezza"]
    if len(R):
        tipi = {"tau": "Sign of $\\tau_b$ (pair $\\times$ band)", "vincitore": "First-ranked mechanism (indicator $\\times$ cell)",
                "capovolgimento": "Reversal with penetration", "soglia": "Regulatory threshold"}
        righe = []
        for t, s in R.groupby("Tipo", sort=False):
            righe.append([tipi.get(t, t), len(s), int((s.Verdetto == "regge").sum()),
                          int((s.Verdetto == "dipende dai partecipanti").sum()), int((s.Verdetto == "si inverte").sum()),
                          f"{int(s.MetaConcordi.sum())}/{len(s)}", p(s.Bootstrap_stesso_verdetto.median())])
        df = pd.DataFrame(righe, columns=["Conclusion type", "N", "Holds", "Depends", "Reverses",
                                          "Halves agree", "Bootstrap (%)"])
        tex(df, T / "robustness")
        macro(len(R), "NumConclusions")
        macro(int((R.Verdetto == "regge").sum()), "NumConclusionsHold")
        macro(int(R.MetaConcordi.sum()), "NumConclusionsHalvesAgree")
        macro(p(R.MetaConcordi.mean()), "PctConclusionsHalvesAgree")
        macro(p(R.Bootstrap_stesso_verdetto.median()), "PctBootstrapSameVerdict")
        for _, r in R[R.Tipo.isin(["capovolgimento", "soglia"])].iterrows():
            chiave = {"tau(Gini, IS)": "ReversalGiniIS", "tau(FI, IS)": "ReversalFIIS",
                      "nessuna comunita'": "ThresholdFirms"}
            k = next((v for kk, v in chiave.items() if r.Conclusione.startswith(kk)), None)
            if k:
                macro(f"{int(r.k)}/{int(r.n)}", k, "Count")
                macro(f"{p(r.IC95_basso)}--{p(r.IC95_alto)}", k, "CI")

    # tau
    Tt = A["tau"]
    if len(Tt):
        righe = []
        for a, b in [("Gini", "ForzaIncentivante"), ("FairnessIndex", "ForzaIncentivante"),
                     ("Gini", "FairnessIndex"), ("FairnessIndex", "EccessoMax_EUR")]:
            s = Tt[((Tt.IndicatoreA == a) & (Tt.IndicatoreB == b)) | ((Tt.IndicatoreA == b) & (Tt.IndicatoreB == a))]
            for _, r in s.sort_values("Fascia").iterrows():
                righe.append([f"{st.nome_indicatore(a)} -- {st.nome_indicatore(b)}", int(r.Fascia), f(r.mediana),
                              f"[{f(r.ic95_basso)}, {f(r.ic95_alto)}]", f"{f(r['min'])} / {f(r['max'])}",
                              p(r.QuotaSegnoMediana)])
                macro(f(r.mediana), "Tau", a, b, "Band", int(r.Fascia))
        tex(pd.DataFrame(righe, columns=["Pair", "Band", "Median", "95% CI", "Min / max", "Same sign (%)"]),
            T / "tau_by_band", "llrrrr")

    # perdite
    P = A["perdite"]
    if len(P):
        righe = []
        for a, b in [("Gini", "ForzaIncentivante"), ("ForzaIncentivante", "Gini"), ("Gini", "EccessoMax_EUR"),
                     ("FairnessIndex", "EccessoMax_EUR"), ("EccessoMax_EUR", "FairnessIndex")]:
            for _, r in P[(P.Scelto == a) & (P.Perde == b)].iterrows():
                righe.append([st.nome_indicatore(a), st.nome_indicatore(b), f(r.mediana),
                              f"[{f(r.ic95_basso)}, {f(r.ic95_alto)}]", f"{f(r['min'])} -- {f(r['max'])}"])
                macro(f(r.mediana), "Loss", a, "To", b)
        tex(pd.DataFrame(righe, columns=["Chosen", "Sacrificed", "Median loss", "95% CI", "Range"]),
            T / "tradeoff_losses", "llrrr")

    # varianza
    V = A["varianza"].dropna(subset=["penetrazione"])
    if len(V):
        df = pd.DataFrame({"Indicator": [st.nome_indicatore(i) for i in V.Indicatore],
                           "Penetration": [p(x) for x in V.penetrazione], "Size": [p(x) for x in V.taglia],
                           "Interaction": [p(x) for x in V.interazione],
                           "Participants": [p(x) for x in V.partecipanti]})
        tex(df, T / "variance_decomposition")
        for _, r in V.iterrows():
            macro(p(r.penetrazione), "VarPenetration", r.Indicatore)
            macro(p(r.partecipanti), "VarParticipants", r.Indicatore)

    # soglia
    S = A["soglia"]
    if len(S):
        df = pd.DataFrame({"Group": S.Gruppo, "Communities": S.Comunita, "Max (%)": [p(x, 1) for x in S.QuotaMax],
                           "Median (%)": [p(x, 1) for x in S.QuotaMediana], "Above 55%": S.Sopra55,
                           "Above 45%": S.Sopra45, "Sizes above 55%": S.TaglieSopra55.fillna("--")})
        tex(df, T / "regulatory_threshold", "lrrrrrl")
        for _, r in S.iterrows():
            g = r.Gruppo.title().replace(" ", "")
            macro(p(r.QuotaMax, 1), "ThresholdMax", g)
            macro(int(r.Sopra55), "ThresholdAbove", g)

    # VAN
    Vn = A["van"]
    if len(Vn):
        s = Vn[Vn.Fascia == "tutte"]
        df = pd.DataFrame({"Mechanism": [st.nome_metodo(m) for m in s.Metodo], "Group": s.Gruppo,
                           "Min NPV, median (EUR)": [f(x, 0) for x in s.VAN_min_mediana],
                           "10--90% (EUR)": [f"{f(a, 0)} / {f(b, 0)}" for a, b in zip(s.VAN_min_p10, s.VAN_min_p90)],
                           "With negative NPV (%)": [p(x) for x in s.QuotaComunitaConNegativi]})
        tex(df, T / "npv", "llrrr")

    # quote ai prosumer
    Q = A["quote_prosumer"]
    if len(Q):
        s = Q[(Q.Gruppo == "households only") & (Q.Fascia != "tutte")]
        w = s.pivot_table(index="Metodo", columns="Fascia", values="QuotaProsumer_mediana")
        w = w.reindex(st.ordina_metodi(w.index))
        df = pd.DataFrame({"Mechanism": [st.nome_metodo(m) for m in w.index],
                           **{f"Band {c} (%)": [p(x) for x in w[c]] for c in w.columns}})
        tex(df, T / "prosumer_share")

    # Shapley contro AS
    F1 = A["fase1"]
    if len(F1):
        w = F1.pivot_table(index="Membri", columns="Misura", values=["mediana", "max", "min"])
        df = pd.DataFrame({"Members": w.index, "Mean rel. error (%)": [f(x) for x in w[("mediana", "RD_medio_pct")]],
                           "Max rel. error (%)": [f(x) for x in w[("max", "RD_max_pct")]],
                           "Min Spearman": [f(x) for x in w[("min", "Spearman_rho_min")]]})
        tex(df, T / "shapley_vs_as")
        macro(f(w[("mediana", "RD_medio_pct")].max(), 1), "ASMeanErrorMax")

    # sensibilita'
    Se = A["sensibilita"]
    if len(Se):
        df = pd.DataFrame({"Range fraction": Se.FracEscursione, "v(N) fraction": Se.FracVN,
                           "Winner changes, median (%)": [p(x) for x in Se.mediana],
                           "Max (%)": [p(x) for x in Se["max"]],
                           "Another method first (max)": Se.AltroMetodoPrimo_max.astype(int)})
        tex(df, T / "relevance_threshold")


# ---------------------------------------------------------------------------- integrita'
def controlli_integrita(A, attese: int, figure_descrittive: Path | None):
    com = A["comunita_tutte"]
    integrita(len(com), "manca comunita_tutte.csv")
    if len(com):
        rep = sorted(com.Replica.unique())
        integrita(len([r for r in rep if r >= 1]) == attese - 1,
                  f"repliche >= 1 attese {attese - 1}, trovate {len([r for r in rep if r >= 1])}")
        per = com.groupby("Replica").size()
        integrita(per.nunique() == 1, f"comunita' diverse fra repliche: {per.to_dict()}")
    Q = quota_poli(A) if len(A["poli_per_replica"]) else pd.DataFrame(columns=["Metodo"])
    integrita("Nucleolo" not in set(Q.Metodo), "il Nucleolo compare fra i vincitori")
    integrita(set(Q.Metodo) <= set(st.METODI), f"metodi inattesi: {sorted(set(Q.Metodo) - set(st.METODI))}")
    pp = A["poli_per_replica"]
    if len(pp):
        stab = pp[pp.Indicatore == "EccessoMax_EUR"].Membri.unique()
        tutte = pp.Membri.unique()
        integrita(set(stab) == set(tutte),
                  f"stabilita' mancante a {sorted(int(x) for x in set(tutte) - set(stab))} membri")
    if figure_descrittive is not None:
        c = figure_descrittive / "controlli.txt"
        if c.exists():
            m = re.search(r"metodi esclusi dai grafici grezzi perche' l'export e' superato: (\[.*?\])", c.read_text())
            integrita(m is None or m.group(1) == "[]",
                      f"grafici_metodi.py ha escluso dei metodi dalle figure grezze: {m.group(1) if m else ''}")


# ---------------------------------------------------------------------------- HTML
CSS = """body{font-family:system-ui,sans-serif;max-width:1100px;margin:2em auto;color:#222;line-height:1.45}
h1{color:#005AA0}h2{color:#005AA0;border-bottom:2px solid #005AA0;padding-bottom:.2em;margin-top:2em}
.fig{margin:1.5em 0}.fig img{max-width:100%;border:1px solid #eee}.cosa{color:#444}
table{border-collapse:collapse;font-size:.85em;margin:.6em 0}td,th{border-bottom:1px solid #ddd;padding:.25em .6em}
th{background:#f4f8fb;text-align:left}.ok{color:#005AA0;font-weight:600}.no{color:#D9731A;font-weight:600}
.dip{color:#666;font-weight:600}.err{background:#fde8e8;padding:1em;border-left:4px solid #c00}
.file{font-size:.75em;color:#888}"""

SEZIONI = [
    ("6.2 Reference comparison across mechanisms and indicators", ["G01_poles", "F01_valori_grezzi",
                                                                   "F03_sintesi_metodi_metriche", "G12_stability_by_size"]),
    ("6.3 Sensitivity to size, penetration and composition", ["G04_variance", "G05_composition",
                                                              "F10_effetto_composizione", "F13_grezzi_ND3"]),
    ("6.4 Ranking reversals", ["G03_reversals"]),
    ("6.5 Agreement among indicators, trade-offs, reduced set", ["G02_tau_by_band", "F12_accordo_indicatori",
                                                                  "G06_tradeoff_losses", "G07_reduced_set", "G08_pareto"]),
    ("6.6 Regulatory admissibility threshold", ["G09_threshold"]),
    ("Complementary analyses", ["G10_npv", "G11_prosumer_share", "F09_quota_prosumer"]),
    ("Robustness to the households drawn (6.1)", ["G13_robustness"]),
]


def pagina(A, C, figure: Path, figure_descr: Path | None, out: Path, n_rep: int):
    cat = pd.read_csv(figure / "figure.csv").set_index("Figura") if (figure / "figure.csv").exists() else pd.DataFrame()
    H = [f"<!DOCTYPE html><html lang='it'><head><meta charset='utf-8'><title>Risultati sulle repliche</title>"
         f"<style>{CSS}</style></head><body><h1>Risultati sulle repliche dei partecipanti</h1>",
         f"<p>{n_rep} repliche (r01-r{n_rep:02d}); r00 non entra nei risultati. Ogni numero viene dai CSV di "
         "<code>aggregato/</code>; i numeri citabili sono in <code>numeri_tesi.tex</code>.</p>"]
    if ERRORI:
        H.append("<div class='err'><b>Controlli di integrita' falliti:</b><ul>"
                 + "".join(f"<li>{html.escape(x)}</li>" for x in ERRORI) + "</ul></div>")
    if len(C):
        cls = {"confermata": "ok", "non confermata": "no"}
        H.append("<h2>Conclusioni del rapporto del 28 ottobre, rilette sulle repliche</h2><table><tr><th>Conclusione"
                 "</th><th>Repliche</th><th>Verdetto</th><th>Numero</th></tr>" + "".join(
                     f"<tr><td>{html.escape(r.Conclusione)}</td><td>{r.Repliche}</td>"
                     f"<td class='{cls.get(r.Verdetto, 'dip')}'>{r.Verdetto}</td><td>{html.escape(str(r.Numero))}</td></tr>"
                     for _, r in C.iterrows()) + "</table>")
    for titolo, figs in SEZIONI:
        H.append(f"<h2>{html.escape(titolo)}</h2>")
        for nome in figs:
            base = figure if nome.startswith("G") else figure_descr
            if base is None:
                continue
            path = base / f"{nome}.png"
            if not path.exists() and nome.startswith("F") and (base / "assi" / f"{nome}.png").exists():
                path = base / "assi" / f"{nome}.png"
            if not path.exists():
                continue
            t = cat.loc[nome, "Titolo"] if nome in cat.index else nome
            d = cat.loc[nome, "Descrizione"] if nome in cat.index else "figura descrittiva di grafici_metodi.py"
            H.append(f"<div class='fig'><h3>{html.escape(str(t))}</h3><p class='cosa'>{html.escape(str(d))}</p>"
                     f"<img src='data:image/png;base64,{img(path)}'><p class='file'>{html.escape(str(path))} (anche .pdf)</p></div>")
    H.append("<h2>Tabelle</h2>")
    for q in sorted((out / "tabelle").glob("*.csv")):
        H.append(f"<h3>{q.stem}</h3>" + tab_html(pd.read_csv(q)))
    H.append("</body></html>")
    (out / "rapporto.html").write_text("\n".join(H), encoding="utf-8")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--radice", default=str(ROOT / "outputs" / "repliche"))
    ap.add_argument("--blocco", default="unito")
    ap.add_argument("--attese", type=int, default=21)
    ap.add_argument("--out", default=str(ROOT / "outputs" / "tesi_finale"))
    ap.add_argument("--figure-descrittive", default=None,
                    help="cartella di grafici_metodi.py (default <out>/figure_descrittive)")
    ap.add_argument("--numeri-descrittivi", default=None,
                    help="cartella --numeri di grafici_metodi.py (default <out>/numeri_descrittivi)")
    a = ap.parse_args(argv)
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    agg = Path(a.radice) / a.blocco / "aggregato"
    A = carica(agg)
    n_rep = int(A["comunita_tutte"].query("Replica >= 1").Replica.nunique()) if len(A["comunita_tutte"]) else 0
    fd = Path(a.figure_descrittive) if a.figure_descrittive else out / "figure_descrittive"
    nd = Path(a.numeri_descrittivi) if a.numeri_descrittivi else out / "numeri_descrittivi"
    controlli_integrita(A, a.attese, nd if nd.exists() else None)
    C = conclusioni(A)
    C.to_csv(out / "conclusioni.csv", index=False)
    numeri_e_tabelle(A, out, n_rep)
    scrivi_macro(out / "numeri_tesi.tex")
    pagina(A, C, out / "figure", fd if fd.exists() else None, out, n_rep)
    print(C.to_string(index=False))
    print(f"\n{len(MACRO)} macro in {out / 'numeri_tesi.tex'}; rapporto in {out / 'rapporto.html'}")
    if ERRORI:
        print("\nCONTROLLI DI INTEGRITA' FALLITI:\n- " + "\n- ".join(ERRORI))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
