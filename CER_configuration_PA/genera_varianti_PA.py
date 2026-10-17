"""Genera l'asse "composizione" (presenza di PA) a partire dalle schede della griglia.

Per ogni scheda CER_C_P_E.txt di CER_configuration/ produce:
  PA0/  copia della scheda (solo domestici), con i percorsi adattati
  PA1/  comune
  PA2/  comune + scuola
  PA3/  comune + scuola + palazzetto
e i CSV dei profili di carico di ogni variante in profili/PAk/.

Regola: N, C e P restano quelli della scheda. Ogni PA e' un prosumer con il suo
impianto; per ogni PA che entra esce un prosumer domestico (l'ultimo per id), con il
suo impianto. Se la scheda ha meno di k prosumer, la variante PAk non si fa.

Uso (dalla radice del progetto):
    python -I CER_configuration_PA/genera_varianti_PA.py
"""
import csv
import math
import re
import sys
from pathlib import Path

import openpyxl

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "CER_configuration"
OUT = ROOT / "CER_configuration_PA"
ND = ROOT / "CER_LoadProfiles/outputs/csv_nd20/profili_nd20.csv"
LUCCA = ROOT / "data/external/palazzetto_lucca/palazzetto_lucca_carico.csv"

# Costo impianto PA: (moduli + BOP) x (1 + ingegneria) + (inverter + allacciamento) per kWac,
# con kWac ~ kWp, dai parametri di scenario_economico.txt: (180+270)*1.40 + (50+50) = 730 EUR/kWp
EUR_KWP = 730

# kWp dichiarati dall'utente: palazzetto 310,5 (progetto), comune 47, scuola 35
PA = [
    dict(tipo="comune", nome="comune_1_kWh", col_nd="comune_1", archetipo="comune",
         kwp=47.0, stima=False, pv="PROVA_CER_1_Project_municipio.CSV", pid="PV_COM",
         tariffa="BIORARIA"),
    dict(tipo="scuola", nome="scuola_superiore_1_kWh", col_nd="scuola_superiore_1",
         archetipo="scuola_superiore", kwp=35.0, stima=False,
         pv="PROVA_CER_1_Project_scuola.CSV", pid="PV_SCU", tariffa="BIORARIA"),
    dict(tipo="palazzetto", nome="palazzetto_lucca_kWh", col_nd=None,
         archetipo="palazzetto_sport", kwp=310.5, stima=False,
         pv="palazzetto_lucca_FV.CSV", pid="PV_PAL", tariffa="BIORARIA", p_prel=448),
]


def read_xlsx(path):
    """xlsx o csv (';' e timestamp ISO) -> (intestazione, righe)"""
    if str(path).lower().endswith(".csv"):
        r = list(csv.reader(open(path, encoding="utf-8"), delimiter=";"))
        return r[0], [[x[0]] + [float(v) for v in x[1:]] for x in r[1:]]
    wb = openpyxl.load_workbook(path, read_only=True)
    rows = list(wb.active.iter_rows(values_only=True))
    return rows[0], rows[1:]


def read_csv_cols(path, cols, delim):
    r = list(csv.reader(open(path, encoding="utf-8"), delimiter=delim))
    h = r[0]
    idx = [h.index(c) for c in cols]
    return [x[0] for x in r[1:]], {c: [float(x[i]) for x in r[1:]] for c, i in zip(cols, idx)}


def pa_series():
    ts_nd, d = read_csv_cols(ND, ["comune_1", "scuola_superiore_1"], ",")
    ts_l, dl = read_csv_cols(LUCCA, ["palazzetto_lucca_kWh"], ";")
    assert len(ts_nd) == len(ts_l) == 8760
    iso = [t.replace(" ", "T") for t in ts_nd]
    assert iso == ts_l, "calendari diversi"
    return iso, {
        "comune_1_kWh": d["comune_1"],
        "scuola_superiore_1_kWh": d["scuola_superiore_1"],
        "palazzetto_lucca_kWh": dl["palazzetto_lucca_kWh"],
    }


def split_sections(text):
    lines = text.splitlines()
    i_m = lines.index("[MEMBRI]")
    i_i = lines.index("[IMPIANTI]")
    return lines, i_m, i_i


def parse_table(lines):
    """righe di tabella 'a | b | c' (esclude commenti e vuote) -> (header, righe)"""
    data = [l for l in lines if l.strip() and not l.lstrip().startswith("#")]
    head = [x.strip() for x in data[0].split("|")]
    rows = [dict(zip(head, [x.strip() for x in l.split("|")])) for l in data[1:]]
    return head, rows


