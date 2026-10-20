"""Curva FV oraria 2024 del Palazzetto di Lucca da TMY PVGIS (2005-2023) + tabelle mensili.

Passi: TMY orario (G(h), Gb(n), Gd(h), T2m, vento) -> piano moduli 15 gradi sud (azimut PVGIS 0)
-> potenza FV con perdite 14% e coeff. di temperatura -> confronto con E_m di PVGIS (310 kWp)
-> calendario 2024 (ora di orologio italiana) -> riscalatura mensile alle tabelle.
usage: python lucca_pv_tmy.py <tmy.csv> <outdir>
"""
import sys

import numpy as np
import pandas as pd
import pvlib

tmy_csv, outdir = sys.argv[1], sys.argv[2]

# ------------------------------------------------------------------ lettura TMY
lines = open(tmy_csv, encoding="utf-8").read().splitlines()
i0 = next(i for i, l in enumerate(lines) if l.startswith("time(UTC)"))
df = pd.read_csv(tmy_csv, skiprows=i0, nrows=8760)
df["t"] = pd.to_datetime(df["time(UTC)"], format="%Y%m%d:%H%M")
assert len(df) == 8760 and df["G(h)"].notna().all()
LAT, LON, ALT = 43.844, 10.489, 16
KWP = 310.0
TILT, AZ = 15, 180                                  # PVGIS azimut 0 = sud  -> pvlib 180
loc = pvlib.location.Location(LAT, LON, tz="UTC", altitude=ALT)

# ------------------------------------------------------------------ istante di riferimento delle medie orarie
# G ~ Gb*cos(zenith) + Gd deve chiudere: scelgo lo scarto temporale che la chiude meglio
best = None
for sh in np.arange(0.0, 1.01, 0.1):
    z = loc.get_solarposition(pd.DatetimeIndex(df["t"] + pd.Timedelta(hours=sh)).tz_localize("UTC")).zenith.to_numpy()
    m = z < 80
    err = np.abs(df["G(h)"].to_numpy()[m] - (df["Gb(n)"].clip(lower=0).to_numpy()[m] * np.cos(np.radians(z[m])) + df["Gd(h)"].to_numpy()[m])).mean()
    if best is None or err < best[1]:
        best = (sh, err)
SH = round(best[0], 1)
print("scarto temporale che chiude G=Gb*cos+Gd: %.1f h (errore medio %.1f W/m2)" % best)

t_utc = pd.DatetimeIndex(df["t"] + pd.Timedelta(hours=SH)).tz_localize("UTC")
sp = loc.get_solarposition(t_utc)
gb = df["Gb(n)"].clip(lower=0).to_numpy()
gd = df["Gd(h)"].clip(lower=0).to_numpy()
ghi = df["G(h)"].clip(lower=0).to_numpy()
poa = pvlib.irradiance.get_total_irradiance(
    TILT, AZ, sp.apparent_zenith, sp.azimuth, dni=gb, ghi=ghi, dhi=gd, albedo=0.2,
    dni_extra=pvlib.irradiance.get_extra_radiation(t_utc), model="haydavies")
poa_g = poa["poa_global"].fillna(0).clip(lower=0).to_numpy()
aoi = pvlib.irradiance.aoi(TILT, AZ, sp.apparent_zenith, sp.azimuth)
iam = pvlib.iam.ashrae(aoi, b=0.05).fillna(0).to_numpy()
poa_eff = (poa["poa_direct"].fillna(0).clip(lower=0).to_numpy() * iam
           + poa["poa_sky_diffuse"].fillna(0).to_numpy() + poa["poa_ground_diffuse"].fillna(0).to_numpy())
tcell = pvlib.temperature.faiman(poa_g, df["T2m"].to_numpy(), df["WS10m"].to_numpy() * 0.75, u0=25, u1=6.84)
pdc_kw = KWP * (poa_eff / 1000.0) * (1 + (-0.0040) * (tcell - 25)) * (1 - 0.14)
pdc_kw = np.where(poa_eff > 0, pdc_kw, 0.0)

# ------------------------------------------------------------------ controllo contro PVGIS (E_m dell'impianto 310 kWp)
EM_PVGIS = np.array([17055.21, 21095.14, 31853.25, 38530.34, 44377.19, 47440.69,
                     51568.82, 45980.25, 35983.83, 26274.80, 16736.17, 14336.19])   # E_m PVGIS-SARAH3, 310 kWp
mon = df["t"].dt.month.to_numpy()
mine = np.array([pdc_kw[mon == m].sum() for m in range(1, 13)])
print("TMY fisico / PVGIS E_m per mese:", (mine / EM_PVGIS).round(2).tolist())
print("TMY fisico annuo %.0f kWh | PVGIS %.0f kWh (310 kWp)" % (mine.sum(), EM_PVGIS.sum()))

# ------------------------------------------------------------------ calendario 2024, ora di orologio italiana
wall = pd.date_range("2024-01-01", "2024-12-31 23:00", freq="h")
d0 = pd.Timestamp(2024, 3, 31); d0 -= pd.Timedelta(days=(d0.weekday() + 1) % 7)
e0 = pd.Timestamp(2024, 10, 31); e0 -= pd.Timedelta(days=(e0.weekday() + 1) % 7)
dst = (wall >= d0 + pd.Timedelta(hours=3)) & (wall < e0 + pd.Timedelta(hours=3))
utc_label = wall - pd.to_timedelta(np.where(dst, 2, 1), unit="h")
key = pd.Series(np.arange(8760), index=pd.MultiIndex.from_arrays([mon, df["t"].dt.day, df["t"].dt.hour]))
mm, dd, hh = utc_label.month.to_numpy(), utc_label.day.to_numpy(), utc_label.hour.to_numpy()
dd = np.where((mm == 2) & (dd == 29), 28, dd)                 # il TMY non ha il 29 febbraio
idx = key.loc[list(zip(mm, dd, hh))].to_numpy()
P0 = pdc_kw[idx]
wm = wall.month.to_numpy()

TABS = {"pvgis_sarah3": list(EM_PVGIS)}      # tabella mensile di riferimento (scelta: la piu' affidabile)
out = pd.DataFrame({"datetime": wall})
for name, tab in TABS.items():
    tab = np.array(tab, float)
    P = P0.copy()
    for m in range(1, 13):
        s = wm == m
        P[s] *= tab[m - 1] / P[s].sum()
    out["pv_kW"] = P.round(2)
    print("%-16s annuo %7.0f kWh | picco %5.1f kW | fattore mensile min/max %.2f/%.2f"
          % (name, P.sum(), P.max(), (tab / np.array([P0[wm == m].sum() for m in range(1, 13)])).min(),
             (tab / np.array([P0[wm == m].sum() for m in range(1, 13)])).max()))
out.to_csv(f"{outdir}/lucca_pv_2024_kW.csv", index=False)
for name in TABS:
    np.save(f"{outdir}/lucca_pv_2024.npy", out["pv_kW"].to_numpy().reshape(366, 24))
print("righe:", len(out), "| ore con produzione > 0.5 kW:", int((out.iloc[:, 1] > 0.5).sum()))
