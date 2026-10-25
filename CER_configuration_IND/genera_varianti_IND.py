"""Genera l'asse "non domestici" (imprese, ND) a partire dalle schede della griglia.

Per ogni scheda CER_C_P_E.txt di CER_configuration/ con N >= 15 produce, in
CER_configuration_IND/<livello>/:
  ND{k}        k imprese (k = 1, 3, 5)             -> D + ND
  ND{k}_PA{p}  k imprese + p PA (p = 1, 2, 3)      -> D + ND + PA
e i CSV dei profili di carico di ogni variante in profili/<livello>/.

Regola (la stessa dell'asse PA): N, C e P restano quelli della scheda. Ogni ND e
ogni PA e' un prosumer con il suo impianto; per ogni ND/PA che entra esce un
prosumer domestico (l'ultimo per id), con il suo impianto. Vincoli:
  - la quota dei non domestici (ND + PA) resta SOTTO il 50% di N:
    ND + PA <= ceil(N/2) - 1;
  - i prosumer domestici di partenza devono bastare: ND + PA <= P.
Le imprese entrano in quest'ordine: antigelo, office_zummo, small_industry,
plastica, office. Le PA (comune, scuola, palazzetto) sono quelle di
genera_varianti_PA.py, di cui si riusano funzioni e parametri.

Uso (dalla radice del progetto):
    python -I CER_configuration_IND/genera_varianti_IND.py
"""
import csv
import datetime as dt
import importlib.util
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "CER_configuration"
OUT = ROOT / "CER_configuration_IND"
VAL = ROOT / "CER_LoadProfiles/outputs/Valencia"
SCHEDA9 = ROOT / "CER_LoadProfiles/outputs/csv_scheda9/profili_tutti.csv"

_spec = importlib.util.spec_from_file_location(
    "genera_varianti_PA", ROOT / "CER_configuration_PA/genera_varianti_PA.py")
gpa = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gpa)       # il blocco __main__ del modulo PA non parte

EUR_KWP = gpa.EUR_KWP               # 730 EUR/kWp, come per le PA
ND_LEVELS = (1, 3, 5)               # imprese per livello
PA_LEVELS = (1, 2, 3)               # PA per livello
N_MIN = 15                          # i ND si inseriscono da 15 membri

# ----------------------------------------------------------------------------
# Le cinque imprese. kWp: STIMATI da produzione/1480 kWh/kWp (i file PVsyst non
# riportano la potenza): da confermare. P_prel_kW: per le tre con dati veri e'
# il picco del profilo arrotondato a 5 kW (potenza contrattuale non nota); per
# i due casi RAMP e' quella dichiarata in CER_input.txt.
# ----------------------------------------------------------------------------
ND = [
    dict(tipo="antigelo", nome="antigelo_kWh", categoria="industriale", archetipo="antigelo",
         tariffa="ORARIO_VARIABILE", p_prel=None, kwp=33.0, pid="PV_ANT",
         pv="PROVA_CER_1_Project_antigelo.CSV", src=("val", "Consumo_orario_antigelo_2024.csv")),
    dict(tipo="office_zummo", nome="office_zummo_kWh", categoria="terziario", archetipo="office_zummo",
         tariffa="BIORARIA", p_prel=None, kwp=129.0, pid="PV_ZUM",
         pv="PROVA_CER_1_Project_office_zummo.CSV", src=("val", "Consumo_orario_office_zummo_2024.csv")),
    dict(tipo="small_industry", nome="small_industry_1_kWh", categoria="industriale",
         archetipo="small_industry", tariffa="ORARIO_VARIABILE", p_prel=50, kwp=69.0, pid="PV_SMI",
         pv="PROVA_CER_1_Project_small_industry.CSV", src=("ramp", "small_industry_1_kWh")),
    dict(tipo="plastica", nome="plastica_kWh", categoria="industriale", archetipo="plastica",
         tariffa="ORARIO_VARIABILE", p_prel=None, kwp=250.0, pid="PV_PLA",
         pv="PROVA_CER_1_Project_plastic_industry.CSV", src=("val", "Consumo_orario_plastica_2024.csv")),
    dict(tipo="office", nome="office_1_kWh", categoria="terziario", archetipo="office",
         tariffa="BIORARIA", p_prel=10, kwp=17.5, pid="PV_OFF",
         pv="PROVA_CER_1_Project_office.CSV", src=("ramp", "office_1_kWh")),
]