def fmt_table(head, rows):
    cells = [[r.get(h, "-") for h in head] for r in rows]
    w = [max(len(h), *(len(c[i]) for c in cells)) for i, h in enumerate(head)]
    num = re.compile(r"^-?[\d.]+$")

    def f(vals):
        return " | ".join(v.rjust(w[i]) if num.match(v) else v.ljust(w[i])
                          for i, v in enumerate(vals)).rstrip()
    return [f(head)] + [f(c) for c in cells]


def set_kv(lines, key, value):
    for i, l in enumerate(lines):
        if re.match(rf"^{key}\s*=", l):
            lines[i] = f"{key.ljust(26)}= {value}" if key in (
                "membri_totali", "consumatori", "prosumer", "produttori_puri",
                "penetrazione_prosumer_pct", "potenza_installata_kWp",
                "impianti_totali") else f"{key} = {value}"
            return
    raise KeyError(key)


def build(src_path, level, ts, series):
    text = src_path.read_text(encoding="utf-8")
    lines, i_m, i_i = split_sections(text)
    # percorsi: la scheda sta due cartelle piu' in basso
    for i, l in enumerate(lines):
        m = re.match(r"^(prezzi_zonali|cartella_pv|scenario_economico|profili_carico)(\s*=\s*)(.*)$", l)
        if m:
            k, eq, v = m.groups()
            if k == "scenario_economico":
                v = "../../CER_configuration/" + v
            elif k != "profili_carico":
                v = "../../" + v.replace("../", "", 1)
            lines[i] = f"{k}{eq}{v}"
    head_m, rows_m = parse_table(lines[i_m + 1:i_i])
    head_p, rows_p = parse_table(lines[i_i + 1:])
    n = len(rows_m)
    n_cons = sum(r["ruolo"] == "C" for r in rows_m)
    pros = [r for r in rows_m if r["ruolo"] == "P"]
    rel = re.search(r"^profili_carico\s*=\s*(.*)$", text, re.M).group(1).strip()
    xlsx = (src_path.parent / rel).resolve()

    if level == 0:
        new_pro = rows_p
        keep_m = rows_m
        add = []
        pfile = "../" + rel
        keep_names = None
    else:
        k = level
        if len(pros) < k:
            raise IndexError("prosumer insufficienti")
        add = PA[:k]
        drop = sorted(pros, key=lambda r: int(r["id"]))[-k:]
        drop_ids = {r["id"] for r in drop}
        drop_plants = {r["impianto"] for r in drop}
        keep_m = [r for r in rows_m if r["id"] not in drop_ids]
        new_pro = [r for r in rows_p if r["id"] not in drop_plants]
        pfile = f"../profili/PA{k}/{src_path.stem}_PA{k}.csv"
        keep_names = [r["nome_csv"] for r in keep_m]

    # membri: domestici nell'ordine originale, poi le PA; id rinumerati
    mem = [dict(r) for r in keep_m]
    imp = [dict(r) for r in new_pro]
    for a in add:
        capex = int(round(a["kwp"] * EUR_KWP, -2))
        mem.append(dict(
            nome_csv=a["nome"], ruolo="P", categoria="PA", archetipo=a["archetipo"],
            tariffa=a["tariffa"], P_prel_kW=str(a.get("p_prel", None) or PEAK[a["nome"]]),
            n_comp="-", n_perc="-", reddito_EUR="-", euro_gas="-",
            quota_inv_EUR=str(capex), mutuo_EUR_anno="0", impianto=a["pid"]))
        imp.append({"id": a["pid"], "proprietario": a["nome"], "kWp": f"{a['kwp']:g}",
                    "file_produzione": a["pv"], "tilt": "?", "azimut": "?",
                    "anno_esercizio": "2025", "capex_EUR": str(capex), "opex_EUR_anno": "?"})
    for i, r in enumerate(mem, 1):
        r["id"] = str(i)

    kwp_tot = sum(float(r["kWp"]) for r in imp)
    n_pro = sum(r["ruolo"] == "P" for r in mem)
    assert len(mem) == n and n_pro == len(pros) and len(imp) == n_pro, (src_path.name, level)
    set_kv(lines, "potenza_installata_kWp", f"{kwp_tot:.1f}")
    for i, l in enumerate(lines):
        if l.startswith("profili_carico"):
            lines[i] = f"profili_carico     = {pfile}"

    # intestazione: quella originale + blocco della variante
    top = lines[:lines.index("[CER]")]
    mid = lines[lines.index("[CER]"):i_m]
    if level:
        names = ", ".join(a["tipo"] for a in add)
        rim = ", ".join(f"{r['nome_csv']} ({r['impianto']})" for r in drop)
        blk = [
            "# =============================================================================",
            f"# VARIANTE PA{level}: composizione con {level} PA ({names}) - asse 'composizione'",
            f"# Derivata da CER_configuration/{src_path.name}: stessi N={n}, C={n_cons}, P={len(pros)}",
            f"# (penetrazione prosumer invariata). Ogni PA e' un prosumer con il proprio impianto;",
            f"# per ogni PA che entra esce un prosumer domestico, con il suo impianto:",
            f"#   rimossi: {rim}",
            "# Le righe domestiche restano quelle della scheda di partenza (stessi reddito/gas).",
            "# ASSUNZIONI PA (da confermare):",
            "#  - palazzetto: carico = ricostruzione Lucca (palazzetto_lucca_carico.csv), FV = FV Lucca",
            "#    (palazzetto_lucca_FV.CSV, riscalato alla stima del progetto), 310,5 kWp dichiarati;",
            "#  - comune e scuola: carico RAMP (colonne comune_1 e scuola_superiore_1 di csv_nd20),",
            "#    FV da PROVA_CER_1_Project_municipio.CSV / _scuola.CSV;",
            "#  - kWp dichiarati dall'utente: comune 47, scuola 35, palazzetto 310,5;",
            f"#  - costo impianto {EUR_KWP} EUR/kWp = (180+270)x1,40 + (50+50), da scenario_economico.txt;",
            "#  - tariffa BIORARIA (come 'office'); P_prel_kW: picco del profilo arrotondato a 5 kW,",
            "#    palazzetto 448 kW (POD in MT, diagnosi energetica);",
            "#  - categoria PA: esente dal fattore F (enti territoriali).",
            "# I profili di carico sono in ../profili/ e si rigenerano con",
            "# CER_configuration_PA/genera_varianti_PA.py.",
            "# =============================================================================",
        ]
        top = blk + top
    else:
        top = ["# VARIANTE PA0: copia della scheda di CER_configuration/ (solo domestici), con i",
               "# percorsi relativi adattati alla cartella. Nessun altro cambiamento.",
               "#"] + top

    mem_comments = [l for l in lines[i_m + 1:i_i] if l.lstrip().startswith("#")]
    head_m_out = head_m
    out = top + mid + ["[MEMBRI]"] + mem_comments + fmt_table(head_m_out, mem) + \
        ["[IMPIANTI]"] + fmt_table(head_p, imp)
    return "\n".join(out) + "\n", (xlsx, keep_names, [a["nome"] for a in add], n)


