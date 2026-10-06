"""
Arricchimento socio-economico delle schede CER: reddito e spesa gas per membro.

Compila nelle schede CER_configuration/CER_*.txt, per ogni membro domestico,
due colonne che finora valevano '?':

  reddito_EUR  reddito netto familiare annuo. Base: la MEDIA Istat EU-SILC
               (Nord-ovest, redditi 2024, esclusi gli affitti figurativi) della
               tipologia familiare dell'archetipo, moltiplicata per un fattore
               f estratto da una gaussiana N(1, sigma) TRONCATA a [1-R, 1+R].
               Il troncamento si fa per riestrazione, non per clipping: il
               clipping ammasserebbe utenti esattamente a +-R.
  euro_gas     spesa gas annua [EUR]. Sostituisce gas_kWh. Ogni household
               riceve le quote ARERA dei punti di prelievo domestici per classe
               di consumo (<=250, 250-500, >500 Smc/anno), perturbate con un
               fattore U(1-J, 1+J) indipendente per quota e rinormalizzate; da
               queste quote si estrae la sua categoria d'uso (cottura,
               cottura + acqua calda, riscaldamento). La spesa e' il consumo
               rappresentativo della categoria [Smc] x kWh/Smc x il prezzo gas
               di scenario_economico.txt.

e accanto, in colonne di provenienza, il valore base, il fattore di
perturbazione e la fonte (reddito_classe, reddito_base_EUR, reddito_f,
reddito_src, gas_categoria, gas_Smc, gas_quote_base, gas_f, gas_quote,
gas_src). Le righe non domestiche ricevono '-' (non applicabile).

FONTI (testo completo in DATA_SOURCES.md):
  [ISTAT-EUSILC]       Istat, "Condizioni di vita e reddito delle famiglie -
                       Anni 2024-2025", Prospetto 3, comunicato del 2/4/2026.
  [ARERA-CONSUMI-GAS]  ARERA, "Analisi dei consumi dei clienti domestici" (gas),
                       dataset dati_consumi_gas_2023-2024_zona_climatica.xlsx.
  [ARERA-PROFILI]      ARERA, Delibera 366/2018/R/com: profili 120 e 480 Smc/anno
                       (cottura e/o acqua calda), riscaldamento da 700 Smc/anno.

I dati stanno in data/external/ (CSV con la fonte riga per riga), i parametri in
data/external/parametri_arricchimento.yaml, la mappatura archetipo -> classe
Istat in data/mapping_archetipo_istat.csv (motivata in
docs/mapping_household_istat.md). Qui non c'e' nessun numero delle fonti.

RIPRODUCIBILITA'. Ogni estrazione usa un generatore suo, con seed derivato da
(seed_base, nome_csv, campo). Lo stesso household_k riceve quindi gli stessi
fattori e la stessa categoria gas in tutte le schede, e rilanciare lo script
riscrive le schede identiche al byte.

Uso (dalla root del progetto):
    python CER_LoadProfiles/arricchisci_schede.py              # tutte le schede
    python CER_LoadProfiles/arricchisci_schede.py --dry-run    # solo riepilogo
    python CER_LoadProfiles/arricchisci_schede.py --schede CER_configuration/CER_0_10_0.txt
"""

from __future__ import annotations

import argparse
import csv
import glob
import hashlib
import re
import sys
from pathlib import Path

import numpy as np
import yaml

ROOT = Path(__file__).resolve().parent.parent
PARAMETRI = ROOT / "data" / "external" / "parametri_arricchimento.yaml"
MAPPING = ROOT / "data" / "mapping_archetipo_istat.csv"

NON_MAPPATO = "NON_MAPPATO"

# Colonne di provenienza, in quest'ordine in coda a [MEMBRI].
COLONNE_PROVENIENZA = [
    "reddito_classe", "reddito_base_EUR", "reddito_f", "reddito_src",
    "gas_categoria", "gas_Smc", "gas_quote_base", "gas_f", "gas_quote", "gas_src",
]
COLONNE_A_DESTRA = {
    "id", "P_prel_kW", "n_comp", "n_perc", "reddito_EUR", "euro_gas", "gas_kWh",
    "quota_inv_EUR", "mutuo_EUR_anno", "reddito_base_EUR", "reddito_f", "gas_Smc",
}

