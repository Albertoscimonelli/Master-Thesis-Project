"""Pagina HTML dei risultati: tutte le figure con spiegazione e conclusioni, per la revisione.

Uso, dalla root del progetto (dopo grafici_metodi.py, che la chiama anche da solo alla fine):
    python -I outputs/workspace/strumenti/pagina_risultati.py [--apri]
        [--figure outputs/figures_tesi] [--numeri outputs/tables_tesi] [--frammento FILE]

Scrive <figure>/index.html: un file unico, con le immagini incorporate, che si apre con un
doppio clic e si puo' inviare cosi' com'e'. --apri lo apre nel browser. --frammento scrive
la stessa pagina senza intestazione del documento (serve a pubblicarla come Artifact).

I NUMERI NEL TESTO non sono scritti a mano: vengono dai CSV di outputs/tables_tesi/ prodotti
da grafici_metodi.py, quindi si aggiornano rigenerando. Il testo interpretativo invece e'
scritto per i dati del 20 ottobre: se un run nuovo cambia il segno di un risultato, le frasi
vanno rilette (la pagina mostra comunque i numeri nuovi).
"""
import argparse
import base64
import html
import re
import webbrowser
from datetime import date
from pathlib import Path

import pandas as pd

NOMI_METRICHE = {
    "Gini": "Gini dei risparmi",
    "FairnessIndex": "Fairness Index",
    "Sigma": "σ dello scostamento dal merito",
    "EccessoMax_EUR": "eccesso massimo di coalizione",
    "CoalizioniInstabili": "coalizioni instabili",
    "ForzaIncentivante": "forza incentivante (netta)",
    "AllineamentoVirtu": "allineamento netto",
    "AllineamentoVirtu_lordo": "allineamento lordo",
}


# ============================================================ numeri dai CSV
def it(x, d=2):
    """Numero all'italiana: virgola decimale, segno meno tipografico."""
    s = f"{x:.{d}f}".replace(".", ",")
    return s.replace("-", "−")


def pct(x, d=0):
    return it(100 * x, d) + "%"


def fascia(df):
    u = df[["Scheda", "Membri", "Penetrazione_pct"]].drop_duplicates("Scheda")
    u = u.assign(Fascia=u.groupby("Membri").Penetrazione_pct.rank(method="dense").astype(int))
    return df.merge(u[["Scheda", "Fascia"]], on="Scheda") if "Fascia" not in df else df


def spearman(a, b):
    return pd.concat([a, b], axis=1).rank().corr().iloc[0, 1]


def numeri(tab):
    N = {}
    g = pd.read_csv(tab / "valori_grezzi_per_comunita.csv")
    lim = g.drop_duplicates("Scheda").groupby("Fascia").Penetrazione_pct.agg(["min", "max"])
    N["fasce"] = {f: (f"{r['min']:.0f}–{r['max']:.0f}%" if round(r["min"]) != round(r["max"])
                      else f"{r['min']:.0f}%") for f, r in lim.iterrows()}
    N["ncom"] = g.Scheda.nunique()
    N["taglie"] = sorted(g.Membri.unique())
    f1, fmax = min(N["fasce"]), max(N["fasce"])
    N["f1"], N["fmax"] = f1, fmax

    pes = pd.read_csv(tab / "F06_scomposizione_varianza_per_indicatore.csv", index_col=0)
    N["eta_pen"] = (pes.eta2_penetrazione.min(), pes.eta2_penetrazione.max())
    N["eta_n"] = (pes.eta2_taglia.min(), pes.eta2_taglia.max())
    N["eta_res"] = (pes.residuo_interazione.min(), pes.residuo_interazione.max())
    N["eta_res_max_ind"] = NOMI_METRICHE.get(pes.residuo_interazione.idxmax(), pes.residuo_interazione.idxmax())
    N["eta_pen_med"] = pes.eta2_penetrazione.median()

    po = fascia(pd.read_csv(tab / "F07_posta_in_gioco.csv"))
    nmin = po.Membri.min()
    cv = po[po.Membri > nmin].groupby("Fascia").vN_membro.agg(lambda x: x.std() / x.mean())
    N["cv_vn"] = (cv.min(), cv.max())
    N["vn_membro"] = po.groupby("Fascia").vN_membro.mean().to_dict()
    N["esc"] = po.groupby("Fascia").Escursione_mean.agg(["min", "max"]).to_dict("index")
    N["esc_rel"] = (po.Escursione_rel.min(), po.Escursione_rel.max())
    po["FracCondivisa"] = po.Condivisa_kWh / (po.Condivisa_kWh + po.NonCondivisa_kWh)
    N["condivisa_fmax"] = po[po.Fascia == fmax].FracCondivisa.mean()

    def segni(metodo, col, f):
        s = g[(g.Metodo == metodo) & (g.Fascia == f)][col]
        return int((s < 0).sum()), len(s), s.min(), s.max()
    N["segni"] = {k: {f: segni(k, "ForzaIncentivante", f) for f in N["fasce"]}
                  for k in ["Shapley", "Nucleolo", "Variance Least Core", "Cascading Tree"]
                  if (g.Metodo == k).any()}
    N["lordo_sh_f1"] = segni("Shapley", "AllineamentoVirtu_lordo", f1) if (g.Metodo == "Shapley").any() else None
    es = g[g.Metodo == "Equal Split"]
    N["es_ecc"] = es.groupby("Fascia").EccessoMax_pct_vN.agg(["min", "max"]).to_dict("index")
    sh = g[g.Metodo == "Shapley"].EccessoMax_pct_vN
    N["sh_ecc"] = (sh.median(), int((sh > 1e-6).sum()), len(sh), sh.max())
    nu = g[g.Metodo.isin(["Nucleolo", "Variance Least Core"])].EccessoMax_pct_vN
    N["core_ok"] = bool((nu <= 1e-6).all())

    q = pd.read_csv(tab / "F09_quota_prosumer.csv")
    qq = q.groupby(["Metodo", "Fascia"]).RapportoAllaQuotaDiMembri.agg(["min", "max"])
    N["quota_sh"] = {f: tuple(qq.loc[("Shapley", f)]) for f in sorted(q.Fascia.unique())} \
        if "Shapley" in q.Metodo.values else {}

    t = pd.read_csv(tab / "F12_accordo_indicatori.csv")
    def tau(a, b):
        s = t[(t.IndicatoreA == a) & (t.IndicatoreB == b)]
        return dict(zip(s.Fascia, s.TauMedio))
    N["tau_gini_is"] = tau("Gini", "ForzaIncentivante")
    N["tau_fi_ecc"] = tau("FairnessIndex", "EccessoMax_EUR")

    dd = tab / "F10_delta_composizione_dettaglio.csv"
    if dd.exists():
        D = pd.read_csv(dd)
        livelli = sorted(D.Livello.unique())
        comuni = set.intersection(*(set(D[D.Livello == k].Scheda) for k in livelli))
        N["pa_comuni"] = len(comuni)
        N["pa_shift"] = {k: D[(D.Livello == k) & D.Scheda.isin(comuni)].Delta.abs().mean() for k in livelli}
        N["pa_ncom"] = {k: D[D.Livello == k].Scheda.nunique() for k in livelli}
        T = pd.read_csv(tab / "F10_delta_composizione.csv")
        forti = T[(T.CoerenzaSegno >= 0.8) & (T.Mediana.abs() >= 0.5)].copy()
        forti["a"] = forti.Mediana.abs()
        # il piu' forte per indicatore, per non elencare sei volte la stessa colonna
        forti = forti.sort_values("a", ascending=False).drop_duplicates("Indicatore")
        N["pa_forti"] = forti.head(5)[
            ["Livello", "Metodo", "Indicatore", "Mediana"]].values.tolist()
    sc = tab / "F11_scala_vs_composizione.csv"
    if sc.exists():
        A = pd.read_csv(sc)
        N["pa_rho"] = {k: spearman(d.DeltaMedioAssoluto, d.vN_rapportoPA0) for k, d in A.groupby("Livello")}
        N["pa_rho_tutti"] = spearman(A.DeltaMedioAssoluto, A.vN_rapportoPA0)
        N["pa_scala_med"] = A.groupby("Livello").vN_rapportoPA0.median().to_dict()

    ctrl = (tab / "controlli.txt").read_text(encoding="utf-8")
    m = re.search(r"esclusi dai grafici grezzi[^\[]*\[(.*?)\]", ctrl)
    N["esclusi"] = [x.strip(" '\"") for x in m.group(1).split(",") if x.strip()] if m else []
    N["controlli"] = ctrl
    return N


