"""Pagina HTML con le figure di grafici_metodi.py, senza testo interpretativo.

Uso, dalla root del progetto (dopo grafici_metodi.py --senza-pagina):
    python -I outputs/workspace/strumenti/pagina_figure.py --figure DIR --numeri DIR [--titolo T] [--apri]

Scrive <figure>/index.html: un file unico, con le immagini incorporate. A differenza di
pagina_risultati.py NON contiene conclusioni: quella pagina ha frasi scritte per i dati del
20 ottobre e pretende tutte le figure, anche F01/F07/F08, che esistono solo con un export
del run. Qui ogni figura ha una didascalia che dice COSA mostra, e le figure che mancano
sono semplicemente assenti; le note di controllo di grafici_metodi.py (controlli.txt) stanno
in fondo, cosi' si vede cosa e' stato escluso e perche'.
"""
import argparse
import base64
import html
import webbrowser
from pathlib import Path

FIGURE = [
    ("F03_sintesi_metodi_metriche", "Punteggio mediano per metodo e metrica",
     "Mediana, fra le comunita' del blocco, del punteggio normalizzato (1 = il migliore in quella "
     "comunita', 0 = il peggiore); fra parentesi l'intervallo interquartile. Le metriche senza dati "
     "non compaiono."),
    ("F03b_sintesi_per_fascia", "Stessa mappa per fascia di penetrazione",
     "Come sopra, ma una mappa per fascia di penetrazione dei prosumer."),
    ("F02_profili_metodo", "Punteggio per comunita', un pannello per metodo",
     "Ogni punto e' una comunita', colorato per fascia di penetrazione; il trattino e' la mediana."),
    ("F06_scomposizione_varianza", "Quanta variabilita' spiegano penetrazione e taglia",
     "Quota di varianza del punteggio spiegata da penetrazione, taglia e dalla loro interazione, "
     "per indicatore."),
    ("F09_quota_prosumer", "Quota ai prosumer",
     "Quota di ricavo che ogni metodo assegna ai prosumer, per fascia di penetrazione."),
    ("F10_effetto_composizione", "Effetto di aggiungere PA o imprese",
     "Differenza mediana di punteggio fra ogni livello di composizione e le sole famiglie, a parita' "
     "di scheda. Un pannello per livello; ° = meno dell'80% delle comunita' concorda col segno."),
    ("F11_scala_e_quote_PA", "Effetto di scala e quota che prendono le PA",
     "A sinistra: spostamento medio di punteggio contro il rapporto fra il v(N) del livello e quello "
     "delle sole famiglie (colore = numero di PA, forma = numero di imprese). A destra: rapporto fra "
     "la quota di v(N) che va alle PA e la loro quota di membri, mediana per metodo e livello."),
    ("F12_accordo_indicatori", "Accordo fra gli indicatori",
     "Tau-b di Kendall medio fra le graduatorie dei metodi prodotte da coppie di indicatori, per "
     "fascia di penetrazione."),
]


def costruisci(fig, tab, titolo, apri=False):
    blocchi = []
    for nome, h, didascalia in FIGURE:
        p = fig / f"{nome}.png"
        if not p.exists():
            continue
        b64 = base64.b64encode(p.read_bytes()).decode()
        blocchi.append(
            f"<section id='{nome}'><h2>{html.escape(h)}</h2><p>{html.escape(didascalia)}</p>"
            f"<a href='{nome}.pdf'><img alt='{html.escape(h)}' src='data:image/png;base64,{b64}'></a>"
            f"<p class='file'>{nome}.png / .pdf</p></section>")
    controlli = ""
    c = tab / "controlli.txt"
    if c.exists():
        controlli = ("<section><h2>Note di controllo</h2><pre>"
                     + html.escape(c.read_text(encoding="utf-8")) + "</pre></section>")
    indice = "".join(f"<a href='#{n}'>{html.escape(h)}</a>" for n, h, _ in FIGURE if (fig / f"{n}.png").exists())
    pagina = f"""<!doctype html>
<html lang="it"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(titolo)}</title>
<style>
:root {{ --bg:#fff; --ink:#13272c; --muted:#52686d; --rule:#d3dedf; --accent:#0a6b70; }}
@media (prefers-color-scheme: dark) {{ :root {{ --bg:#0e191b; --ink:#e2eded; --muted:#98afb2;
  --rule:#2a3e43; --accent:#5fc3c7; }} }}
body {{ background:var(--bg); color:var(--ink); font:16px/1.55 system-ui,"Segoe UI",sans-serif; margin:0; }}
main {{ max-width:1180px; margin:0 auto; padding:24px 16px 64px; }}
h1 {{ font-size:28px; margin:0 0 4px; }}
h2 {{ font-size:20px; margin:0 0 4px; }}
nav {{ display:flex; flex-wrap:wrap; gap:6px 16px; margin:12px 0 24px; font-size:14px; }}
a {{ color:var(--accent); }}
section {{ border-top:1px solid var(--rule); padding:20px 0; }}
img {{ max-width:100%; height:auto; background:#fff; border:1px solid var(--rule); }}
.file {{ color:var(--muted); font-size:13px; margin:4px 0 0; }}
p {{ margin:0 0 10px; max-width:75ch; }}
pre {{ white-space:pre-wrap; font:13px/1.45 ui-monospace,Consolas,monospace; overflow-x:auto; }}
</style></head><body><main>
<h1>{html.escape(titolo)}</h1>
<p class="file">Pagina generata da grafici_metodi.py: i numeri vengono dai CSV, non ci sono commenti
interpretativi. Le figure sono vettoriali (PDF) cliccando sull'immagine.</p>
<nav>{indice}</nav>
{''.join(blocchi)}
{controlli}
</main></body></html>"""
    (fig / "index.html").write_text(pagina, encoding="utf-8")
    print(f"pagina: {fig / 'index.html'}  ({len(pagina) / 1e6:.1f} MB)")
    if apri:
        webbrowser.open((fig / "index.html").resolve().as_uri())


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--figure", required=True)
    ap.add_argument("--numeri", required=True)
    ap.add_argument("--titolo", default="Ripartizione CER: risultati")
    ap.add_argument("--apri", action="store_true")
    a = ap.parse_args()
    costruisci(Path(a.figure), Path(a.numeri), a.titolo, a.apri)