INIZIO_BLOCCO = "# >>> arricchimento socio-economico"
FINE_BLOCCO = "# <<< arricchimento socio-economico"


# --- Caricamento dei dati ---------------------------------------------------

def carica_parametri(percorso: Path = PARAMETRI) -> dict:
    with open(percorso, encoding="utf-8") as f:
        return yaml.safe_load(f)


def carica_redditi(percorso: Path) -> dict[str, dict]:
    """classe_istat -> {'media': int, 'mediana': int, 'source_id': str}."""
    with open(percorso, encoding="utf-8", newline="") as f:
        return {
            r["classe_istat"]: {
                "media": int(r["media_EUR"]),
                "mediana": int(r["mediana_EUR"]),
                "source_id": r["source_id"],
            }
            for r in csv.DictReader(f)
        }


def carica_quote_gas(percorso: Path, area: str, soglie: list[float]) -> dict:
    """Quote ARERA dell'area, nell'ordine delle classi di consumo crescenti.

    Il file e' gia' aggregato a tre gruppi: se le soglie configurate non sono
    i confini di quei gruppi, i dati non bastano a ricalcolare le quote e ci
    si ferma invece di applicare in silenzio le soglie sbagliate.
    """
    with open(percorso, encoding="utf-8", newline="") as f:
        righe = [r for r in csv.DictReader(f) if r["area"] == area]
    if not righe:
        raise ValueError(f"area gas '{area}' assente da {percorso.name}")
    righe.sort(key=lambda r: float(r["smc_min"]))
    confini = [float(r["smc_min"]) for r in righe[1:]]
    if confini != [float(s) for s in soglie]:
        raise ValueError(
            f"soglie_smc {soglie} diverse dai confini dei gruppi nel file dati "
            f"{confini}: per spostarle servono le quote ARERA per singola classe di consumo"
        )
    return {
        "usi": [r["uso_assunto"] for r in righe],
        "quote": np.array([float(r["quota_pct"]) for r in righe]) / 100.0,
        "source_id": righe[0]["source_id"],
    }


def carica_mapping(percorso: Path = MAPPING) -> dict[str, str]:
    """codice LPG (CHR44) -> classe Istat."""
    with open(percorso, encoding="utf-8", newline="") as f:
        return {r["codice_lpg"]: r["classe_istat"] for r in csv.DictReader(f)}


def leggi_prezzo_gas(percorso: Path, chiave: str) -> float:
    """Legge 'chiave = valore' da scenario_economico.txt (commenti ammessi)."""
    with open(percorso, encoding="utf-8") as f:
        for riga in f:
            testo = riga.split("#", 1)[0].strip()
            m = re.fullmatch(rf"{re.escape(chiave)}\s*=\s*(\S+)", testo)
            if m:
                return float(m.group(1))
    raise ValueError(f"'{chiave}' non trovato in {percorso}")


# --- Estrazioni ---------------------------------------------------------------

def rng_per(seed_base: int, nome_csv: str, campo: str) -> np.random.Generator:
    """Generatore deterministico per (household, campo), indipendente dagli altri."""
    chiave = f"{seed_base}|{nome_csv}|{campo}".encode()
    seme = int.from_bytes(hashlib.sha256(chiave).digest()[:8], "little")
    return np.random.default_rng(seme)


def fattore_gaussiano_troncato(rng: np.random.Generator, R: float, sigma_fraction: float) -> float:
    """f ~ N(1, sigma_fraction*R) condizionata a [1-R, 1+R], per riestrazione."""
    sigma = sigma_fraction * R
    while True:
        f = rng.normal(1.0, sigma)
        if 1.0 - R <= f <= 1.0 + R:
            return float(f)