def read_valencia(fname):
    """CSV 'dd/mm/yyyy HH:MM;kWh' -> {data: [24 valori]} (solo giorni completi)"""
    days = {}
    with open(VAL / fname, encoding="utf-8") as f:
        r = csv.reader(f, delimiter=";")
        next(r)
        for t, v in r:
            d = dt.datetime.strptime(t, "%d/%m/%Y %H:%M")
            days.setdefault(d.date(), {})[d.hour] = float(v.replace(",", "."))
    return {d: [h[i] for i in range(24)] for d, h in days.items() if len(h) == 24}


def to_grid_2025(days, ts):
    """Profilo di un altro anno sulla griglia 2025 mantenendo il giorno della settimana.

    Per ogni giorno del 2025 si prende il giorno 2024 con lo stesso giorno della
    settimana piu' vicino (spostamento 0-6 giorni in avanti); se manca o esce
    dall'anno, 7 giorni indietro. Il 29/02/2024 non e' un giorno della griglia."""
    out = []
    for t in ts[::24]:
        d25 = dt.date.fromisoformat(t[:10])
        d24 = d25.replace(year=2024)
        src = d24 + dt.timedelta(days=(d25.weekday() - d24.weekday()) % 7)
        while src not in days:
            src -= dt.timedelta(days=7)
        out.extend(days[src])
    return out


def nd_series(ts):
    ramp = {}
    with open(SCHEDA9, encoding="utf-8") as f:
        r = list(csv.reader(f, delimiter=","))
    head = r[0]
    assert [x[0] for x in r[1:]] == ts, "calendario scheda9 diverso dalla griglia"
    series = {}
    for a in ND:
        kind, key = a["src"]
        if kind == "val":
            series[a["nome"]] = to_grid_2025(read_valencia(key), ts)
        else:
            i = head.index(key)
            series[a["nome"]] = [float(x[i]) for x in r[1:]]
        assert len(series[a["nome"]]) == 8760, a["nome"]
    return series


_cache = {}


def read_source(xlsx):
    if xlsx not in _cache:
        _cache.clear()
        _cache[xlsx] = gpa.read_xlsx(xlsx)
    return _cache[xlsx]


def fmt(v):
    return f"{v:.4f}".rstrip("0").rstrip(".") or "0"


def write_profile(xlsx, keep_names, add_names, ts, series, dest):
    header, rows = read_source(xlsx)
    header = list(header)
    idx = [header.index(c) for c in keep_names]
    dest.parent.mkdir(parents=True, exist_ok=True)
    with open(dest, "w", encoding="ascii", newline="") as f:
        w = csv.writer(f, delimiter=";", lineterminator="\r\n")
        w.writerow(["timestamp"] + keep_names + add_names)
        for r, row in enumerate(rows):
            t = row[0] if isinstance(row[0], str) else row[0].strftime("%Y-%m-%dT%H:%M:%S")
            assert t == ts[r], (t, ts[r])
            w.writerow([t] + [f"{row[i]:g}" for i in idx] + [fmt(series[a][r]) for a in add_names])