# ============================================================ pezzi di pagina
def immagine(p, alt):
    b = base64.b64encode(p.read_bytes()).decode()
    return (f'<button class="plate" type="button" aria-label="Ingrandisci: {html.escape(alt)}">'
            f'<img src="data:image/png;base64,{b}" alt="{html.escape(alt)}" loading="lazy"></button>')


def scheda_figura(fid, titolo, figure, alt, mostra, leggi, risultato, cautele, ancora):
    return f"""
<section class="fig" id="{ancora}">
  <header class="fig-head"><span class="fid">{fid}</span><h3>{titolo}</h3></header>
  {figure if isinstance(figure, str) else immagine(figure, alt)}
  <div class="notes">
    <div><h4>Cosa mostra</h4><p>{mostra}</p></div>
    <div><h4>Come leggerla</h4><p>{leggi}</p></div>
    <div class="esito"><h4>Risultato</h4><p>{risultato}</p></div>
  </div>
  <p class="cautela"><strong>Cautele.</strong> {cautele}</p>
</section>"""


def viewer(cartella, prefisso, vid):
    file = sorted(cartella.glob(f"{prefisso}_*.png"))
    if not file:
        return None
    ordine = list(NOMI_METRICHE)
    file.sort(key=lambda p: ordine.index(p.stem[len(prefisso) + 1:]) if p.stem[len(prefisso) + 1:] in ordine else 99)
    bott, imm = [], []
    for i, p in enumerate(file):
        k = p.stem[len(prefisso) + 1:]
        nome = NOMI_METRICHE.get(k, k)
        bott.append(f'<button type="button" role="tab" id="{vid}-t{i}" aria-selected="{"true" if i == 0 else "false"}" '
                    f'aria-controls="{vid}-p{i}" data-i="{i}">{html.escape(nome)}</button>')
        imm.append(f'<div role="tabpanel" id="{vid}-p{i}" aria-labelledby="{vid}-t{i}"{"" if i == 0 else " hidden"}>'
                   f'{immagine(p, nome)}</div>')
    return (f'<div class="viewer" data-viewer><div class="tabs" role="tablist" aria-label="Metrica">{"".join(bott)}</div>'
            f'{"".join(imm)}</div>')