def perturba_quote(rng: np.random.Generator, quote: np.ndarray, J: float):
    """Fattore U(1-J, 1+J) indipendente per quota, poi somma riportata a 1."""
    fattori = rng.uniform(1.0 - J, 1.0 + J, size=len(quote))
    perturbate = quote * fattori
    return fattori, perturbate / perturbate.sum()


def assegna_reddito(nome_csv: str, archetipo: str, redditi: dict, mapping: dict,
                    par: dict, seed_base: int) -> dict:
    codice = archetipo.split("_", 1)[0]
    classe = mapping.get(codice)
    if classe is None or classe not in redditi:
        return {"classe": NON_MAPPATO, "base": None, "f": None, "reddito": None}
    f = fattore_gaussiano_troncato(
        rng_per(seed_base, nome_csv, "reddito"),
        par["INCOME_JITTER_PCT"], par["SIGMA_FRACTION"],
    )
    base = redditi[classe]["media"]
    return {"classe": classe, "base": base, "f": f, "reddito": int(round(base * f))}


def assegna_gas(nome_csv: str, gas: dict, par: dict, seed_base: int, prezzo: float) -> dict:
    fattori, quote = perturba_quote(
        rng_per(seed_base, nome_csv, "gas_quote"), gas["quote"], par["GAS_JITTER_PCT"]
    )
    # Categoria campionata dalle quote, non perturbata essa stessa.
    rng_cat = rng_per(seed_base, nome_csv, "gas_categoria")
    categoria = gas["usi"][int(rng_cat.choice(len(quote), p=quote))]
    smc = par["smc_rappresentativi"][categoria]
    return {
        "categoria": categoria,
        "smc": smc,
        "fattori": fattori,
        "quote": quote,
        "euro": int(round(smc * par["kWh_per_Smc"] * prezzo)),
    }


# --- Riscrittura della scheda -----------------------------------------------

def _celle(riga: str) -> list[str]:
    return [c.strip() for c in riga.split("#", 1)[0].split("|")]


def _tabella(intestazione: list[str], righe: list[list[str]]) -> list[str]:
    """Stesso formato di cer_config_writer._tabella: colonne allineate, niente '|' ai bordi."""
    larghezze = [max([len(intestazione[i])] + [len(r[i]) for r in righe])
                 for i in range(len(intestazione))]

    def allinea(cella: str, i: int) -> str:
        if intestazione[i] in COLONNE_A_DESTRA:
            return cella.rjust(larghezze[i])
        return cella.ljust(larghezze[i])

    return [" | ".join(allinea(c, i) for i, c in enumerate(r)).rstrip()
            for r in [intestazione] + righe]


def _numero(x: float, cifre: int) -> str:
    return f"{x:.{cifre}f}"


def _blocco_commento(par: dict, gas: dict, prezzo: float, area: str) -> list[str]:
    pr, pg = par["reddito"], par["gas"]
    R, J = pr["INCOME_JITTER_PCT"], pg["GAS_JITTER_PCT"]
    sigma = pr["SIGMA_FRACTION"] * R
    smc = pg["smc_rappresentativi"]
    return [
        f"{INIZIO_BLOCCO} (CER_LoadProfiles/arricchisci_schede.py)",
        "# Righe e colonne reddito_*, gas_*, euro_gas GENERATE: non modificarle a mano,",
        "# rilanciare lo script. Fonti: DATA_SOURCES.md; mapping archetipo -> classe:",
        "# docs/mapping_household_istat.md.",
        "# reddito_EUR = reddito_base_EUR x reddito_f. Base: media Istat EU-SILC della",
        "#   classe (Nord-ovest, redditi 2024, netto, senza affitti figurativi).",
        f"#   reddito_f ~ N(1, {sigma:.3f}) troncata a [{1 - R:.2f}, {1 + R:.2f}] per"
        " riestrazione. [ISTAT-EUSILC]",
        f"# euro_gas = spesa gas annua [EUR] = gas_Smc x {pg['kWh_per_Smc']:.2f} kWh/Smc x"
        f" {prezzo:.3f} EUR/kWh",
        f"#   ({pg['chiave_prezzo']} di scenario_economico.txt al momento della generazione).",
        f"#   gas_categoria estratta dalle quote ARERA {area} 2023-24 per gruppo di consumo",
        f"#   (<=250 | 250-500 | >500 Smc), ciascuna x gas_f ~ U({1 - J:.2f}, {1 + J:.2f}) e",
        "#   rinormalizzate (gas_quote). [ARERA-CONSUMI-GAS]",
        f"#   ASSUNZIONE: soglie 250/500 Smc e consumo per uso ({smc['cottura']} /"
        f" {smc['cottura_acqua_calda']} / {smc['riscaldamento']} Smc). [ARERA-PROFILI]",
        f"# Seed: sha256(seed_base={par['seed_base']}, nome_csv, campo).",
        FINE_BLOCCO,
    ]