def build(src_path, label, add, ts):
    """add: lista di membri (ND poi PA) da inserire. Ritorna (testo, xlsx, nomi tenuti)."""
    text = src_path.read_text(encoding="utf-8")
    lines, i_m, i_i = gpa.split_sections(text)
    for i, l in enumerate(lines):
        m = re.match(r"^(prezzi_zonali|cartella_pv|scenario_economico|profili_carico)(\s*=\s*)(.*)$", l)
        if m:
            k, eq, v = m.groups()
            if k == "scenario_economico":
                v = "../../CER_configuration/" + v
            elif k != "profili_carico":
                v = "../../" + v.replace("../", "", 1)
            lines[i] = f"{k}{eq}{v}"
    head_m, rows_m = gpa.parse_table(lines[i_m + 1:i_i])
    head_p, rows_p = gpa.parse_table(lines[i_i + 1:])
    n = len(rows_m)
    n_cons = sum(r["ruolo"] == "C" for r in rows_m)
    pros = [r for r in rows_m if r["ruolo"] == "P"]
    rel = re.search(r"^profili_carico\s*=\s*(.*)$", text, re.M).group(1).strip()
    xlsx = (src_path.parent / rel).resolve()

    k = len(add)
    drop = sorted(pros, key=lambda r: int(r["id"]))[-k:]
    drop_ids = {r["id"] for r in drop}
    drop_plants = {r["impianto"] for r in drop}
    keep_m = [r for r in rows_m if r["id"] not in drop_ids]
    new_pro = [r for r in rows_p if r["id"] not in drop_plants]
    keep_names = [r["nome_csv"] for r in keep_m]

    mem = [dict(r) for r in keep_m]
    imp = [dict(r) for r in new_pro]
    for a in add:
        capex = int(round(a["kwp"] * EUR_KWP, -2))
        mem.append(dict(
            nome_csv=a["nome"], ruolo="P", categoria=a["categoria"], archetipo=a["archetipo"],
            tariffa=a["tariffa"], P_prel_kW=str(a["p_prel"]), n_comp="-", n_perc="-",
            reddito_EUR="-", euro_gas="-", quota_inv_EUR=str(capex), mutuo_EUR_anno="0",
            impianto=a["pid"]))
        imp.append({"id": a["pid"], "proprietario": a["nome"], "kWp": f"{a['kwp']:g}",
                    "file_produzione": a["pv"], "tilt": "?", "azimut": "?",
                    "anno_esercizio": "2025", "capex_EUR": str(capex), "opex_EUR_anno": "?"})
    for i, r in enumerate(mem, 1):
        r["id"] = str(i)

    n_pro = sum(r["ruolo"] == "P" for r in mem)
    assert len(mem) == n and n_pro == len(pros) and len(imp) == n_pro, (src_path.name, label)
    n_nd = sum(1 for a in add if "tipo" in a and a["tipo"] in {x["tipo"] for x in ND})
    assert n_nd + sum(1 for a in add if a["categoria"] == "PA") == k
    assert k <= (n + 1) // 2 - 1, (src_path.name, label, "quota ND >= 50%")
    gpa.set_kv(lines, "potenza_installata_kWp", f"{sum(float(r['kWp']) for r in imp):.1f}")
    pfile = f"../profili/{label}/{src_path.stem}_{label}.csv"
    for i, l in enumerate(lines):
        if l.startswith("profili_carico"):
            lines[i] = f"profili_carico     = {pfile}"

    top = lines[:lines.index("[CER]")]
    mid = lines[lines.index("[CER]"):i_m]
    nd_names = ", ".join(a["tipo"] for a in add if a["categoria"] != "PA")
    pa_names = ", ".join(a["tipo"] for a in add if a["categoria"] == "PA") or "nessuna"
    rim = ", ".join(f"{r['nome_csv']} ({r['impianto']})" for r in drop)
    blk = [
        "# =============================================================================",
        f"# VARIANTE {label}: imprese ({nd_names}) + PA ({pa_names}) - asse 'non domestici'",
        f"# Derivata da CER_configuration/{src_path.name}: stessi N={n}, C={n_cons}, P={len(pros)}",
        "# (penetrazione prosumer invariata). Ogni ND e ogni PA e' un prosumer con il proprio",
        f"# impianto; per ognuno che entra esce un prosumer domestico, con il suo impianto:",
        f"#   rimossi: {rim}",
        f"# Quota non domestici: {k}/{n} = {100.0 * k / n:.1f}% (regola: sotto il 50%).",
        "# Le righe domestiche restano quelle della scheda di partenza (stessi reddito/gas).",
        "# ASSUNZIONI ND (da confermare):",
        "#  - antigelo, office_zummo, plastica: consumi orari REALI 2024 (CER_LoadProfiles/outputs/",
        "#    Valencia/), riportati sul 2025 mantenendo il giorno della settimana; FV simulato in",
        "#    PVsyst su Milano (Duomo) dall'autore; small_industry e office: profili RAMP (csv_scheda9);",
        "#  - kWp STIMATI (produzione/1480 kWh/kWp): antigelo 33, zummo 129, small_industry 69,",
        "#    plastica 250, office 17,5;",
        f"#  - costo impianto {EUR_KWP} EUR/kWp (come le PA), P_prel_kW dal picco del profilo per i dati",
        "#    reali, da CER_input.txt per i RAMP; tariffa BIORARIA per i terziari, ORARIO_VARIABILE",
        "#    per gli industriali; categoria industriale/terziario: NON esenti dal fattore F;",
        "#  - le PA sono quelle di CER_configuration_PA/ (stesse assunzioni).",
        "# I profili di carico sono in ../profili/ e si rigenerano con",
        "# CER_configuration_IND/genera_varianti_IND.py.",
        "# =============================================================================",
    ]
    mem_comments = [l for l in lines[i_m + 1:i_i] if l.lstrip().startswith("#")]
    out = blk + top + mid + ["[MEMBRI]"] + mem_comments + gpa.fmt_table(head_m, mem) + \
        ["[IMPIANTI]"] + gpa.fmt_table(head_p, imp)
    return "\n".join(out) + "\n", xlsx, keep_names


