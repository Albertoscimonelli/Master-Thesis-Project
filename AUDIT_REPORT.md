# Project Audit Report — CER Master Thesis Project

**Date:** 2026-07-10
**Scope:** all tracked source files (MATLAB + Python), config, docs, data files.
**Mode:** review only — no code was modified.

---

## 1. Project overview

### Purpose
Simulation and techno-economic analysis of an Italian Renewable Energy Community (CER):

1. **Load profile generation** (Python, `CER_LoadProfiles/`) — stochastic hourly load profiles for 3 businesses (RAMP) and 3 households (pyLPG or synthetic fallback), exported as CSV (kWh per hour, year 2025).
2. **PV generation** — hourly PVsyst export (`PV_Generation/*.CSV`) read by MATLAB.
3. **CER energy & economic analysis** (`MAIN.m`) — shared energy, sold energy, monthly/annual revenues, grid-supply cost under 3 PUN tariff schemes.
4. **Benefit distribution** (`cer_coalition_values.m`, `shapley_cer.m`, `nucleolus_cer.m`) — cooperative game theory allocation of the CER incentive (Shapley value + Nucleolus, on the same characteristic function).
5. **PV plant sizing** (`optimizer_PV.m`) — brute-force optimization of inverter count, tilt, row spacing, maximizing IRR or NPV. (`PROVA_PV.m` is the legacy predecessor.)

### Technology stack
- **Python 3.12** (venv): rampdemand 0.5.0, pyloadprofilegenerator, pandas 3.0.x, numpy 2.4.x, PyYAML — with two runtime monkey-patches in `ramp_runner.py` for NumPy 2 / pandas 3 compatibility.
- **MATLAB**: base + Optimization Toolbox (`linprog` in the Nucleolus) + **Financial Toolbox** (`irr` in the optimizer — undeclared dependency).
- Data interchange: CSV (ISO8601 timestamps, comma separator).

### Component map

```
simulation_config.yaml
        │
        ▼
generate_load_profiles.py  (orchestrator)
   ├── ramp_runner.py ──► ramp_inputs/use_cases/{office,small_industry,retail}.py
   ├── lpg_runner.py  ──► pyLPG (or synthetic fallback)   [lpg_inputs/ = catalog only]
   └── postprocessing.py  (hourly kWh aggregation + CSV export)
        │
        ▼
outputs/csv/profili_tutti.csv (8759 rows × 6 users, kWh/h, 2025)
        │                                    PV_Generation/Salvaplast_*.CSV (PVsyst)
        ▼                                    │
      MAIN.m ◄───────────────────────────────┘
   ├── §1 load + retime onto canonical 8760-h grid
   ├── §2 shared = min(PV, load) ; sold = surplus
   ├── §3 revenues (P_CER = 0.18, P_SELL = 0.11 €/kWh)
   ├── §3b/3c  shapley_cer / nucleolus_cer  ◄── cer_coalition_values (shared v(S))
   ├── §4 grid cost ◄── profilo_prezzi_pun_2025.m  (⚠ duplicated as pun_gme_2025.m)
   └── §5 plots

optimizer_PV.m  (standalone; reads profili_tutti.csv + PVGIS TMY)
PROVA_PV.m      (legacy version of the optimizer — superseded)
```

### Execution flow (detail)

**Python pipeline** (`python generate_load_profiles.py`):
1. Load YAML config; resolve paths relative to the package.
2. Phase 1 — RAMP: for each use case × instance, seed numpy, build the RAMP `User` from the use-case module, generate a 1-minute Watt profile for 2025 (tz Europe/Rome).
3. Phase 2 — LPG: for each household, run pyLPG (validating year/index, cleaning the ReadOnly results dir) or fall back to a synthetic Italian-pattern profile.
4. Phase 3 — `resample_to_hourly_energy`: 1-min W → hourly kWh (mean/1000); strip timezone; de-duplicate index.
5. Phase 4 — export 4 CSVs (`profili_aziende`, `profili_famiglie`, `profili_tutti` [inner join], `profilo_CER_aggregato`).