def write_profile(xlsx, keep_names, add_names, ts, series, dest):
    header, rows = read_xlsx(xlsx)
    header = list(header)
    idx = [header.index(c) for c in keep_names]
    dest.parent.mkdir(parents=True, exist_ok=True)
    with open(dest, "w", encoding="ascii", newline="") as f:
        w = csv.writer(f, delimiter=";", lineterminator="\r\n")
        w.writerow(["timestamp"] + keep_names + add_names)
        for r, row in enumerate(rows):
            t = row[0] if isinstance(row[0], str) else row[0].strftime("%Y-%m-%dT%H:%M:%S")
            assert t == ts[r], (t, ts[r])
            w.writerow([t] + [f"{row[i]:g}" for i in idx] +
                       [f"{series[a][r]:.4f}".rstrip("0").rstrip(".") for a in add_names])


if __name__ == "__main__":
    ts, series = pa_series()
    PEAK = {k: int(math.ceil(max(v) / 5.0) * 5) for k, v in series.items()}
    print("P_prel (picco, arr. 5 kW):", PEAK)
    skipped = []
    for p in sorted(SRC.glob("CER_*.txt")):
        for level in range(4):
            try:
                text, (xlsx, keep_names, add_names, n) = build(p, level, ts, series)
            except AssertionError:
                raise
            except IndexError:      # meno di k prosumer
                skipped.append((p.name, level))
                continue
            d = OUT / f"PA{level}"
            d.mkdir(parents=True, exist_ok=True)
            (d / p.name).write_text(text, encoding="utf-8", newline="\n")
            if level:
                write_profile(xlsx, keep_names, add_names, ts, series,
                              OUT / f"profili/PA{level}/{p.stem}_PA{level}.csv")
    print("saltate (prosumer insufficienti):", skipped)
