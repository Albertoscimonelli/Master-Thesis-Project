import datetime as dt
import sys

import numpy as np
import pandas as pd

base = sys.argv[1]            # cartella con i CSV estratti dal PDF
out_csv = sys.argv[2]

# ------------------------------------------------------------ input estratti dal PDF
env = pd.read_csv(f"{base}/lucca_envelope_giornaliera_2024.csv")          # Fig.3: min/max giornalieri (kW)
week = pd.read_csv(f"{base}/lucca_settimana_22_28_gen_2024_kW.csv", index_col=0)  # Fig.4: 24 x 7 (kW)
# Fig.2: altezze delle barre mensili (pixel) -> MWh, scalate al totale ufficiale 290,136 MWh
tops = [174, 229, 220, 278, 307, 330, 396, 399, 278, 229, 164, 126]
y0, y40 = 539.5, 77.5
mwh = np.array([(y0 - t) / ((y0 - y40) / 40.0) for t in tops])
mwh *= 290.136 / mwh.sum()

# ------------------------------------------------------------ pulizia dell'inviluppo
e = env.copy()
e["min_c"] = e.min_kw.where(e.min_kw >= 8)                                  # 1 kW = interruzione del grafico
e["min_c"] = e.min_c.fillna(e.min_c.rolling(7, center=True, min_periods=1).median()).ffill().bfill()
e["max_c"] = e.max_kw.interpolate().ffill().bfill()
e["max_c"] = np.maximum(e.max_c, e.min_c + 1.0)
dates = pd.to_datetime(e["date"])
wd = dates.dt.weekday.to_numpy()                                           # 0 = lunedi'
month = dates.dt.month.to_numpy()

# ------------------------------------------------------------ forme giornaliere normalizzate
W = week.to_numpy().T                                                      # 7 giorni x 24 ore
S = (W - W.min(1, keepdims=True)) / (W.max(1, keepdims=True) - W.min(1, keepdims=True))
shape = {"feriale": S[:5].mean(0), "sabato": S[5], "domenica": S[6]}
def tipo(d):
    return "domenica" if d == 6 else ("sabato" if d == 5 else "feriale")

# ------------------------------------------------------------ ricostruzione + calibrazione mensile
# Massimo e minimo di ogni giorno restano quelli letti dal grafico annuo; la forma tra i due
# e' s(h)**gamma, con gamma scelto per ogni mese in modo che l'energia mensile sia quella ufficiale.
mn = e.min_c.to_numpy()
amp = (e.max_c - e.min_c).to_numpy()
S_day = np.array([shape[tipo(d)] for d in wd])             # giorni x 24
P = np.zeros_like(S_day)
gam = np.zeros(12)
for m in range(1, 13):
    idx = month == m
    target = mwh[m - 1] * 1000.0
    f = lambda g: (mn[idx, None] + amp[idx, None] * S_day[idx] ** g).sum() - target
    lo, hi = 0.05, 8.0
    if f(lo) < 0 or f(hi) > 0:
        print("mese", m, "obiettivo fuori portata:", round(f(lo)), round(f(hi)))
    for _ in range(80):
        mid = (lo + hi) / 2
        if f(mid) > 0:
            lo = mid
        else:
            hi = mid
    gam[m - 1] = (lo + hi) / 2
    P[idx] = mn[idx, None] + amp[idx, None] * S_day[idx] ** gam[m - 1]

print("esponente di forma per mese (1 = forma della settimana tipo invariata):")
print(dict(zip(range(1, 13), gam.round(2))))
print("energia ricostruita MWh: %.1f (ufficiale 290.136)" % (P.sum() / 1000))
k = gam

# ------------------------------------------------------------ verifica contro la settimana letta (Fig.4)
i0 = (dt.date(2024, 1, 22) - dt.date(2024, 1, 1)).days
rec = P[i0:i0 + 7]
obs = W
rmse = np.sqrt(((rec - obs) ** 2).mean())
print("settimana 22-28 gen: RMSE %.1f kW | energia ricostruita %.2f MWh vs letta %.2f MWh | correlazione %.2f"
      % (rmse, rec.sum() / 1000, obs.sum() / 1000, np.corrcoef(rec.ravel(), obs.ravel())[0, 1]))
print("scarto per giorno (kWh, ricostruita - letta):", (rec.sum(1) - obs.sum(1)).round(0).tolist())
print("picco annuo ricostruito: %.0f kW | minimo: %.0f kW" % (P.max(), P.min()))

# ------------------------------------------------------------ export orario
ts = pd.date_range("2024-01-01", periods=len(e) * 24, freq="h")
pd.DataFrame({"datetime": ts, "potenza_kW": P.ravel().round(1)}).to_csv(out_csv, index=False)
np.save(f"{base}/lucca_year_P.npy", P)
print("righe:", len(ts))