**MATLAB analysis** (`MAIN.m`):
1. Read `profili_tutti.csv`; `retime` every user column onto the canonical hourly grid (fills the missing DST hour by linear interpolation).
2. Read PVsyst hourly export (regex-filtered data rows; negatives clamped to 0; pad/truncate to 8760).
3. Hourly balance: `shared = min(genPV, loadTotal)`, `sold = max(0, genPV − loadTotal)`; monthly aggregation via `accumarray`.
4. Revenues; report table.
5. `cer_coalition_values` builds `v(S)` for all 2^7 coalitions (bit 1 = PV); `shapley_cer` computes exact Shapley; `nucleolus_cer` solves sequential LPs (Maschler scheme). Two `assert`s check efficiency and consistency with §3 (good practice).
6. Grid-cost per user for MONORARIA / BIORARIA / ORARIO_VARIABILE from `profilo_prezzi_pun_2025`.
7. Plots.

**Optimizer** (`optimizer_PV.m`): 4×9×15 grid over (N_inv, tilt, D_rtr) → layout → string sizing → 8760-h solar/shading/DC/AC simulation → energy balance (building first, then CER, then grid) → CAPEX/OPEX/REV → IRR & NPV → pick optimum → re-simulate + operational plots.

---

## 2. Findings — grouped by severity

Verification status: every finding below was confirmed by direct inspection; the DST
gap was confirmed empirically (`2025-03-30 02:00` absent from `profili_aziende.csv`
and `profili_tutti.csv`).

### 🔴 CRITICAL

#### C1. Reproducibility is broken: seeds derived from Python's randomized `hash()`
- **Where:** `CER_LoadProfiles/ramp_runner.py:203`, `CER_LoadProfiles/lpg_runner.py:266`, `lpg_runner.py:163`
- **Current code:**
  ```python
  # Seed per riproducibilita'
  seed = hash(f"{use_case_name}_{i}") % (2**31)
  ```
- **Issue:** since Python 3.3, `hash()` of a `str` is salted per process (`PYTHONHASHSEED`). The seed is therefore **different on every run** — the comment "per riproducibilità" is false. Two runs of the pipeline produce different profiles, so every downstream MATLAB result (shared energy, Shapley/Nucleolus shares, optimizer IRR) is not reproducible. For a thesis this is the single most important defect.
- **Suggested fix:**
  ```python
  import zlib
  seed = zlib.crc32(f"{use_case_name}_{i}".encode()) % (2**31)
  ```
  (same for `lpg_runner.py`: `zlib.crc32(f"{label}_{i}".encode())` and `zlib.crc32(label.encode()) % 1000`).

#### C2. Duplicated price module: `pun_gme_2025.m` ≡ `profilo_prezzi_pun_2025.m`
- **Where:** `pun_gme_2025.m` (whole file) — byte-identical to `profilo_prezzi_pun_2025.m` except a trailing newline; it even contains `function [TT,S,P] = profilo_prezzi_pun_2025(...)` (function name ≠ file name).
- **Issue:** the 2025 PUN price tables exist twice. MATLAB dispatches by *file name*, so both `pun_gme_2025(...)` and `profilo_prezzi_pun_2025(...)` are callable and can silently diverge when prices are corrected in only one file. `MAIN.m` calls only `profilo_prezzi_pun_2025`.
- **Suggested fix:** delete `pun_gme_2025.m` (git history preserves it), or reduce it to a one-line wrapper if the alternative name must survive:
  ```matlab
  function [TT,S,P] = pun_gme_2025(varargin)
      [TT,S,P] = profilo_prezzi_pun_2025(varargin{:});
  end
  ```

