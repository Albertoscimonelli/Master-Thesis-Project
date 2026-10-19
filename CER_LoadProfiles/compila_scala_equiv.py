"""Aggiunge e compila la colonna scala_equiv (scala di equivalenza) nelle schede CER.

scala_equiv e' il peso del nucleo nella scala OCSE modificata usata da Istat e
Eurostat per la soglia di rischio di poverta': 1,0 il primo adulto, 0,5 ogni altra
persona di 14 anni o piu', 0,3 ogni minore di 14. La soglia di poverta' del nucleo
e' y* x scala_equiv, dove y* (scenario_economico.txt,
soglia_poverta_EUR_equivalente) e' la soglia per ADULTO EQUIVALENTE: l'Istat non
pubblica una soglia per percettore, ed e' questa la grandezza che pubblica.

I pesi stanno in data/mapping_archetipo_nperc.csv, calcolati dalle eta' dei
componenti dell'archetipo (data/mapping_archetipo_istat.csv). Un'eccezione
dichiarata: in CHR19 la collaboratrice domestica (50 anni) e' contata da LPG fra i
componenti ma non e' della famiglia, quindi non entra nella scala (1,5 e non 2,0).

La colonna si inserisce subito dopo n_perc. Righe non domestiche: '-'. Se la
colonna c'e' gia' lo script non fa nulla: e' idempotente. Dopo aver rigenerato le
varianti PA con genera_varianti_PA.py va rilanciato.

Uso (dalla root del progetto):
    python -I CER_LoadProfiles/compila_scala_equiv.py             # CER_configuration/ e CER_configuration_PA/PA*/
    python -I CER_LoadProfiles/compila_scala_equiv.py --dry-run
"""
from __future__ import annotations

import argparse
import csv
import glob
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAPPING = ROOT / "data" / "mapping_archetipo_nperc.csv"
NOME = "scala_equiv"


def carica_pesi() -> dict[str, float]:
    with open(MAPPING, newline="", encoding="utf-8") as f:
        return {r["codice_lpg"]: float(r["scala_equiv"]) for r in csv.DictReader(f)}


def inserisci_testo(testo: str, pesi: dict[str, float]) -> tuple[str, int]:
    righe = testo.split("\n")
    idx = None
    n = 0
    for k, riga in enumerate(righe):
        corpo = riga.rstrip("\r").split("#", 1)[0]
        if "|" not in corpo:
            continue
        celle = corpo.split("|")
        nomi = [c.strip() for c in celle]
        resto = riga[len(corpo):]
        if "n_perc" in nomi and "archetipo" in nomi:
            if NOME in nomi:
                return testo, 0                      # gia' presente
            idx = {c: i for i, c in enumerate(nomi)}
            celle.insert(idx["n_perc"] + 1, f" {NOME} ")
            righe[k] = "|".join(celle) + resto
            continue
        if idx is None or len(celle) <= max(idx.values()):
            continue
        if nomi[idx["categoria"]] == "domestico":
            codice = nomi[idx["archetipo"]].split("_", 1)[0]
            if codice not in pesi:
                raise SystemExit(f"archetipo senza scala_equiv: {nomi[idx['archetipo']]}")
            cella = f" {pesi[codice]:>{len(NOME)}.1f} "
        else:
            cella = f" {'-':>{len(NOME)}} "
        celle.insert(idx["n_perc"] + 1, cella)
        righe[k] = "|".join(celle) + resto
        n += 1
    return "\n".join(righe), n


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0].strip())
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--schede", nargs="*")
    a = ap.parse_args(argv)
    pesi = carica_pesi()
    schede = a.schede or sorted(
        glob.glob(str(ROOT / "CER_configuration" / "CER_*.txt"))
        + glob.glob(str(ROOT / "CER_configuration_PA" / "PA*" / "CER_*.txt")))
    fatte = righe_tot = 0
    for s in schede:
        p = Path(s)
        with open(p, newline="", encoding="utf-8") as f:
            testo = f.read()
        nuovo, n = inserisci_testo(testo, pesi)
        if n:
            fatte += 1
            righe_tot += n
            if not a.dry_run:
                with open(p, "w", newline="", encoding="utf-8") as f:
                    f.write(nuovo)
    print(f"{len(schede)} schede, {fatte} modificate, {righe_tot} righe di membri")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