def arricchisci_testo(testo: str, ctx: dict) -> tuple[str, list[dict]]:
    """Restituisce il testo della scheda arricchito e un riepilogo per membro."""
    righe = testo.split("\n")
    try:
        i0 = next(i for i, r in enumerate(righe) if r.strip() == "[MEMBRI]")
    except StopIteration:
        raise ValueError("sezione [MEMBRI] assente")
    i1 = next((i for i in range(i0 + 1, len(righe)) if righe[i].strip().startswith("[")),
              len(righe))

    commenti, tabella, coda = [], [], []
    dentro_blocco = False
    for r in righe[i0 + 1:i1]:
        s = r.strip()
        if s.startswith(INIZIO_BLOCCO):
            dentro_blocco = True
        if dentro_blocco:
            dentro_blocco = not s.startswith(FINE_BLOCCO)
            continue
        if "|" in s.split("#", 1)[0]:
            tabella.append(_celle(r))
        elif tabella:
            coda.append(r)
        else:
            commenti.append(r)
    if not tabella:
        raise ValueError("[MEMBRI] senza tabella")

    intest, dati = tabella[0], [dict(zip(tabella[0], c)) for c in tabella[1:]]
    if any(len(c) != len(intest) for c in tabella[1:]):
        raise ValueError("[MEMBRI]: righe con un numero di colonne diverso dall'intestazione")
    if "gas_kWh" in intest:
        # Un consumo vero in kWh non e' una spesa: rinominarlo lo falserebbe.
        veri = [d["nome_csv"] for d in dati if d["gas_kWh"] not in ("?", "-", "")]
        if veri:
            raise ValueError(f"gas_kWh compilato per {veri}: convertirlo a mano in euro_gas")
        intest = ["euro_gas" if c == "gas_kWh" else c for c in intest]
        for d in dati:
            d["euro_gas"] = d.pop("gas_kWh")
    intest = [c for c in intest if c not in COLONNE_PROVENIENZA] + COLONNE_PROVENIENZA

    par, gas, prezzo = ctx["par"], ctx["gas"], ctx["prezzo"]
    seed_base = par["seed_base"]
    src_gas = f"{gas['source_id']}:{par['gas']['area']}"
    quote_base = ";".join(_numero(q, 3) for q in gas["quote"])
    riepilogo = []
    for d in dati:
        if d.get("categoria") != "domestico":
            for c in COLONNE_PROVENIENZA:
                d[c] = "-"
            continue
        # Si sovrascrive solo cio' che manca ('?') o cio' che lo script stesso
        # aveva scritto: un dato vero inserito a mano non si tocca.
        nostro_r = d.get("reddito_src", "") == ctx["src_reddito"]
        if d.get("reddito_EUR", "?") in ("?", "") or nostro_r:
            r = assegna_reddito(d["nome_csv"], d["archetipo"], ctx["redditi"],
                                ctx["mapping"], par["reddito"], seed_base)
            if r["classe"] == NON_MAPPATO:
                d.update(reddito_EUR="?", reddito_classe=NON_MAPPATO, reddito_base_EUR="?",
                         reddito_f="?", reddito_src="-")
            else:
                d.update(reddito_EUR=str(r["reddito"]), reddito_classe=r["classe"],
                         reddito_base_EUR=str(r["base"]), reddito_f=_numero(r["f"], 6),
                         reddito_src=ctx["src_reddito"])
        else:
            d.update(reddito_classe="-", reddito_base_EUR="-", reddito_f="-",
                     reddito_src="scheda")

        nostro_g = d.get("gas_src", "") == src_gas
        if d.get("euro_gas", "?") in ("?", "") or nostro_g:
            g = assegna_gas(d["nome_csv"], gas, par["gas"], seed_base, prezzo)
            d.update(euro_gas=str(g["euro"]), gas_categoria=g["categoria"],
                     gas_Smc=str(g["smc"]), gas_quote_base=quote_base,
                     gas_f=";".join(_numero(x, 4) for x in g["fattori"]),
                     gas_quote=";".join(_numero(x, 4) for x in g["quote"]),
                     gas_src=src_gas)
        else:
            d.update(gas_categoria="-", gas_Smc="-", gas_quote_base="-", gas_f="-",
                     gas_quote="-", gas_src="scheda")
        riepilogo.append({k: d[k] for k in ("nome_csv", "archetipo", "reddito_classe",
                                            "reddito_EUR", "gas_categoria", "euro_gas")})

    nuove = (righe[:i0 + 1]
             + _blocco_commento(par, gas, prezzo, par["gas"]["area"])
             + commenti
             + _tabella(intest, [[d[c] for c in intest] for d in dati])
             + coda + righe[i1:])
    return "\n".join(nuove), riepilogo