#### C3. The two `requirements.txt` contradict each other (and the root one is UTF-16)
- **Where:** `requirements.txt` (root) vs `CER_LoadProfiles/requirements.txt`
- **Issue:**
  - Root file pins `numpy==2.4.4`, `pandas==3.0.2` (the actual environment, which the RAMP monkey-patches target).
  - Package file demands `pandas>=2.0.0,<3.0.0` and `numpy>=1.24.0,<2.0.0` — **incompatible with the root file** and with the environment the code was actually developed against.
  - The root file is saved as **UTF-16** (PowerShell `pip freeze >` default); `pip install -r requirements.txt` fails or misparses on most systems, which expect UTF-8.
- **Suggested fix:** regenerate the root file as UTF-8 (`pip freeze | Out-File -Encoding utf8 requirements.txt` or `python -m pip freeze > req.txt` from cmd), and align the package file to the reality: `numpy>=2.0`, `pandas>=3.0` (keeping the patches), or pin the old versions and delete the patches. One coherent story, not two.

### 🟠 HIGH

#### H1. `STRUTTURA_PROGETTO.txt` describes a pipeline that no longer exists
- **Where:** `STRUTTURA_PROGETTO.txt` (sections 2, 3, 4 in particular)
- **Issue:** it documents 15-minute kW CSVs, year 2024, 11 users (3 offices, 2 industries, 5 households), W→kW conversion, `resample_to_resolution`, ~35,000 rows, and a `simulazione_quartiere.py` that is no longer in the repo. The actual pipeline produces **hourly kWh CSVs, year 2025, 6 users, 8759–8760 rows** via `resample_to_hourly_energy`. Anyone (including a thesis reviewer) reading this file will misunderstand the data.
- **Suggested fix:** update sections 2–4 (resolution, units, user counts, row counts, function names) or delete the file in favour of the package README (which must also be checked for the same drift).

#### H2. Dead configuration keys and dead code in the Python pipeline
- **Where:**
  - `config/simulation_config.yaml:4` — `temporal_resolution_minutes: 15` is read and *logged* by `generate_load_profiles.py:93` but never used: output is hard-coded hourly. The log line "Risoluzione: 15 min" is actively misleading.
  - `simulation_config.yaml:7` — `ramp.num_days` never read (`date_start`/`date_end` govern).
  - `simulation_config.yaml:33` — `simulate_transportation` never read.
  - `postprocessing.py:19-57` — `resample_to_resolution()` is no longer called by anything.
  - `lpg_runner.py:91,124` — `_run_single_lpg_household(resolution_minutes=...)` parameter ignored (resolution hard-coded to `"00:01:00"`).
- **Issue:** config promises knobs that do nothing; readers assume the 15-min resolution is honoured.
- **Suggested fix:** either wire `temporal_resolution_minutes` into the resampling step, or remove the key + dead function + dead parameter and log "Risoluzione output: 1 h" only.

#### H3. Silent DST data loss and interpolation
- **Where:** generation in `ramp_runner.py:232-237` (tz-aware 1-min index) + `generate_load_profiles.py:147-151` (`tz_localize(None)` then drop duplicates `keep="first"`).
- **Issue (confirmed):** `profili_aziende.csv` / `profili_tutti.csv` are missing `2025-03-30 02:00` (spring-forward) and, on `2025-10-26 02:00`, one of the two real hours was silently discarded. `MAIN.m` then *linearly interpolates* the missing hour via `retime`. Energy is slightly altered, invisibly, twice a year.
- **Suggested fix:** generate the RAMP index tz-naive (`tz=None`) so the wall-clock year is complete and matches the LPG index and the PUN grid; or resample *after* removing the timezone and aggregate the duplicated autumn hour with `sum`/`mean` instead of dropping it.

#### H4. `optimizer_PV.m` trusts the CSV schema with no check
- **Where:** `optimizer_PV.m:104-113`
- **Current code:**
  ```matlab
  buildColIdx = strcmp(allNumNames, 'small_industry_1_kWh');
  build_cons_data = double(PT{:, allNumNames{buildColIdx}})';
  ```