CSS = """
:root {
  /* Layout: indice laterale fisso + colonna di lettura; ogni figura su una lastra chiara */
  --bg: #f3f6f6; --surface: #ffffff; --ink: #13272c; --muted: #52686d; --rule: #d3dedf;
  --accent: #0a6b70; --accent-soft: #e0f0f0; --sun: #9a6a00; --sun-soft: #fbf1d9;
  --warn: #9b3f26; --plate: #ffffff;
  --display: "IBM Plex Serif", Georgia, "Times New Roman", serif;
  --body: "IBM Plex Sans", "Segoe UI", system-ui, sans-serif;
  --mono: "IBM Plex Mono", ui-monospace, "SFMono-Regular", Menlo, monospace;
}
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --bg: #0e191b; --surface: #152428; --ink: #e2eded; --muted: #98afb2; --rule: #2a3e43;
  --accent: #5fc3c7; --accent-soft: #173a3d; --sun: #e5b347; --sun-soft: #33290f;
  --warn: #e98b6f; --plate: #ffffff; color-scheme: dark } }
:root[data-theme="dark"] {
  --bg: #0e191b; --surface: #152428; --ink: #e2eded; --muted: #98afb2; --rule: #2a3e43;
  --accent: #5fc3c7; --accent-soft: #173a3d; --sun: #e5b347; --sun-soft: #33290f;
  --warn: #e98b6f; --plate: #ffffff; color-scheme: dark }
body { background: var(--bg); color: var(--ink); font: 16px/1.6 var(--body); margin: 0; }
.wrap { max-width: 1240px; margin: 0 auto; padding-block: 32px 72px;
  padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px));
  display: grid; grid-template-columns: 210px minmax(0, 1fr); gap: 48px; }
nav.toc { position: sticky; top: calc(env(safe-area-inset-top, 0px) + 24px); align-self: start;
  font-size: 13.5px; display: grid; gap: 4px; }
nav.toc .lbl { font: 600 11px/1.4 var(--body); letter-spacing: .09em; text-transform: uppercase; color: var(--muted); margin-top: 14px; }
nav.toc a { color: var(--ink); text-decoration: none; padding: 3px 8px; border-left: 2px solid transparent; }
nav.toc a:hover, nav.toc a:focus-visible { border-left-color: var(--accent); color: var(--accent); }
main { min-width: 0; display: grid; gap: 56px; }
.intro .eyebrow { font: 600 12px/1.4 var(--mono); letter-spacing: .06em; color: var(--accent); text-transform: uppercase; }
h1 { font: 600 clamp(28px, 4vw, 40px)/1.15 var(--display); margin: 8px 0 12px; text-wrap: balance; }
h2 { font: 600 26px/1.25 var(--display); margin: 0 0 8px; text-wrap: balance; }
h3 { font: 600 19px/1.3 var(--display); margin: 0; text-wrap: balance; }
h4 { font: 600 11.5px/1.4 var(--body); letter-spacing: .08em; text-transform: uppercase; color: var(--muted); margin: 0 0 6px; }
p { margin: 0; max-width: 68ch; }
.lead { font-size: 18px; color: var(--muted); max-width: 70ch; }
.meta { font: 13px/1.5 var(--mono); color: var(--muted); margin-top: 14px; }
.sec { display: grid; gap: 22px; }
.sec > .sec-intro { display: grid; gap: 10px; }
.key { list-style: none; padding: 0; margin: 0; display: grid; gap: 12px; counter-reset: k; }
.key li { display: grid; grid-template-columns: 2.2em minmax(0, 1fr); gap: 4px 12px; padding: 14px 16px;
  background: var(--surface); border: 1px solid var(--rule); border-radius: 6px; counter-increment: k; }
.key li::before { content: "R" counter(k); font: 600 13px/1.7 var(--mono); color: var(--accent); }
.key b { font-weight: 600; }
.key a { color: var(--accent); }
.fig { display: grid; gap: 14px; scroll-margin-top: 24px; }
.fig-head { display: flex; align-items: baseline; gap: 12px; flex-wrap: wrap; }
.fid { font: 600 12.5px/1 var(--mono); color: var(--accent); background: var(--accent-soft); padding: 5px 7px; border-radius: 4px; }
.plate { display: block; width: 100%; padding: 14px; background: var(--plate); border: 1px solid var(--rule);
  border-radius: 6px; cursor: zoom-in; }
.plate:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
.plate img { display: block; width: 100%; height: auto; }
.notes { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 20px; }
.notes p { font-size: 15px; }
.esito { background: var(--sun-soft); border-radius: 6px; padding: 12px 14px; }
.esito h4 { color: var(--sun); }
.cautela { font-size: 14px; color: var(--muted); border-left: 2px solid var(--warn); padding-left: 12px; max-width: 90ch; }
.cautela strong { color: var(--warn); font-weight: 600; }
.viewer { display: grid; gap: 10px; }
.tabs { display: flex; flex-wrap: wrap; gap: 6px; }
.tabs button { font: 500 13px/1.3 var(--body); color: var(--ink); background: var(--surface); border: 1px solid var(--rule);
  border-radius: 999px; padding: 6px 12px; cursor: pointer; }
.tabs button[aria-selected="true"] { background: var(--accent); border-color: var(--accent); color: var(--surface); }
.tabs button:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
table { border-collapse: collapse; width: 100%; font-size: 14.5px; }
.tbl { overflow-x: auto; }
th, td { text-align: left; vertical-align: top; padding: 10px 12px; border-bottom: 1px solid var(--rule); }
th { font: 600 11.5px/1.4 var(--body); letter-spacing: .07em; text-transform: uppercase; color: var(--muted); }
td.num { font-variant-numeric: tabular-nums; white-space: nowrap; }
.decisione td:first-child { font-weight: 600; width: 28%; }
details { background: var(--surface); border: 1px solid var(--rule); border-radius: 6px; padding: 12px 16px; }
summary { cursor: pointer; font-weight: 600; }
pre { font: 12.5px/1.5 var(--mono); overflow-x: auto; white-space: pre; margin: 12px 0 0; color: var(--ink); }
code { font: 0.92em var(--mono); }
.lightbox { position: fixed; inset: 0; background: rgba(8, 16, 18, .88); z-index: 20; overflow: auto;
  padding: calc(env(safe-area-inset-top, 0px) + 48px) max(16px, env(safe-area-inset-right, 0px)) 24px max(16px, env(safe-area-inset-left, 0px)); }
.lightbox img { display: block; margin: 0 auto; max-width: none; width: min(1600px, 160vw); background: #fff; padding: 12px; }
.lightbox button { position: fixed; top: calc(env(safe-area-inset-top, 0px) + 10px); right: max(16px, env(safe-area-inset-right, 0px));
  font: 600 14px var(--body); background: #fff; color: #13272c; border: 0; border-radius: 4px; padding: 8px 12px; cursor: pointer; }
@media (max-width: 920px) {
  .wrap { grid-template-columns: minmax(0, 1fr); gap: 28px; }
  nav.toc { position: static; display: flex; flex-wrap: wrap; gap: 4px 10px; }
  nav.toc .lbl { width: 100%; margin-top: 4px; }
  .notes { grid-template-columns: minmax(0, 1fr); }
}
@media (prefers-reduced-motion: no-preference) { html { scroll-behavior: smooth; } }
"""