def n_of(path):
    c, p, e = map(int, re.match(r"CER_(\d+)_(\d+)_(\d+)\.txt", path.name).groups())
    return c + p + e, p


if __name__ == "__main__":
    ts, series_pa = gpa.pa_series()
    peak = {k: int(math.ceil(max(v) / 5.0) * 5) for k, v in series_pa.items()}
    series = nd_series(ts)
    for a in ND:
        if a["p_prel"] is None:
            a["p_prel"] = int(math.ceil(max(series[a["nome"]]) / 5.0) * 5)
    PA = []
    for a in gpa.PA:
        b = dict(a)
        b.update(categoria="PA", p_prel=a.get("p_prel") or peak[a["nome"]])
        PA.append(b)
    series.update(series_pa)
    print("P_prel_kW ND:", {a["nome"]: a["p_prel"] for a in ND})
    print("energia annua ND [kWh]:", {a["nome"]: round(sum(series[a["nome"]])) for a in ND})

    tot, skipped = 0, []
    for p in sorted(SRC.glob("CER_*.txt")):
        n, n_pros = n_of(p)
        if n < N_MIN:
            continue
        tetto = (n + 1) // 2 - 1
        for k in ND_LEVELS:
            for q in (0,) + PA_LEVELS:
                label = f"ND{k}" + (f"_PA{q}" if q else "")
                if k + q > tetto or k + q > n_pros:
                    skipped.append((p.name, label))
                    continue
                add = ND[:k] + PA[:q]
                text, xlsx, keep = build(p, label, add, ts)
                d = OUT / label
                d.mkdir(parents=True, exist_ok=True)
                (d / p.name).write_text(text, encoding="utf-8", newline="\n")
                write_profile(xlsx, keep, [a["nome"] for a in add], ts, series,
                              OUT / f"profili/{label}/{p.stem}_{label}.csv")
                tot += 1
    print("schede generate:", tot)
    print("saltate (quota >= 50% o prosumer insufficienti):", len(skipped))