- **Issue:** if the column is renamed/absent (e.g. profile regeneration with different config), `allNumNames{buildColIdx}` with an all-false mask throws a cryptic brace-indexing error — or worse, a future edit could make it silently pick the wrong column. The header comment (line 45-46) already lists a column set (`small_industry_2_kWh`, three offices…) that does not match the actual CSV.
- **Suggested fix:**
  ```matlab
  assert(any(buildColIdx), 'Colonna small_industry_1_kWh non trovata in %s', profilesFile);
  ```
  and update the stale comment.

#### H5. Hard-coded absolute personal paths
- **Where:** `MAIN.m:25,28`, `optimizer_PV.m:41,47`, `PROVA_PV.m:36`
- **Issue:** `C:\Users\scimo\desktop\Project\...` and `C:\Users\scimo\OneDrive\Desktop\PoliMi\Tesi\...` break the project on any other machine (and the TMY file lives *outside* the repo, so the optimizer is not runnable from a fresh clone at all).
- **Suggested fix:**
  ```matlab
  projRoot = fileparts(mfilename('fullpath'));
  loadFile = fullfile(projRoot, 'CER_LoadProfiles', 'outputs', 'csv', 'profili_tutti.csv');
  ```
  and move (or document) the TMY file into the repo/`PV_Generation/`.

#### H6. `acosd` domain not clamped → possible silent complex arithmetic
- **Where:** `optimizer_PV.m:342-343`, `optimizer_PV.m:646-647`, `PROVA_PV.m:180,411`
- **Current code:**
  ```matlab
  gamma_s(h) = acosd((cosd(theta_z(h))*sind(lat) - sind(delta(h))) ...
               / (cosd(90 - theta_z(h))*cosd(lat)) * sign(lat));
  ```
- **Issue:** near solar noon / at very low sun the argument can numerically fall outside [−1, 1]; MATLAB then returns a **complex** angle that propagates through `theta`, `G_tot`, `P_dc` without any warning (warnings are even switched off around the loop). Results can be silently corrupted for a few hours per year.
- **Suggested fix:** clamp the argument:
  ```matlab
  argAz = (cosd(theta_z(h))*sind(lat) - sind(delta(h))) / (cosd(90-theta_z(h))*cosd(lat)) * sign(lat);
  gamma_s(h) = acosd(min(1, max(-1, argAz)));
  ```
  (same for `theta_z` and `theta` for robustness).

### 🟡 MEDIUM

#### M1. Escalation/inflation off-by-one in cash flows
- **Where:** `optimizer_PV.m:449-453` (and `PROVA_PV.m:236`)
- **Current code:** `OPEX(y) = (...)*(1+infl)^(y-1);  REV(y) = (...)*(1+r_en)^(y-1);` with `y=2` being the **first operating year** → already escalated by one full year.
- **Issue:** first-year revenue/OPEX should normally be at year-1 prices, i.e. exponent `y-2`. With `r_en=3%`/`infl=5%` this shifts IRR/NPV visibly.
- **Suggested fix:** use `^(y-2)` (or define `year = y-1` and use `^(year-1)`), and state the convention in the comment.

#### M2. CER incentive inconsistent across models
- **Where:** `MAIN.m:40` (`P_CER = 0.18 €/kWh` = 180 €/MWh) vs `optimizer_PV.m:140` (`p_en_REC = 110*0.3` = 33 €/MWh, added on top of `p_en_sell`).
- **Issue:** the two scripts price shared energy at values ~5× apart (133 vs 180 €/MWh total). If intentional (plant-owner perspective vs community perspective), it is nowhere documented; results from the two scripts are not comparable.
- **Suggested fix:** centralize the tariff assumptions (one shared config/constants file per perspective) or add an explicit comment in both files explaining the difference.

#### M3. Two different sharing models without a note
- **Where:** `MAIN.m:101-102` (`shared = min(genPV, loadTotal)` — all consumption, including the host building, counts as shared) vs `optimizer_PV.m:391-414` (priority: building self-consumption first, then CER, then grid).
- **Issue:** with the same physical community the two scripts compute different "shared energy". Under the Italian CACER rules, the host building's self-consumption behind the POD is *not* CER-shared energy — MAIN's model overstates it.
- **Suggested fix:** in `MAIN.m`, either subtract the producer's own consumption before computing `shared`, or document explicitly that MAIN treats the PV as a pure producer with no local load.