JS = """
document.querySelectorAll('[data-viewer]').forEach(function (v) {
  var tabs = v.querySelectorAll('[role=tab]'), panes = v.querySelectorAll('[role=tabpanel]');
  tabs.forEach(function (t) { t.addEventListener('click', function () {
    tabs.forEach(function (x) { x.setAttribute('aria-selected', x === t ? 'true' : 'false'); });
    panes.forEach(function (p, i) { p.hidden = String(i) !== t.dataset.i; });
  }); });
});
var box = null;
function chiudi() { if (box) { box.remove(); box = null; } }
document.addEventListener('click', function (e) {
  var b = e.target.closest('.plate');
  if (!b) return;
  chiudi();
  box = document.createElement('div'); box.className = 'lightbox';
  var c = document.createElement('button'); c.type = 'button'; c.textContent = 'Chiudi (Esc)';
  c.addEventListener('click', chiudi);
  var im = document.createElement('img'); im.src = b.querySelector('img').src; im.alt = b.querySelector('img').alt;
  box.appendChild(c); box.appendChild(im);
  box.addEventListener('click', function (ev) { if (ev.target === box) chiudi(); });
  document.body.appendChild(box); c.focus();
});
document.addEventListener('keydown', function (e) { if (e.key === 'Escape') chiudi(); });
"""


