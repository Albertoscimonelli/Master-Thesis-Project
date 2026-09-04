"""ARERA non domestico: il giudice del LIVELLO e della STAGIONALITA'.

COS'E' QUESTA FONTE. I dati provinciali ARERA sui prelievi non domestici in
bassa tensione: per ogni Provincia, banda di potenza e classe ATECO, il
PRELIEVO MEDIO MENSILE per punto di prelievo. E' energia misurata al contatore,
quindi il giudice piu' solido che questo lavoro abbia sul lato non domestico.

DUE ASIMMETRIE RISPETTO AL LATO DOMESTICO, da tenere a mente:

1. E' SOLO MENSILE. Non esiste il dettaglio orario che ARERA pubblica per i
   domestici. Quindi questa fonte giudica il LIVELLO annuo e la FORMA MENSILE
   (la stagionalita'), mai la forma della giornata: quella la giudica il GSE,
   in riferimento_gse.py.

2. E' SOLO IL 2025. Manca la coppia di anni con cui, sul lato domestico, si e'
   costruita la soglia di accettazione. Al suo posto questo modulo offre tre
   surrogati, che vanno riportati tutti e tre perche' misurano tre arbitrarieta'
   diverse: rumore_geografico() (quanto la stessa classe varia fra province),
   rumore_banda() (quanto pesa l'assunzione sulla banda di potenza) e
   rumore_classe() (quanto pesa la scelta della classe rappresentativa).

TRE TRAPPOLE DI LETTURA, tutte verificate sui file:

a) LA RIGA CON ATECO VUOTO NON E' IL TOTALE. Esiste una riga per mese con tutte
   e quattro le colonne ATECO vuote: e' la categoria "non attribuito", non la
   somma. A Milano BTA6 vale 30.736 kWh/anno mentre la sola classe 84.11 ne
   vale 50.310, e un totale non puo' essere minore di un suo addendo. Va
   esposta come una categoria a se' - la restituisce classe_non_attribuita() -
   e mai usata come bersaglio complessivo.

b) I VALORI SONO MEDIE PER PUNTO, non totali di provincia. Non essendoci il
   NUMERO di clienti per classe, non si puo' costruire una media pesata di
   Sezione o Divisione: e' lo stesso limite gia' dichiarato per i domestici.
   Il livello della singola classe e' pero' direttamente utilizzabile.

c) ALCUNE CLASSI HANNO MENO DI DODICI MESI, per soppressione statistica quando
   i clienti sono pochi. Sommarne sei darebbe in silenzio un livello annuo
   dimezzato, quindi livello_annuo() le RIFIUTA invece di sommarle.

Nota sulle bande: due file portano l'etichetta BTA3, uno per 3-4,5 kW e uno per
4,5-6 kW; e BTA5 (>10) e BTA6 (>16,5) si sovrappongono. E' come ARERA le
pubblica: qui si usano chiavi brevi non ambigue, elencate in BANDE.

Uso:
    python riferimento_arera_nd.py --provincia Milano --banda ">16.5"
    python riferimento_arera_nd.py --provincia Milano --banda ">16.5" --ateco 85.31
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import pandas as pd

from riferimento_gse import radice

QUI = Path(__file__).resolve().parent
CACHE = QUI / "dati" / "riferimento_arera_nd"

# Chiave breve -> etichetta esatta nella colonna 'Tariffa potenza kW'.
# La chiave e' quella da usare in configurazione e nel report; l'etichetta
# serve solo a filtrare le righe.
BANDE: dict[str, str] = {
    "0-1.5": "BTA1: 0 <>= 1,5",
    "1.5-3": "BTA2: 1,5 <>= 3",
    "3-4.5": "BTA3: 3 <>= 4,5",
    "4.5-6": "BTA3: 4,5 <>= 6",
    "6-10": "BTA4: 6 <>= 10",
    ">10": "BTA5: >10",
    ">16.5": "BTA6: potenza disponibile >16,5",
}

# Frammento del nome file per ciascuna banda.
FILE_BANDA: dict[str, str] = {
    "0-1.5": "BTA1_0_potenza_1_5.csv",
    "1.5-3": "BTA2_1_5_potenza_3.csv",
    "3-4.5": "BTA3_3_potenza_4_5.csv",
    "4.5-6": "BTA3_4_5_potenza_6.csv",
    "6-10": "BTA4_6_potenza_10.csv",
    ">10": "BTA5_potenza_10.csv",
    ">16.5": "BTA6_potenza_16_5.csv",
}

VALORE = "Prelievo medio mensile"

# I file sono cp1252 - con utf-8 le sezioni diventano 'ATTIVIT?' - ma portano
# un BOM UTF-8 in testa, che finisce nel nome della prima colonna.
ENCODING = "cp1252"

_cache: dict[tuple[str, str], pd.DataFrame] = {}


def _percorso(banda: str) -> Path:
    if banda not in FILE_BANDA:
        sys.exit(f"Banda '{banda}' ignota. Disponibili: "
                 f"{', '.join(BANDE)}")
    trovati = sorted(radice().glob(f"**/{FILE_BANDA[banda]}"))
    if not trovati:
        sys.exit(f"File ARERA non domestico non trovato per la banda "
                 f"'{banda}' (atteso {FILE_BANDA[banda]} sotto {radice()}).")
    return trovati[0]


def _impronta(percorso: Path) -> str:
    """SHA-256 del sorgente, per invalidare la cache se il file cambia."""
    h = hashlib.sha256()
    with open(percorso, "rb") as f:
        for blocco in iter(lambda: f.read(1 << 20), b""):
            h.update(blocco)
    return h.hexdigest()


def carica(provincia: str, banda: str, verboso: bool = True) -> pd.DataFrame:
    """Righe di una provincia e banda, dalla cache o dal sorgente.

    I sorgenti sono sette CSV per circa 660 MB complessivi: senza cache ogni
    interrogazione richiederebbe una scansione completa. La cache si invalida
    da sola confrontando lo SHA-256 del sorgente, come sul lato domestico.

    Returns:
        DataFrame con colonne mese, sezione, divisione, gruppo, classe, kwh.
    """
    chiave = (provincia, banda)
    if chiave in _cache:
        return _cache[chiave]

    sorgente = _percorso(banda)
    CACHE.mkdir(parents=True, exist_ok=True)
    nome = f"{provincia}_{banda.replace('.', '_').replace('>', 'oltre')}"
    destinazione = CACHE / f"{nome}.csv"
    manifesto = CACHE / f"{nome}.json"

    if destinazione.exists() and manifesto.exists():
        atteso = json.loads(manifesto.read_text(encoding="utf-8"))
        if atteso.get("sha256") == _impronta(sorgente):
            # keep_default_na=False: le celle ATECO vuote sono la categoria
            # "non attribuito", non dati mancanti. Senza questo tornerebbero
            # come NaN e la categoria diventerebbe irraggiungibile.
            d = pd.read_csv(destinazione, keep_default_na=False,
                            dtype={"sezione": str, "divisione": str,
                                   "gruppo": str, "classe": str})
            d["mese"] = pd.to_numeric(d["mese"])
            d["kwh"] = pd.to_numeric(d["kwh"])
            _cache[chiave] = d
            return d

    if verboso:
        print(f"  lettura di {sorgente.name} per {provincia} "
              "(prima volta, poi va in cache)...", flush=True)

    pezzi = []
    for blocco in pd.read_csv(sorgente, sep=";", encoding=ENCODING,
                              chunksize=300_000, dtype=str):
        blocco.columns = [c.replace("﻿", "").strip() for c in blocco.columns]
        pezzi.append(blocco[blocco["Provincia"] == provincia])

    d = pd.concat(pezzi, ignore_index=True)
    if d.empty:
        sys.exit(f"Nessuna riga per la provincia '{provincia}' in "
                 f"{sorgente.name}. Controllare il nome (es. 'Milano').")

    d = pd.DataFrame({
        "mese": pd.to_numeric(d["Mese"]),
        "sezione": d["Sezione ATECO"].fillna(""),
        "divisione": d["Divisione ATECO"].fillna(""),
        "gruppo": d["Gruppo ATECO"].fillna(""),
        "classe": d["Classe ATECO"].fillna(""),
        "kwh": pd.to_numeric(d[VALORE].str.replace(",", ".", regex=False)),
    })

    d.to_csv(destinazione, index=False)
    manifesto.write_text(json.dumps({
        "sorgente": str(sorgente), "sha256": _impronta(sorgente),
        "provincia": provincia, "banda": banda, "righe": len(d),
    }, indent=2), encoding="utf-8")

    _cache[chiave] = d
    return d


def _codice(classe) -> str:
    """Codice numerico da un'etichetta ARERA ('85.31  Istruzione...' -> '85.31').

    Tollera i non-stringa: una cella ATECO vuota puo' tornare dalla cache come
    NaN se qualcuno rilegge il CSV senza keep_default_na=False.
    """
    if not isinstance(classe, str):
        return ""
    return classe.strip().split()[0] if classe.strip() else ""


def _serie(provincia: str, banda: str, ateco: str) -> pd.DataFrame:
    d = carica(provincia, banda)
    if ateco is None or ateco == "":
        sel = d[d["classe"] == ""]
    else:
        sel = d[d["classe"].map(_codice) == str(ateco)]
    if sel.empty:
        disponibili = sorted({_codice(c) for c in d["classe"] if c})[:12]
        sys.exit(f"Classe ATECO '{ateco}' assente per {provincia}, banda "
                 f"{banda}. Prime disponibili: {', '.join(disponibili)}...\n"
                 "Usare --elenco per vederle tutte.")
    return sel.groupby("mese", as_index=False)["kwh"].sum()


def livello_annuo(provincia: str, banda: str, ateco: str) -> float:
    """kWh/anno per punto di prelievo, somma dei dodici prelievi medi mensili.

    Raises:
        SystemExit: se la classe non ha tutti e dodici i mesi. Le celle con
            pochi clienti vengono soppresse da ARERA, e sommare i mesi
            superstiti darebbe un livello annuo sottostimato senza che nulla
            lo segnali.
    """
    s = _serie(provincia, banda, ateco)
    if len(s) != 12:
        mancanti = sorted(set(range(1, 13)) - set(s["mese"]))
        sys.exit(f"La classe {ateco} ({provincia}, {banda}) ha solo "
                 f"{len(s)} mesi su 12: mancano {mancanti}. E' soppressione "
                 "statistica per numero di clienti troppo basso, non un dato "
                 "parziale: sommare i mesi presenti darebbe un livello "
                 "sbagliato. Scegliere un'altra classe o un'altra banda.")
    return float(s["kwh"].sum())


def forma_mensile(provincia: str, banda: str, ateco: str) -> pd.Series:
    """Quote mensili a somma unitaria: la stagionalita' del livello.

    E' il bersaglio che smaschera i difetti di calendario: chiusura di agosto,
    calendario scolastico, picco estivo da climatizzazione. Un modello senza
    calendario produce dodici quote uguali a 1/12.
    """
    s = _serie(provincia, banda, ateco)
    if len(s) != 12:
        sys.exit(f"Forma mensile non calcolabile per {ateco}: "
                 f"{len(s)} mesi su 12 (soppressione statistica).")
    serie = s.set_index("mese")["kwh"]
    return serie / serie.sum()


def classe_non_attribuita(provincia: str, banda: str) -> pd.Series:
    """La riga con ATECO vuoto: categoria 'non attribuito', NON il totale."""
    return forma_mensile(provincia, banda, "")


def classi_disponibili(provincia: str, banda: str,
                       completi: bool = True) -> pd.DataFrame:
    """Classi ATECO presenti, con livello annuo e numero di mesi.

    Args:
        completi: se True elenca solo le classi con tutti e dodici i mesi,
            cioe' quelle utilizzabili come bersaglio.
    """
    d = carica(provincia, banda)
    d = d[d["classe"] != ""].copy()
    d["codice"] = d["classe"].map(_codice)
    g = d.groupby(["codice", "classe"], as_index=False).agg(
        mesi=("mese", "nunique"), kwh_anno=("kwh", "sum"))
    if completi:
        g = g[g["mesi"] == 12]
    return g.sort_values("kwh_anno", ascending=False).reset_index(drop=True)


def _l1(a: pd.Series, b: pd.Series) -> float:
    """Distanza L1 fra due distribuzioni mensili."""
    comuni = a.index.intersection(b.index)
    return float((a[comuni] - b[comuni]).abs().sum())


def rumore_banda(provincia: str, ateco: str, bande: tuple[str, str],
                 ) -> float:
    """Quanto cambia la forma mensile della stessa classe fra due bande.

    Misura l'arbitrarieta' dell'assunzione sulla banda di potenza, che e'
    dichiarata e non derivata. E' l'analogo della 'classe adiacente' usata sul
    lato domestico.
    """
    return _l1(forma_mensile(provincia, bande[0], ateco),
               forma_mensile(provincia, bande[1], ateco))


def rumore_classe(provincia: str, banda: str, classi: tuple[str, ...]) -> dict:
    """Dispersione della forma mensile fra classi vicine della stessa divisione.

    Misura quanto pesa la scelta della classe rappresentativa: se due classi
    sorelle distano quanto il modello dista dal bersaglio, la scelta della
    classe conta quanto il modello.
    """
    curve = {}
    for c in classi:
        try:
            curve[c] = forma_mensile(provincia, banda, c)
        except SystemExit:
            continue
    if len(curve) < 2:
        sys.exit(f"Servono almeno due classi con dodici mesi: trovate "
                 f"{len(curve)} fra {classi}.")
    coppie = {}
    nomi = list(curve)
    for i, a in enumerate(nomi):
        for b in nomi[i + 1:]:
            coppie[(a, b)] = _l1(curve[a], curve[b])
    return {"coppie": coppie,
            "medio": sum(coppie.values()) / len(coppie),
            "massimo": max(coppie.values())}


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--provincia", default="Milano")
    parser.add_argument("--banda", default=">16.5")
    parser.add_argument("--ateco", default=None)
    parser.add_argument("--elenco", action="store_true",
                        help="elenca le classi ATECO utilizzabili")
    parser.add_argument("--top", type=int, default=20)
    args = parser.parse_args()

    if args.elenco or args.ateco is None:
        g = classi_disponibili(args.provincia, args.banda)
        print(f"\nClassi ATECO con dodici mesi - {args.provincia}, "
              f"banda {args.banda} ({BANDE[args.banda]})\n")
        print(f"{'codice':8} {'kWh/anno':>10}  descrizione")
        for _, r in g.head(args.top).iterrows():
            desc = r["classe"].split(maxsplit=1)[1] if " " in r["classe"] else ""
            print(f"{r['codice']:8} {r['kwh_anno']:>10,.0f}  {desc[:60]}")
        print(f"\n({len(g)} classi complete in totale)")
        na = classe_non_attribuita(args.provincia, args.banda)
        print("\nRiga con ATECO vuoto (categoria 'non attribuito', NON il "
              "totale):")
        print("  quote mensili " + " ".join(f"{v * 100:.1f}" for v in na))
        return

    livello = livello_annuo(args.provincia, args.banda, args.ateco)
    forma = forma_mensile(args.provincia, args.banda, args.ateco)
    print(f"\n{args.ateco} - {args.provincia}, banda {args.banda}\n")
    print(f"  livello: {livello:,.0f} kWh/anno per punto di prelievo")
    print("  mese   " + " ".join(f"{m:5d}" for m in range(1, 13)))
    print("  quota% " + " ".join(f"{forma[m] * 100:5.1f}" for m in range(1, 13)))
    print(f"  (uniforme sarebbe 8,3 ogni mese; scarto L1 dall'uniforme "
          f"{_l1(forma, pd.Series(1 / 12, index=range(1, 13))):.4f})")


if __name__ == "__main__":
    main()