#### M4. Nucleolus: fragile numeric tolerances and iteration cap
- **Where:** `nucleolus_cer.m:46` (`tol = 1e-7` absolute), `:63` (`for it = 1:(n+2)`), `:107` (`rank(M,1e-9)`)
- **Issue:** tightness is detected with an absolute 1e-7 € tolerance on values of order 10³–10⁴ €, while `linprog` accuracy is typically ~1e-6 relative; ties can be missed. If the loop exits at `n+2` without reaching `rank(M) >= n`, the returned `x` may not be the true nucleolus, and no warning is raised.
- **Suggested fix:** scale the tolerance (`tol = 1e-6 * max(1, abs(vGrand))`), and after the loop:
  ```matlab
  if rank(M,1e-9) < n
      warning('nucleolus_cer:notUnique','x non univocamente determinato: risultato potenzialmente approssimato.');
  end
  ```

#### M5. `irr()` — undeclared Financial Toolbox dependency
- **Where:** `optimizer_PV.m:471,732`, `PROVA_PV.m:247,479`
- **Issue:** `irr` ships with the Financial Toolbox; on a base installation the script dies deep in the triple loop. The multiple-sign-change counter (good!) already acknowledges IRR pathologies but the dependency is not documented anywhere.
- **Suggested fix:** document the toolbox requirement in the header, or inline a small bisection/`fzero` NPV-root helper to remove the dependency.

#### M6. Data provenance mismatch of the PV file
- **Where:** `PV_Generation/Salvaplast_Project_VD7_HourlyRes_1.CSV` header: *"Salvaplast VLC … Spain"*, simulated over a Meteonorm typical year (dates `01/01/90`).
- **Issue:** the loads and PUN prices are Italian (Milan patterns, PUN 2025); the PV plant appears to be simulated in **Spain** (Valencia?). Also, weekday alignment of 1990 vs 2025 is irrelevant for PV but the docs never state that this is a *typical-year* series being treated as calendar-2025.
- **Suggested fix:** document (README/MAIN header) the origin and location of the PV series and confirm the site is the intended one; if the plant is the Milan building of `optimizer_PV.m`, regenerate the PVsyst export for that site.

#### M7. Leap-year fragility of MAIN's canonical grid
- **Where:** `MAIN.m:31-36,104-108`
- **Issue:** `N_HOURS=8760`, `N_DAYS=365` are constants while `tGrid` is derived from `ANNO`; setting `ANNO=2028` silently produces an 8784-element grid vs 8760 constants → reshape errors or, worse, truncation via the PV padding path.
- **Suggested fix:** derive them: `N_HOURS = numel(tGrid); N_DAYS = days(datetime(ANNO+1,1,1)-datetime(ANNO,1,1));` and guard `reshape` accordingly.

#### M8. `PROVA_PV.m` is a superseded, internally inconsistent legacy script
- **Where:** whole file. Known defects fixed in `optimizer_PV.m` but still present here: `NPV = sum(CF)` undiscounted (line 249), `c_interconn` applied to `P_ac_nom` in the re-simulation but to `min(DC,AC)` in the main loop (lines 227 vs 458), `h_eq_dc` written even for unfeasible configs (line 252), no irradiance clamping, daily 24-h consumption profile only.
- **Suggested fix:** delete it (git preserves history) or move to an `archive/` folder with a "superseded by optimizer_PV.m" note, mirroring what was done for `simulazione_quartiere.py`.

### 🟢 LOW