def contesto(par: dict | None = None) -> dict:
    """Carica una volta sola dati, mapping e prezzo per tutte le schede."""
    par = par or carica_parametri()
    base = PARAMETRI.parent
    redditi = carica_redditi(base / par["reddito"]["file"])
    gas = carica_quote_gas(base / par["gas"]["file"], par["gas"]["area"],
                           par["gas"]["soglie_smc"])
    prezzo = leggi_prezzo_gas(ROOT / par["gas"]["scenario_economico"],
                              par["gas"]["chiave_prezzo"])
    return {"par": par, "redditi": redditi, "gas": gas, "prezzo": prezzo,
            "mapping": carica_mapping(), "src_reddito": par["reddito"]["source_id"]}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0].strip())
    ap.add_argument("--schede", nargs="*",
                    default=sorted(glob.glob(str(ROOT / "CER_configuration" / "CER_*.txt"))))
    ap.add_argument("--area", choices=["lombardia", "milano"],
                    help="area delle quote gas (default: quella del YAML)")
    ap.add_argument("--dry-run", action="store_true", help="non scrive, riassume soltanto")
    args = ap.parse_args(argv)

    par = carica_parametri()
    if args.area:
        par["gas"]["area"] = args.area
    ctx = contesto(par)

    non_mappati, cambiate = set(), 0
    for p in map(Path, args.schede):
        with open(p, encoding="utf-8", newline="") as f:
            vecchio = f.read()
        nuovo, riep = arricchisci_testo(vecchio, ctx)
        non_mappati |= {r["archetipo"] for r in riep if r["reddito_classe"] == NON_MAPPATO}
        if nuovo != vecchio:
            cambiate += 1
            if not args.dry_run:
                with open(p, "w", encoding="utf-8", newline="") as f:
                    f.write(nuovo)
        print(f"{p.name:<20} {len(riep):>3} domestici "
              f"{'(cambiata)' if nuovo != vecchio else '(invariata)'}")
    print(f"schede {'da cambiare' if args.dry_run else 'cambiate'}: {cambiate}/{len(args.schede)}")
    print("archetipi NON MAPPATI:", ", ".join(sorted(non_mappati)) or "nessuno")
    return 0


if __name__ == "__main__":
    sys.exit(main())
