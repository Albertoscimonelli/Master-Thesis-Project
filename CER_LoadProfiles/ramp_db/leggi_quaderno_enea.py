"""Estrae dai documenti di benchmark gli indici di consumo specifico, con la pagina.

Serve al passo 3 della validazione non domestica: dare una FONTE agli apparecchi
degli archetipi RAMP. Oggi i numeri di `office.py` (20 plafoniere da 40 W, 8 PC
da 200 W, 2 climatizzatori da 2,5 kW) non sono attribuibili ad alcun documento;
gli indici di prestazione energetica per uso finale lo sono, e ogni ramo
dell'albero energetico diventa un gruppo di `Appliance`.

COSA FA E COSA NON FA. Questo modulo **propone**, non decide. Percorre un PDF,
trova le righe che contengono un valore con un'unita' di misura di consumo
specifico, e le stampa con il numero di pagina. Le righe proposte per
`benchmark_letteratura.csv` escono sempre con `verificato = no`: un numero
riportato di seconda mano non e' una citazione, e in tesi si vede. Il passaggio
a `si` si fa a mano, dopo aver riletto il valore sul documento alla pagina
indicata. L'estrazione automatica da PDF e' inaffidabile per costruzione - le
tabelle diventano righe sciolte, le intestazioni si separano dai valori - e
questo strumento serve a *trovare* i numeri in fretta, non a fidarsene.

I TRE DOCUMENTI gia' presenti in `File Non Domestici/`:

  - ENEA con Assoimmobiliare, *Uffici - Quaderni dell'Efficienza Energetica*,
    Ricerca di Sistema Elettrico 2022-2024 (MASE): guida alla diagnosi
    energetica del settore uffici ex Allegato II del D.Lgs. 102/2014. Il §4.3
    porta gli IPE di secondo livello, cioe' il consumo per uso finale
    (illuminazione, climatizzazione, ICT, data center): e' l'albero energetico
    su cui riscrivere `office.py`.
  - Corgnati, Fabrizio, Ariaudo, Rollino, *Edifici tipo, indici di benchmark di
    consumo per tipologie di edificio, ad uso scolastico (medie superiori e
    istituti tecnici)*, Report RSE/2010, Accordo di Programma MSE-ENEA: il
    benchmark per `scuola_superiore`. Attenzione alla data: e' del 2010.
  - RSE, *I consumi della Pubblica Amministrazione* (RSEview): il §3.3 tratta
    gli uffici pubblici "dall'amministrazione centrale a quelli
    dell'amministrazione regionale sino al livello comunale", quindi comprende
    il municipio di `comune.py`.

Uso:
    python leggi_quaderno_enea.py --elenca
    python leggi_quaderno_enea.py --pdf "<percorso>" --pagine 75 78
    python leggi_quaderno_enea.py --pdf "<percorso>" --proponi
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

try:
    import pypdf
except ImportError:
    sys.exit("Serve pypdf: ../../venv/Scripts/python.exe -m pip install pypdf")

from riferimento_arera_nd import radice

QUI = Path(__file__).resolve().parent
TABELLA = QUI / "benchmark_letteratura.csv"

# I documenti attesi, con l'etichetta con cui compaiono nella tabella.
DOCUMENTI = {
    "ENEA_uffici": "uffici-quaderni-efficienza-energetica.pdf",
    "RSE_scuole": "Edifici tipo indici di benchmark di consumo per tipologie "
                  "di uso scolastico.pdf",
    "RSEview_PA": "consumi della pubblica amministrazione.pdf",
}

# Un valore di consumo specifico e' un numero seguito da un'unita'. Si accettano
# sia la virgola decimale sia il simbolo di deviazione standard, perche' questi
# documenti scrivono quasi sempre "25,7 +/- 11,8 kWh/m2".
UNITA = r"kWh/m\s*[²2q]|kWh/mq|tep/m\s*[²2]|kWh/anno|kWh/addetto"
VALORE = re.compile(
    r"(\d{1,3}(?:\.\d{3})*(?:,\d+)?)\s*(?:±\s*(\d{1,3}(?:[.,]\d+)?))?\s*(" + UNITA + ")",
    re.IGNORECASE,
)

# L'unita' da sola, ovunque compaia. Serve perche' VALORE trova soltanto i
# numeri ATTACCATI all'unita', e in molte tabelle non lo sono: nel report RSE
# sulle scuole l'unita' sta nell'intestazione di colonna ("Bench. [kWh/m2] RoT
# [kWh/m2]") e i valori stanno su una riga tutta loro ("Energia elettrica 15
# 30"). Cercando solo VALORE quel documento risultava privo di indici, mentre ne
# ha. Una pagina che contiene l'unita' ma nessun valore adiacente va quindi
# segnalata come DA LEGGERE A MANO, non scartata in silenzio.
SOLO_UNITA = re.compile(UNITA, re.IGNORECASE)

# Righe che parlano di indici ma senza numeri sulla stessa riga: nei PDF
# impaginati su tabelle l'etichetta e il valore finiscono spesso separati, e
# vederle aiuta a capire a quale tabella appartiene un numero orfano.
CONTESTO = re.compile(
    r"IPE|indice di prestazione|benchmark|consumo specifico|tabella\s+\d|"
    r"illuminazione|climatizzazione|infrastruttura informatica|data center|"
    r"energia elettrica", re.IGNORECASE)


def percorso_documento(nome_o_percorso: str) -> Path:
    """Accetta un percorso completo oppure una delle etichette di DOCUMENTI."""
    if nome_o_percorso in DOCUMENTI:
        trovati = sorted(radice().glob(f"**/{DOCUMENTI[nome_o_percorso]}"))
        if not trovati:
            sys.exit(f"Documento '{nome_o_percorso}' non trovato sotto {radice()}")
        return trovati[0]
    percorso = Path(nome_o_percorso)
    if not percorso.exists():
        sys.exit(f"File non trovato: {percorso}")
    return percorso


def pagine_testo(percorso: Path) -> list[str]:
    """Testo di ogni pagina. L'indice della lista e' la pagina meno uno."""
    lettore = pypdf.PdfReader(str(percorso))
    return [(p.extract_text() or "") for p in lettore.pages]


def valori(percorso: Path, da: int = 1, a: int | None = None) -> list[dict]:
    """Tutti i valori con unita' di consumo specifico, con la loro pagina.

    Returns:
        lista di dizionari con pagina, valore, deviazione, unita', riga.
    """
    trovati = []
    pagine = pagine_testo(percorso)
    a = a or len(pagine)
    for numero, testo in enumerate(pagine[da - 1:a], start=da):
        for riga in testo.splitlines():
            for m in VALORE.finditer(riga):
                trovati.append({
                    "pagina": numero,
                    "valore": m.group(1),
                    "deviazione": m.group(2) or "",
                    "unita": m.group(3),
                    "riga": riga.strip()[:90],
                })
    return trovati


def pagine_con_unita(percorso: Path) -> list[int]:
    """Pagine che contengono un'unita' di consumo specifico, ovunque nella pagina."""
    return [n for n, t in enumerate(pagine_testo(percorso), start=1)
            if SOLO_UNITA.search(t)]


def elenca() -> None:
    """Quali documenti ci sono, quante pagine, e dove stanno i numeri.

    Si stampano DUE insiemi di pagine, e la differenza fra i due e' il punto:
    le pagine con valore e unita' attaccati sono leggibili in automatico, quelle
    con la sola unita' hanno la tabella spezzata dall'estrazione e vanno lette a
    mano con --pagine. Confondere i due insiemi fa concludere che un documento
    non abbia indici quando invece li ha.
    """
    print(f"\nDOCUMENTI DI BENCHMARK sotto {radice()}\n")
    for etichetta, schema in DOCUMENTI.items():
        trovati = sorted(radice().glob(f"**/{schema}"))
        if not trovati:
            print(f"  {etichetta:14} ASSENTE ({schema})")
            continue
        percorso = trovati[0]
        pagine = pagine_testo(percorso)
        con_valori = sorted({v["pagina"] for v in valori(percorso)})
        con_unita = pagine_con_unita(percorso)
        solo_unita = [p for p in con_unita if p not in con_valori]
        print(f"  {etichetta:14} {len(pagine):>4} pagine")
        print(f"  {'':14} {len(con_valori):>4} con valore e unita' attaccati: "
              f"{con_valori[:16]}{' ...' if len(con_valori) > 16 else ''}")
        print(f"  {'':14} {len(solo_unita):>4} con la sola unita', DA LEGGERE A "
              f"MANO: {solo_unita[:16]}{' ...' if len(solo_unita) > 16 else ''}")
        if not any(p.strip() for p in pagine):
            print(f"  {'':14} ATTENZIONE: nessun testo estraibile, PDF scansionato")


def mostra(percorso: Path, da: int, a: int) -> None:
    """Stampa le pagine richieste evidenziando valori e righe di contesto."""
    pagine = pagine_testo(percorso)
    for numero in range(da, min(a, len(pagine)) + 1):
        print(f"\n{'=' * 78}\npagina {numero}\n{'=' * 78}")
        for riga in pagine[numero - 1].splitlines():
            pulita = riga.strip()
            if not pulita:
                continue
            if VALORE.search(pulita):
                print(f"  >> {pulita}")
            elif CONTESTO.search(pulita):
                print(f"   . {pulita}")


def proponi(percorso: Path, etichetta: str, da: int, a: int | None) -> None:
    """Emette righe candidate per benchmark_letteratura.csv, tutte da verificare.

    Le colonne sono quelle della tabella: fonte, anno, tipologia, indicatore,
    valore, unita, campione, pagina, url, verificato. Tipologia e indicatore
    restano da compilare a mano, perche' dedurli dalla riga estratta sarebbe
    esattamente il tipo di inferenza che questo strumento non deve fare.
    """
    print("fonte;anno;tipologia;indicatore;valore;unita;campione;pagina;url;verificato")
    for v in valori(percorso, da, a):
        valore = v["valore"] + (f" ± {v['deviazione']}" if v["deviazione"] else "")
        print(f"{etichetta};;;{v['riga']};{valore};{v['unita']};;"
              f"{v['pagina']};;no")


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--pdf", default=None,
                        help="percorso del PDF, oppure un'etichetta fra "
                             + ", ".join(DOCUMENTI))
    parser.add_argument("--elenca", action="store_true",
                        help="elenca i documenti disponibili e le pagine con numeri")
    parser.add_argument("--pagine", type=int, nargs=2, metavar=("DA", "A"),
                        default=None, help="intervallo di pagine da mostrare")
    parser.add_argument("--proponi", action="store_true",
                        help="emette righe CSV candidate, tutte con verificato=no")
    args = parser.parse_args()

    if args.elenca or args.pdf is None:
        elenca()
        if args.pdf is None:
            return

    percorso = percorso_documento(args.pdf)
    etichetta = args.pdf if args.pdf in DOCUMENTI else percorso.stem

    if args.proponi:
        da, a = args.pagine if args.pagine else (1, None)
        proponi(percorso, etichetta, da, a)
        return

    if args.pagine:
        mostra(percorso, args.pagine[0], args.pagine[1])
        return

    trovati = valori(percorso)
    print(f"\n{percorso.name}: {len(trovati)} valori con unita' di consumo "
          f"specifico\n")
    for v in trovati[:60]:
        print(f"  p.{v['pagina']:>3}  {v['valore']:>10} "
              f"{('± ' + v['deviazione']) if v['deviazione'] else '':>10} "
              f"{v['unita']:<10} {v['riga'][:60]}")
    if len(trovati) > 60:
        print(f"  ... e altri {len(trovati) - 60}. Usare --pagine per leggerli.")
    print("\nNessun valore e' una citazione finche' non e' stato riletto sul")
    print("documento alla pagina indicata: le righe proposte escono con")
    print("verificato = no, e il passaggio a si si fa a mano.")


if __name__ == "__main__":
    main()
