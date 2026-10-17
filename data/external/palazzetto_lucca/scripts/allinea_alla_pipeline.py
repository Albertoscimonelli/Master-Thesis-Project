"""Porta i CSV di Lucca (2024, ora di orologio, 8784 righe) al formato e al
calendario che la pipeline MATLAB si aspetta (vedi README §5.1):

  * anno uniforme di 8760 ore, SENZA ora legale (ora "standard", come
    PVsyst/pyLPG/RAMP);
  * FV: export in stile PVsyst ("dd/mm/yy HH:MM;kW", anno 90), letto per
    posizione da load_pv_generation;
  * carico: CSV "timestamp;<nome>_kWh" su griglia 2025, ISO con 'T', come
    CER_LoadProfiles/outputs/csv_lombardia100/100_utenti.csv.

Uso (da qualunque cartella):
    python -I allinea_alla_pipeline.py <cartella_originali> <cartella_uscita>
"""
import csv
import sys
from datetime import datetime, timedelta, date
from pathlib import Path

FMT = "%Y-%m-%d %H:%M:%S"
DST_START = datetime(2024, 3, 31, 3)   # prima ora estiva (orologio)
DST_END = datetime(2024, 10, 27, 2)    # ultima ora estiva (02:00, prima occorrenza)


def read(path, col):
    rows = list(csv.reader(open(path, encoding="utf-8")))[1:]
    return [(datetime.strptime(r[0], FMT), float(r[col])) for r in rows]


def to_standard_time(series):
    """Serie 2024 con ora legale -> ora standard, 8784 ore uniche."""
    std = {}
    for t, v in series:
        if t == datetime(2024, 3, 31, 2):
            continue                      # ora inesistente per il cambio d'ora
        summer = DST_START <= t <= DST_END
        s = t - timedelta(hours=1) if summer else t
        std[s] = v
    # 27 ottobre: l'ora 02:00 compare due volte nel mondo reale e una sola nel
    # file; la stessa riga serve per le due occorrenze (01:00 e 02:00 standard)
    std[datetime(2024, 10, 27, 2)] = std[datetime(2024, 10, 27, 1)]
    t0 = datetime(2024, 1, 1)
    full = [t0 + timedelta(hours=k) for k in range(8784)]
    missing = [t for t in full if t not in std]
    assert not missing, missing[:3]
    assert len(std) == 8784
    return {t: std[t] for t in full}


def pv_to_pvsyst(std, out):
    vals = [(t, v) for t, v in std.items() if not (t.month == 2 and t.day == 29)]
    assert len(vals) == 8760
    lines = [
        "Export orario FV palazzetto Lucca (310 kWp, 15 gradi sud) - NON e' un export PVsyst",
        "Origine: TMY PVGIS + pvlib, riscalato mese per mese alla tabella del progetto",
        "Ora standard (senza ora legale), 8760 ore, anno fittizio 90 come gli altri export",
        "Metodo: data/external/palazzetto_lucca/GUIDA_dati_e_metodi.md",
        "",
        "Simulation:;Valori orari; dal 01/01/90; al 31/12/90 ",
        "",
        "data;E_Grid",
        "    ;kW",
        "",
    ]
    for t, v in vals:
        lines.append(f"{t.day:02d}/{t.month:02d}/90 {t.hour:02d}:00;{v:g}")
    Path(out).write_text("\r\n".join(lines) + "\r\n", encoding="ascii", newline="")


def load_to_grid2025(std, out, name):
    """Carico 2024 (ora standard) -> griglia 2025 mantenendo il giorno della
    settimana: il giorno D del 2025 prende il giorno D-364 (52 settimane); per
    gli ultimi giorni, che cadrebbero nel 2025, si risale di altre 52 settimane.
    """
    lines = [f"timestamp;{name}_kWh"]
    d = date(2025, 1, 1)
    while d.year == 2025:
        src = d - timedelta(days=364)
        if src.year != 2024:
            src = d - timedelta(days=728)
        assert src.year == 2024 and src.weekday() == d.weekday()
        for h in range(24):
            v = std[datetime(src.year, src.month, src.day, h)]
            lines.append(f"{d.isoformat()}T{h:02d}:00:00;{v:g}")
        d += timedelta(days=1)
    assert len(lines) == 1 + 8760
    Path(out).write_text("\r\n".join(lines) + "\r\n", encoding="ascii", newline="")


if __name__ == "__main__":
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    pv = to_standard_time(read(src / "lucca_pv_2024_kW.csv", 1))
    load = to_standard_time(read(src / "lucca_anno_2024_ricostruito_kW.csv", 1))
    pv_to_pvsyst(pv, dst / "palazzetto_lucca_FV.CSV")
    load_to_grid2025(load, dst / "palazzetto_lucca_carico.csv", "palazzetto_lucca")
    print("ok")
