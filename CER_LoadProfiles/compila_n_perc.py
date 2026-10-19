"""Compila la colonna n_perc (percettori di reddito) dei membri domestici nelle schede CER.

n_perc e' il divisore con cui l'indice LIHC (lihc_index.m, eq. 12 di Campagna et
al. 2024) converte il reddito familiare in reddito per percettore: scala
direttamente chi risulta vulnerabile. Prima valeva '?' ovunque e il Tri-level EP
assumeva 2 percettori per tutti (ipotesi 10), anche per le persone sole.

Il valore viene dall'ARCHETIPO dichiarato del membro (stessa fonte del reddito,
vedi arricchisci_schede.py): data/mapping_archetipo_nperc.csv, che per ogni
codice LPG dice quante persone portano un reddito da lavoro o una pensione. Le
regole di conteggio stanno nella colonna `criterio` del CSV; in breve: occupati
e pensionati contano uno ciascuno, un nucleo senza occupati conta 1 (il reddito
per percettore non e' definito con 0), la collaboratrice domestica non conta.

Tocca SOLO le celle che valgono '?' dei membri di categoria `domestico`: un dato
inserito a mano non si sovrascrive, e rilanciare e' innocuo. Le righe non
domestiche hanno '-' e restano cosi'.

Uso (dalla root del progetto):
    python -I CER_LoadProfiles/compila_n_perc.py             # CER_configuration/ e CER_configuration_PA/PA*/
    python -I CER_LoadProfiles/compila_n_perc.py --dry-run   # solo riepilogo
"""
from __future__ import annotations

import argparse
import csv
import glob
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAPPING = ROOT / "data" / "mapping_archetipo_nperc.csv"


def carica_mapping(percorso: Path = MAPPING) -> dict[str, int]:
    with open(percorso, newline="", encoding="utf-8") as f:
        return {r["codice_lpg"]: int(r["n_perc"]) for r in csv.DictReader(f)}


def compila_testo(testo: str, mapping: dict[str, int]) -> tuple[str, Counter]:
    """Sostituisce '?' in n_perc dei membri domestici. Conserva i fine riga."""
    righe = testo.split("\n")
    conta: Counter = Counter()
    idx = None
    for k, riga in enumerate(righe):
        corpo = riga.rstrip("\r").split("#", 1)[0]
        if "|" not in corpo:
            continue
        celle = corpo.split("|")
        nomi = [c.strip() for c in celle]
        if "n_perc" in nomi and "archetipo" in nomi:
            idx = {n: i for i, n in enumerate(nomi)}
            continue
        if idx is None or len(celle) <= max(idx["n_perc"], idx["archetipo"], idx["categoria"]):
            continue
        if nomi[idx["categoria"]] != "domestico" or nomi[idx["n_perc"]] != "?":
            continue
        codice = nomi[idx["archetipo"]].split("_", 1)[0]
        if codice not in mapping:
            raise SystemExit(f"archetipo senza n_perc in {MAPPING.name}: {nomi[idx['archetipo']]}")
        n = mapping[codice]
        assert 0 < n < 10          # una cifra: la larghezza della cella non cambia
        celle[idx["n_perc"]] = celle[idx["n_perc"]].replace("?", str(n))
        resto = riga[len(corpo):]  # commento e \r finali
        righe[k] = "|".join(celle) + resto
        conta[n] += 1
    return "\n".join(righe), conta


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0].strip())
    ap.add_argument("--dry-run", action="store_true", help="non scrive, stampa il riepilogo")
    ap.add_argument("--schede", nargs="*", help="percorsi delle schede (default: tutte)")
    a = ap.parse_args(argv)
    mapping = carica_mapping()
    schede = a.schede or sorted(
        glob.glob(str(ROOT / "CER_configuration" / "CER_*.txt"))
        + glob.glob(str(ROOT / "CER_configuration_PA" / "PA*" / "CER_*.txt")))
    tot: Counter = Counter()
    for s in schede:
        p = Path(s)
        with open(p, newline="", encoding="utf-8") as f:
            testo = f.read()
        nuovo, conta = compila_testo(testo, mapping)
        tot.update(conta)
        if conta and not a.dry_run:
            with open(p, "w", newline="", encoding="utf-8") as f:
                f.write(nuovo)
    print(f"{len(schede)} schede; celle compilate per valore di n_perc: " + ", ".join(f"{k}: {v}" for k, v in sorted(tot.items())))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