| # | Where | Issue | Suggestion |
|---|-------|-------|------------|
| L1 | `MAIN.m:72` | User labels keep the `_kWh` suffix in tables/plots/Shapley player names | `userNames = erase(userNames, "_kWh")` after reading |
| L2 | `MAIN.m:169,213` | If `vGrand==0` (e.g. empty PV file → all zeros), percentage prints divide by zero (NaN) | guard with `max(vGrand, eps)` or an explicit check |
| L3 | `lpg_runner.py:58` | `shutil.rmtree(onerror=...)` is deprecated since Python 3.12 | use `onexc=` with a version check |
| L4 | `lpg_runner.py:129,329` | Magic `time.sleep(2)` for OneDrive/.NET locks | retry loop with backoff, and a comment is already there — fine, but consider moving outputs out of OneDrive-synced folders |
| L5 | `ramp_runner.py:216` | `peak_enlarge=0.15` hard-coded | expose in YAML `ramp:` section |
| L6 | `ramp_runner.py:203` | `np.random.seed` (legacy global RNG) | fine while RAMP itself uses the global RNG; note it deliberately |
| L7 | `optimizer_PV.m:422` / `PROVA_PV.m:220-221` | `clipping_losses` computed but never used/printed | print it in the summary or drop it |
| L8 | `optimizer_PV.m:581` | `N_inv_plot = 2` is an **index**, commented as "numero di inverter" | clarify: `N_inv_plot` is the index into `N_inv_vet` |
| L9 | `optimizer_PV.m:247` / `PROVA_PV.m:155` | String-sizing cell temp uses `(NOCT-25)/800*1000` while the simulation uses `(NOCT-20)/800` | align on the standard `(NOCT-20)/800·G` convention |
| L10 | root `README.md` | Two lines; does not mention MATLAB stage, PUN, game theory | short pipeline overview + run instructions |
| L11 | repo | Generated CSV outputs committed to git | acceptable for thesis reproducibility — but then the seeds must be deterministic (see C1), otherwise they can never be regenerated identically |
| L12 | `MAIN.m` prints | Mixed `EUR`/`€` in fprintf | cosmetic consistency |

### Security
No secrets, no network calls, no user input parsing beyond local config. Two mild notes:
- `_import_use_case` (`ramp_runner.py:128-161`) imports arbitrary module names taken from the YAML via `sys.path` injection — fine for a personal research project, worth knowing.
- Personal paths (`C:\Users\scimo\OneDrive\...`) embedded in tracked sources (privacy/portability, see H5).

---

## 3. Coherence check — summary

**Verified consistent (good):**
- The bitmask convention (bit 1 = PV) is identical across `cer_coalition_values`, `shapley_cer`, `nucleolus_cer`; Shapley weights and marginal-contribution indexing are correct; both allocation methods consume the *same* `v(S)` (excellent design, matches the GUIDA doc).
- `MAIN.m` self-checks: Shapley efficiency assert and consistency assert against §3 revenue — both correct.
- Units are coherent end-to-end: 1-min W → hourly kWh (`mean/1000` is correct) → MATLAB treats kWh/h ≡ kW consistently.
- `GUIDA_modelli_distribuzione.md` matches the implemented code (7 players, same formulas).
- PUN band definitions (F1/F2/F3, holidays 2025) match ARERA conventions; `weekday()` usage is locale-safe.

**Incoherent (documented above):** C2 (duplicate price file), C3 (requirements), H1 (stale STRUTTURA doc), H2 (dead config), M2 (incentive values), M3 (sharing model), M6 (PV site), plus the stale column list comment in `optimizer_PV.m:45-46`.

---

## 4. Priority action list (suggested order)

1. **C1** — deterministic seeds (`zlib.crc32`), then regenerate and re-commit the CSVs once.
2. **C3** — fix/align both requirements files (UTF-8).
3. **C2** — delete `pun_gme_2025.m`.
4. **H3** — make the generated year DST-complete (tz-naive index).
5. **H5/H4** — relative paths + schema assert, so the repo runs from a clone.
6. **H1/H2** — bring docs and config in line with reality.
7. **M1–M8** — modeling refinements, best handled consciously chapter-by-chapter in the thesis.