# ============================================================ testo
def costruisci_pagina(fig, tab):
    N = numeri(tab)
    F = N["fasce"]
    f1, fm = N["f1"], N["fmax"]
    esclusi = ", ".join(N["esclusi"]) or "nessuno"
    seg = N["segni"]

    def segno_str(k, f):
        neg, tot, lo, hi = seg[k][f]
        return f"{neg} comunità su {tot}"

    sh_f1 = seg.get("Shapley", {}).get(f1)
    tg = N["tau_gini_is"]
    tf = N["tau_fi_ecc"]
    es = N["es_ecc"]
    es_picco = max(es, key=lambda f: es[f]["max"])

    # ---------------------------------------------------------------- sintesi
    sintesi = [
        f"<b>La penetrazione dei prosumer decide le graduatorie molto più della taglia.</b> Spiega fra "
        f"{pct(N['eta_pen'][0])} e {pct(N['eta_pen'][1])} della varianza fra comunità dei punteggi; la "
        f"taglia fra {pct(N['eta_n'][0])} e {pct(N['eta_n'][1])}. <a href='#f06'>F06</a>",
        f"<b>A penetrazione fissa, la comunità è quasi la stessa a ogni taglia.</b> Il valore da "
        f"ripartire per membro cambia fra le taglie (da 8 membri in su) di un coefficiente di variazione "
        f"fra {pct(N['cv_vn'][0])} e {pct(N['cv_vn'][1])}, secondo la fascia. <a href='#f07'>F07</a>",
    ]
    if sh_f1:
        sintesi.append(
            f"<b>Le regole della teoria dei giochi cambiano segno sull'incentivo.</b> Con il "
            f"{F[f1]} di prosumer lo Shapley penalizza il sincronismo in {segno_str('Shapley', f1)}; "
            f"da metà penetrazione lo premia. Premia il lato scarso. <a href='#f04'>F04</a> "
            f"<a href='#f09'>F09</a>")
    sintesi += [
        f"<b>Il conflitto fra uguaglianza e incentivo nasce sopra il 40%.</b> τ(Gini, forza "
        f"incentivante) passa da {it(tg[f1])} a {it(tg[fm])}. <a href='#f12'>F12</a>",
        f"<b>La stabilità delle regole semplici crolla a penetrazione medio-alta.</b> Con l'Equal Split "
        f"una coalizione che uscisse dalla comunità guadagnerebbe fino al {it(es[es_picco]['max'], 0)}% "
        f"di v(N) in più, con {F[es_picco]} di prosumer. <a href='#f04'>F04</a>",
        f"<b>La posta in gioco cambia di un ordine di grandezza.</b> Scegliere il metodo sposta "
        f"circa {it(N['esc'][f1]['min'], 0)}–{it(N['esc'][f1]['max'], 0)} €/anno per membro con "
        f"{F[f1]} di prosumer e {it(N['esc'][fm]['min'], 0)}–{it(N['esc'][fm]['max'], 0)} € con "
        f"{F[fm]}. <a href='#f07'>F07</a>",
    ]
    if "pa_shift" in N:
        sh = N["pa_shift"]
        top = max(sh, key=sh.get)
        sintesi.append(
            f"<b>Gli edifici pubblici spostano le graduatorie, ma non come puro effetto di scala.</b> "
            f"Lo spostamento più grande è con {top} ({it(sh[top])}), non con il livello più grande; "
            f"dentro i livelli lo spostamento non cresce con la scala. <a href='#f10'>F10</a> "
            f"<a href='#f11'>F11</a>")

    # ---------------------------------------------------------------- figure
    S = []
    S.append(("profilo", "Il profilo dei metodi", "Che cosa fa ciascun metodo su ciascuna metrica, "
              "prima in unità naturali, poi in punteggio relativo.", [
        scheda_figura("F01", "Valori grezzi per comunità", fig / "F01_valori_grezzi.png",
            "Valori grezzi degli indicatori per metodo",
            f"Per ogni metrica e metodo, un punto per ciascuna delle {N['ncom']} comunità di soli domestici "
            "(5–18 membri), colorato per fascia di penetrazione. La barra nera è la mediana.",
            "Eccesso e coalizioni sono in quota (% di v(N), % delle coalizioni possibili), perché v(N) va "
            "da poche decine a oltre mille euro e le coalizioni sono 2ⁿ−2. Per Gini, merito e stabilità "
            "più basso è meglio; per l'incentivo più alto vuol dire più premio al sincronismo, che non è "
            "un giudizio di equità.",
            "I colori si separano quasi sempre: i punti chiari (pochi prosumer) stanno da una parte, gli "
            "scuri dall'altra. La penetrazione sposta i valori più di quanto differiscano molti metodi fra "
            "loro.",
            f"Esclusi dai valori grezzi: {esclusi} (export del 13 ottobre superato dal run del 20).",
            "f01"),
        scheda_figura("F02", "Profilo normalizzato di ciascun metodo", fig / "F02_profili_metodo.png",
            "Punteggi normalizzati per metodo",
            "Per ogni metodo, il punteggio su ciascuna metrica: in ogni comunità 1 è il metodo migliore e 0 "
            "il peggiore, con la stessa soglia di rilevanza di MAIN2.",
            "Un punteggio alto e compatto è un punto di forza stabile. Punti sparsi sono un metodo che "
            "cambia posizione al cambiare della comunità.",
            "Nucleolo e Variance Least Core sono sempre primi su merito e stabilità. Equal Split è sempre "
            "primo sul Gini e ultimo sull'incentivo. Pearson Key e Similarity-Utilization sono il "
            "contrario.",
            "Il punteggio è relativo agli altri metodi: dice chi è primo, non di quanto. La distanza in "
            "euro è in F07.",
            "f02"),
        scheda_figura("F03", "Mappa di sintesi metodo × metrica", fig / "F03_sintesi_metodi_metriche.png",
            "Mappa mediana dei punteggi",
            f"La mediana del punteggio sulle {N['ncom']} comunità, con l'intervallo interquartile fra "
            "parentesi. Sostituisce il grafico con media ± deviazione standard.",
            "Blu = metodo fra i migliori, rosso = fra i peggiori. Un intervallo interquartile largo vuol "
            "dire che la posizione dipende dalla comunità.",
            "Nessun metodo è blu su tutte le colonne: non esiste un metodo migliore in generale, e i "
            "compromessi sono strutturali.",
            "La mediana su comunità diverse nasconde il cambio di regime con la penetrazione: va letta "
            "insieme a F03b.",
            "f03"),
        scheda_figura("F03b", "La stessa mappa, per fascia di penetrazione", fig / "F03b_sintesi_per_fascia.png",
            "Mappe dei punteggi per fascia",
            "Una mappa per fascia di penetrazione; ogni cella è la mediana sulle 5 taglie.",
            "Confrontare la stessa cella da sinistra a destra: se il colore cambia, la graduatoria del "
            "metodo dipende dalla quota di prosumer.",
            f"Il cambio più netto è sull'incentivo delle regole della teoria dei giochi, rosse con "
            f"{F[f1]} di prosumer e blu dopo. Al 100% l'allineamento lordo si ribalta per quasi tutti i "
            "metodi.",
            "Ogni cella è la mediana di 5 comunità annidate (le stesse famiglie), non di 5 repliche "
            "indipendenti.",
            "f03b"),
    ]))

    v4 = viewer(fig / "assi", "F04_penetrazione", "v4")
    v5 = viewer(fig / "assi", "F05_taglia", "v5")
    blocco_assi = [
        scheda_figura("F06", "Che cosa spiega le differenze fra comunità", fig / "F06_scomposizione_varianza.png",
            "Scomposizione della varianza",
            "Una scomposizione a due vie della varianza dei punteggi fra le 20 comunità: quanta parte "
            "spiega la fascia di penetrazione, quanta la taglia, quanta resta.",
            "Barre lunghe in blu: la graduatoria dipende dalla penetrazione. In arancio: dalla taglia. Il "
            "grigio è interazione fra le due, non rumore, perché c'è una sola comunità per cella. La mappa "
            "a destra lo dice metodo per metodo; «const.» = sempre primo o sempre a pari.",
            f"La penetrazione spiega fra {pct(N['eta_pen'][0])} e {pct(N['eta_pen'][1])} (mediana "
            f"{pct(N['eta_pen_med'])}); la taglia fra {pct(N['eta_n'][0])} e {pct(N['eta_n'][1])}. "
            f"L'interazione è più alta per il {N['eta_res_max_ind']} ({pct(N['eta_res'][1])}).",
            "Vale per 5–18 membri. La fascia è il rango della penetrazione dentro la taglia (20% a 5 "
            "membri, 28% a 18).",
            "f06"),
    ]
    if v4:
        txt = ""
        if sh_f1:
            neg, tot, lo, hi = sh_f1
            txt = (f"Forza incentivante dello Shapley negativa in {neg} comunità su {tot} con {F[f1]} di "
                   f"prosumer (da {it(lo)} a {it(hi)}), positiva dalla fascia successiva. ")
            for k in ("Nucleolo", "Variance Least Core"):
                if k in seg:
                    txt += f"{k}: negativa in {segno_str(k, f1)}. "
        txt += (f"Eccesso dell'Equal Split da {it(es[f1]['min'], 0)}–{it(es[f1]['max'], 0)}% di v(N) a "
                f"{it(es[es_picco]['min'], 0)}–{it(es[es_picco]['max'], 0)}% alla fascia {F[es_picco]}, poi "
                f"di nuovo {it(es[fm]['min'], 0)}–{it(es[fm]['max'], 0)}% al {F[fm]}.")
        blocco_assi.append(scheda_figura("F04", "Le metriche lungo la penetrazione", v4, "",
            "Una figura per metrica (scegliere sopra). Un pannello per metodo; una linea per taglia; il "
            "tratteggio è la mediana fra le taglie per fascia.",
            "Ogni punto è una sola comunità, quindi non ci sono barre d'errore. La variabilità per punto è "
            "la distanza fra le linee: linee sovrapposte = l'effetto della penetrazione non dipende dalla "
            "taglia.",
            txt,
            "Fra 30% e 50% di penetrazione non c'è nessuna comunità: la soglia del cambio di segno sta lì "
            "in mezzo, non è localizzata. La taglia da 5 membri (linea più chiara) si discosta spesso: con "
            "1–3 prosumer conta il singolo impianto.",
            "f04"))
    if v5:
        blocco_assi.append(scheda_figura("F05", "Le metriche lungo la taglia", v5, "",
            "La stessa informazione di F04 vista dall'altro asse: x = membri, una linea per fascia di "
            "penetrazione.",
            "Linee orizzontali = la taglia non cambia la metrica. Linee che si incrociano = interazione fra "
            "taglia e penetrazione.",
            "Le linee sono quasi piatte da 8 membri in su; le differenze si concentrano a 5 membri.",
            "Le comunità sono annidate: quella da 18 contiene le famiglie di quella da 5. La piattezza può "
            "dipendere anche da questo.",
            "f05"))
    vn = N["vn_membro"]
    blocco_assi.append(scheda_figura("F07", "Quanto c'è in gioco, in euro", fig / "F07_posta_in_gioco.png",
        "Posta in gioco per membro",
        "A sinistra il valore da ripartire per membro; al centro quanto un membro medio può guadagnare o "
        "perdere fra il metodo più e il meno favorevole; a destra lo stesso in rapporto alla quota uguale.",
        "Le perdite fra criteri del capitolo dei risultati sono in quota dell'escursione fra i metodi. "
        "Questa figura dice quanti euro corrispondono a quella quota.",
        f"Il valore per membro va da circa {it(vn[f1], 0)} €/anno ({F[f1]}) a {it(vn[fm], 0)} €/anno "
        f"({F[fm]}); al 100% la quota dell'immissione che trova un carico è appena {pct(N['condivisa_fmax'], 0)}. "
        f"A penetrazione fissa le curve delle diverse taglie si sovrappongono (coefficiente di variazione "
        f"{pct(N['cv_vn'][0])}–{pct(N['cv_vn'][1])} da 8 membri in su). La scelta del metodo sposta da "
        f"{it(N['esc_rel'][0], 0)}% a {it(N['esc_rel'][1], 0)}% della quota uguale.",
        f"Escluso dall'escursione: {esclusi}. La sovrapposizione fra taglie va verificata con famiglie "
        "non annidate.",
        "f07"))
    S.append(("assi", "Penetrazione e taglia", "Quanto le graduatorie dipendono dalla composizione per "
              "prosumer e dal numero di membri.", blocco_assi))

    qs = N["quota_sh"]
    qtxt = ""
    if qs:
        fq = sorted(qs)
        qtxt = (f"Per lo Shapley il rapporto scende da {it(qs[fq[0]][0])}–{it(qs[fq[0]][1])} ({F[fq[0]]}) a "
                f"{it(qs[fq[-1]][0])}–{it(qs[fq[-1]][1])} ({F[fq[-1]]}). ")
    lordo = N["lordo_sh_f1"]
    S.append(("meccanismi", "Meccanismi e compromessi", "Perché le graduatorie cambiano, e quanto costa "
              "un criterio in termini di un altro.", [
        scheda_figura("F09", "Chi viene premiato: prosumer o consumatori", fig / "F09_quota_prosumer.png",
            "Quota di v(N) ai prosumer",
            "La quota di v(N) che va ai prosumer divisa per la loro quota di membri, contro la penetrazione.",
            "Sopra 1 i prosumer ricevono più del loro numero; sotto 1 meno; 0 = nulla. Scala logaritmica "
            "sopra 0,05.",
            qtxt + "Le regole della teoria dei giochi premiano il lato scarso e cambiano lato con la "
            "penetrazione: è il meccanismo dietro il cambio di segno della forza incentivante (F04). Pearson "
            "Key e Similarity-Utilization danno sempre poco ai prosumer.",
            ("Il segno negativo alla fascia più bassa non è solo un effetto dei profili netti: sull'asse "
             f"lordo lo Shapley è negativo in {lordo[0]} comunità su {lordo[1]}. " if lordo else "")
            + "Al 100% di penetrazione il rapporto vale 1 per costruzione ed è omesso.",
            "f09"),
        scheda_figura("F08", "I compromessi in unità naturali", fig / "F08_compromessi.png",
            "Compromessi fra criteri",
            "Tre coppie di criteri (uguaglianza–stabilità, uguaglianza–incentivo, incentivo–stabilità), "
            "una colonna per fascia. Punto piccolo = una comunità, punto grande = mediana del metodo.",
            "In basso a sinistra (Gini e eccesso bassi) e in alto (incentivo alto) stanno le scelte "
            "migliori. Un metodo che migliora un asse spostandosi in diagonale sull'altro mostra il "
            "compromesso.",
            "Da metà penetrazione in su uguaglianza e incentivo stanno su una diagonale quasi perfetta: "
            "nessun metodo li ottiene insieme. Con pochi prosumer la diagonale non c'è.",
            "Le mediane mescolano 5 comunità annidate per fascia.",
            "f08"),
        scheda_figura("F12", "Gli indicatori concordano?", fig / "F12_accordo_indicatori.png",
            "Accordo fra indicatori",
            "Il τ-b di Kendall medio fra le graduatorie che le 8 metriche danno dei metodi, per fascia.",
            "Blu = due metriche ordinano i metodi allo stesso modo; rosso = in modo opposto; bianco = "
            "indipendenti.",
            f"τ(Gini, forza incentivante): {', '.join(f'{it(tg[f])} ({F[f]})' for f in sorted(tg))}. "
            f"Merito e stabilità concordano sempre di più: τ(Fairness Index, eccesso) da {it(tf[f1])} a "
            f"{it(tf[max(tf)])}. Il sottoinsieme minimo di indicatori dipende quindi dalla fascia.",
            "Media di 5 τ, ciascuno su 11 metodi: piccole differenze di τ corrispondono a poche coppie.",
            "f12"),
    ]))

    if "pa_shift" in N:
        sh = N["pa_shift"]
        rho = N["pa_rho"]
        forti = "; ".join(f"{m} su {NOMI_METRICHE.get(i, i)} con {lv} ({it(d, 1)})" for lv, m, i, d in N["pa_forti"])
        blocco_pa = [
            scheda_figura("F10", "L'effetto degli edifici pubblici", fig / "F10_effetto_composizione.png",
                "Effetto appaiato della composizione",
                "Per ogni metodo e metrica, la differenza di punteggio fra la stessa comunità con e senza "
                "edifici pubblici (stessi membri, stessi prosumer), mediana sulle comunità appaiate.",
                "Verde = il metodo sale in graduatoria con le PA, marrone = scende. ° = meno dell'80% delle "
                "comunità concorda sul segno.",
                f"Spostamento medio sulle {N['pa_comuni']} comunità comuni ai tre livelli: "
                + ", ".join(f"{k} {it(v)}" for k, v in sh.items())
                + f". Effetti più grandi e coerenti: {forti}.",
                "PA1, PA2 e PA3 aggiungono edifici diversi (comune, scuola, palazzetto), non dosi diverse "
                "dello stesso trattamento. PA2 e PA3 non hanno le schede a bassa penetrazione. Δ è "
                "relativo: un metodo può scendere perché un altro sale.",
                "f10"),
            scheda_figura("F11", "Scala o composizione?", fig / "F11_scala_e_quote_PA.png",
                "Scala contro spostamento delle graduatorie",
                "A sinistra lo spostamento medio delle graduatorie di ogni comunità contro quanto cresce "
                "v(N) aggiungendo gli edifici; a destra quanto prendono gli edifici rispetto al loro numero.",
                "Se l'effetto fosse solo di scala, i punti salirebbero verso destra anche dentro ciascun "
                "colore.",
                f"Sommando i livelli la correlazione con la scala è {it(N['pa_rho_tutti'])}; dentro i "
                "livelli è " + ", ".join(f"{it(v)} ({k})" for k, v in rho.items())
                + ". La correlazione complessiva viene dalle differenze fra livelli (paradosso di Simpson), "
                "non dalla scala: conta quale edificio entra.",
                "Il disegno non separa scala e composizione. Serve un confronto 2 × 2: profilo da PA a "
                "volume domestico, profilo domestico a volume da PA.",
                "f11"),
        ]
        for p in sorted(fig.glob("F13_grezzi_*.png")):
            lv = p.stem.split("_")[-1]
            blocco_pa.append(scheda_figura("F13", f"Valori grezzi con e senza {lv}", p, f"Valori grezzi {lv}",
                f"Ogni punto è una coppia (comunità, metodo): x = senza edifici pubblici, y = con {lv}.",
                "Sopra la diagonale il valore cresce con le PA.", "Da leggere sui dati nuovi.",
                "Disponibile solo con un export che contiene più livelli.", f"f13-{lv}"))
        S.append(("composizione", "La composizione: edifici pubblici", "La terza dimensione della domanda "
                  "di ricerca, nei dati del 20 ottobre (PA0–PA3).", blocco_pa))

    # ---------------------------------------------------------------- assemblaggio
    nav = ['<span class="lbl">Pagina</span>', '<a href="#sintesi">In sintesi</a>',
           '<a href="#metodo">Dati e metodo</a>', '<a href="#scelte">Scelte da approvare</a>']
    corpo = []
    for sid, tit, intro, blocchi in S:
        nav.append(f'<span class="lbl">{tit}</span>')
        for b in blocchi:
            m = re.search(r'id="([^"]+)".*?<span class="fid">([^<]+)</span><h3>([^<]+)</h3>', b, re.S)
            nav.append(f'<a href="#{m.group(1)}">{m.group(2)} · {m.group(3)}</a>')
        corpo.append(f'<section class="sec" id="{sid}"><div class="sec-intro"><h2>{tit}</h2>'
                     f'<p class="lead">{intro}</p></div>{"".join(blocchi)}</section>')
    nav += ['<span class="lbl">Chiusura</span>', '<a href="#conclusioni">Conclusioni e limiti</a>',
            '<a href="#prossimi">Prossimi passi</a>', '<a href="#verifiche">Verifiche</a>']

    taglie = ", ".join(str(t) for t in N["taglie"])
    fasce = ", ".join(F[f] for f in sorted(F))
    pagina = f"""<title>Ripartizione CER: risultati</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;600&family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Serif:wght@600&display=swap">
<style>{CSS}</style>
<div class="wrap">
<nav class="toc" aria-label="Indice">{"".join(nav)}</nav>
<main>
<header class="intro">
  <div class="eyebrow">Tesi magistrale · Comunità energetiche rinnovabili</div>
  <h1>Come cambiano le graduatorie dei metodi di ripartizione</h1>
  <p class="lead">Dodici regole per dividere l'incentivo sull'energia condivisa, valutate con gli stessi
  indicatori di uguaglianza, merito, stabilità e premio al sincronismo, su comunità di taglia, quota di
  prosumer e composizione diverse. Ogni figura ha la spiegazione e il risultato che ne segue.</p>
  <p class="meta">Dati: run MAIN2 del 20 ottobre 2026 (76 comunità) · export del 13 ottobre per i valori
  grezzi · pagina generata il {date.today().strftime('%d/%m/%Y')} da <code>grafici_metodi.py</code>.
  Clic su una figura per ingrandirla.</p>
</header>

<section class="sec" id="sintesi"><div class="sec-intro"><h2>In sintesi</h2>
<p class="lead">I risultati principali, con il rimando alla figura che li sostiene.</p></div>
<ol class="key">{"".join(f"<li><span>{s}</span></li>" for s in sintesi)}</ol></section>

<section class="sec" id="metodo"><div class="sec-intro"><h2>Dati e metodo</h2></div>
<p><b>Comunità.</b> Griglia di soli domestici con {len(N['taglie'])} taglie ({taglie} membri) e 4 fasce
di penetrazione ({fasce}), una comunità per cella; più tre livelli con edifici pubblici a membri e
prosumer invariati. Le famiglie vengono da una società simulata di 100 nuclei lombardi, un anno orario.</p>
<p><b>Metriche.</b> Uguaglianza (Gini), merito (Fairness Index, σ), stabilità (eccesso massimo,
coalizioni instabili), incentivo (forza incentivante, allineamento netto e lordo). Inclusione e VAN del
membro peggiore sono un'analisi a parte.</p>
<p><b>Punteggio normalizzato.</b> In ogni comunità e metrica, 1 = metodo migliore e 0 = peggiore, con la
soglia di rilevanza di MAIN2 (10% dell'escursione, 5% di v(N) per l'eccesso). È il complemento del
«rimpianto» di <code>tradeoff_losses.m</code>.</p>
<p><b>Variabilità.</b> Ogni comunità è una sola simulazione deterministica: non ci sono repliche. Le
comunità sono inoltre annidate (quella da n membri usa le prime n famiglie), e a taglia fissa le fasce
hanno le stesse famiglie. Per questo le figure mostrano tutti i punti, la mediana e l'intervallo
interquartile, mai media ± deviazione standard su punti fatti da una sola comunità, e nessun intervallo di
confidenza: la griglia è un disegno scelto, non un campione casuale.</p>
</section>

<section class="sec" id="scelte"><div class="sec-intro"><h2>Scelte da approvare</h2>
<p class="lead">Le scelte di metodo che determinano le figure. Sono quelle su cui serve l'accordo prima di
scrivere il capitolo dei risultati.</p></div>
<div class="tbl"><table class="decisione"><thead><tr><th>Scelta</th><th>Motivo</th></tr></thead><tbody>
<tr><td>Otto metriche in quattro gruppi</td><td>EI_orig vale 1 − Gini e duplicherebbe il Gini. Inclusione LIHC (nessuna famiglia vulnerabile con i redditi Istat) e VAN del membro peggiore restano un'analisi a parte.</td></tr>
<tr><td>Eccesso in % di v(N), coalizioni in % di 2ⁿ−2</td><td>Dentro una comunità ordinano i metodi come i valori in euro e in conteggio, ma fra comunità diverse solo le quote sono confrontabili.</td></tr>
<tr><td>Punteggio relativo con soglia di rilevanza</td><td>È la stessa definizione delle tabelle di MAIN2 (perdite fra criteri, inversioni), quindi figure e tabelle dicono la stessa cosa.</td></tr>
<tr><td>Distribuzioni invece di media ± std; niente intervalli di confidenza</td><td>Non ci sono repliche: la dispersione fra comunità è un effetto della configurazione, non incertezza di stima.</td></tr>
<tr><td>Confronto con le PA appaiato per scheda</td><td>Le medie per livello mescolerebbero insiemi di comunità diversi (PA2 e PA3 hanno meno schede).</td></tr>
<tr><td>Forza incentivante riportata con il suo verso convenzionale</td><td>Più alta = più premio al sincronismo. Non è un giudizio di equità, e il testo non la tratta come tale.</td></tr>
<tr><td>Adaptive Sampling Shapley fuori dove c'è lo Shapley esatto</td><td>Scarto dello 0,3–0,8% di v(N): tenerlo raddoppierebbe un metodo.</td></tr>
</tbody></table></div></section>

{"".join(corpo)}

<section class="sec" id="conclusioni"><div class="sec-intro"><h2>Conclusioni e limiti</h2></div>
<p><b>Cosa si può sostenere.</b> Non esiste un metodo migliore su tutto, e la graduatoria dipende
soprattutto dalla quota di prosumer: le regole della teoria dei giochi premiano il lato scarso e cambiano
segno sull'incentivo, il conflitto fra uguaglianza e incentivo compare da metà penetrazione, la stabilità
delle regole semplici è peggiore a penetrazione medio-alta. Per la tesi questo risponde a come le
graduatorie varino con taglia e penetrazione, e quantifica i compromessi anche in euro.</p>
<p><b>Cosa non si può sostenere con questi dati.</b></p>
<div class="tbl"><table><thead><tr><th>Affermazione</th><th>Perché no</th><th>Cosa servirebbe</th></tr></thead><tbody>
<tr><td>I risultati valgono per comunità reali in generale</td><td>Una società simulata, un anno, una zona, famiglie annidate</td><td>Repliche con altre estrazioni di famiglie; un secondo anno o una seconda zona</td></tr>
<tr><td>La taglia non conta</td><td>Solo 5–18 membri, comunità annidate</td><td>Run fino a 25 membri con i parametri attuali; repliche</td></tr>
<tr><td>Le PA cambiano le graduatorie perché cambia la composizione</td><td>Scala e composizione cambiano insieme; un edificio per tipo</td><td>Confronto 2 × 2 forma del profilo × volume</td></tr>
<tr><td>La regola X induce comportamenti virtuosi</td><td>La forza incentivante è una covarianza ex post, non una risposta dei membri</td><td>Un modello di risposta, fuori dallo scope</td></tr>
<tr><td>Il cambio di regime avviene a una soglia precisa</td><td>Nessuna comunità fra 30% e 50% di penetrazione</td><td>2–3 schede a 35–45% per taglia</td></tr>
</tbody></table></div></section>

<section class="sec" id="prossimi"><div class="sec-intro"><h2>Prossimi passi</h2></div>
<div class="tbl"><table><thead><tr><th>Passo</th><th>Cosa serve</th><th>Valore per la tesi</th></tr></thead><tbody>
<tr><td>Perdite fra criteri in €/membro per fascia</td><td>Tabelle esistenti</td><td>Rende confrontabile «quanto si perde» fra comunità con poste diverse</td></tr>
<tr><td>Sottoinsieme minimo di indicatori per fascia</td><td>Tabelle esistenti</td><td>Il sottoinsieme potrebbe cambiare con la penetrazione (F12)</td></tr>
<tr><td>Valori grezzi con le PA (F13)</td><td>Riesportare il run del 20 ottobre con <code>esporta_run.m</code> aggiornato</td><td>Gli effetti della composizione in unità naturali</td></tr>
<tr><td>Livelli con imprese</td><td>Run in corso; controllare la colonna <code>Binding</code> (soglia del 55%)</td><td>Completa l'asse della composizione</td></tr>
<tr><td>Repliche con famiglie diverse a 10 membri</td><td>Nuove simulazioni, costo contenuto</td><td>Rende difendibili barre d'errore e test</td></tr>
</tbody></table></div></section>

<section class="sec" id="verifiche"><div class="sec-intro"><h2>Verifiche</h2>
<p class="lead">Controlli automatici dell'ultima generazione: livelli trovati, copertura delle metriche,
coerenza fra export e tabelle.</p></div>
<details><summary>Mostra i controlli</summary><pre>{html.escape(N['controlli'])}</pre></details>
</section>
</main>
</div>
<script>{JS}</script>
"""
    return pagina


def costruisci(fig, tab, apri=False, frammento=None):
    fig, tab = Path(fig), Path(tab)
    corpo = costruisci_pagina(fig, tab)
    doc = ('<!doctype html>\n<html lang="it">\n<meta charset="utf-8">\n'
           '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
           + corpo + "\n</html>\n")
    dest = fig / "index.html"
    dest.write_text(doc, encoding="utf-8")
    if frammento:
        Path(frammento).write_text(corpo, encoding="utf-8")
    url = dest.resolve().as_uri()
    print(f"pagina dei risultati: {url}  ({dest.stat().st_size / 1e6:.1f} MB)")
    if apri:
        webbrowser.open(url)
    return dest


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--figure", default="outputs/figures_tesi")
    ap.add_argument("--numeri", default="outputs/tables_tesi")
    ap.add_argument("--apri", action="store_true")
    ap.add_argument("--frammento", default=None)
    a = ap.parse_args()
    costruisci(a.figure, a.numeri, apri=a.apri, frammento=a.frammento)
