"""
Modulo per la generazione di profili di carico residenziali tramite pyLPG.

Usa pyLPG (wrapper Python di LoadProfileGenerator) per generare profili
realistici per nuclei familiari. Se pyLPG o il runtime .NET non sono
disponibili, genera profili sintetici di fallback.
"""

import logging
import time
from pathlib import Path
from typing import Optional

import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)

# Flag per disponibilita' pyLPG
_PYLPG_AVAILABLE = False
try:
    from pylpg import lpg_execution, lpgdata
    from pylpg.lpgpythonbindings import EnergyIntensityType

    _PYLPG_AVAILABLE = True
except ImportError:
    pass


def _get_household_ref(ref_name: str) -> object:
    """Ottieni il JsonReference dalla classe lpgdata.Households.

    Args:
        ref_name: Nome dell'attributo in lpgdata.Households (es. 'CHR02_Couple_30_64_age_with_work').

    Returns:
        L'oggetto JsonReference corrispondente.

    Raises:
        AttributeError: Se il riferimento non esiste.
    """
    if not hasattr(lpgdata.Households, ref_name):
        available = [
            a for a in dir(lpgdata.Households) if not a.startswith("_")
        ]
        raise AttributeError(
            f"Household reference '{ref_name}' non trovato. "
            f"Riferimenti disponibili: {available[:10]}..."
        )
    return getattr(lpgdata.Households, ref_name)


def _run_single_lpg_household(
    year: int,
    household_ref_name: str,
    house_type: str,
    seed: int,
    resolution_minutes: int,
    energy_intensity: str,
) -> Optional[pd.DataFrame]:
    """Esegue pyLPG per un singolo nucleo familiare.

    Args:
        year: Anno di simulazione.
        household_ref_name: Nome attributo in lpgdata.Households.
        house_type: Nome attributo in lpgdata.HouseTypes.
        seed: Seed random per riproducibilita'.
        resolution_minutes: Risoluzione temporale in minuti.
        energy_intensity: Tipo di intensita' energetica.

    Returns:
        DataFrame con DatetimeIndex e colonne per tipo di carico, o None se fallisce.
    """
    household_ref = _get_household_ref(household_ref_name)
    house_type_code = getattr(lpgdata.HouseTypes, house_type)
    # Genera sempre a 1 minuto (come RAMP), il postprocessing ricampionera'
    resolution_str = "00:01:00"
    intensity = getattr(EnergyIntensityType, energy_intensity)

    # Pulisci la directory Charts che OneDrive potrebbe aver bloccato
    import shutil
    lpg_dir = Path(lpg_execution.__file__).parent / "C1" / "results" / "Charts"
    if lpg_dir.exists():
        try:
            shutil.rmtree(lpg_dir, ignore_errors=True)
            time.sleep(1)
        except Exception:
            pass

    result = lpg_execution.execute_lpg_single_household(
        year=year,
        householdref=household_ref,
        housetype=house_type_code,
        startdate=f"{year}-01-01",
        enddate=f"{year}-12-31",
        geographic_location=lpgdata.GeographicLocations.Italy_Mailand,
        random_seed=seed,
        energy_intensity=intensity,
        resolution=resolution_str,
    )

    return result


def _generate_synthetic_profile(
    label: str,
    idx: int,
    year: int,
    resolution_minutes: int,
) -> pd.Series:
    """Genera un profilo sintetico di fallback per un nucleo familiare.

    Produce un profilo realistico basato su pattern tipici italiani
    quando pyLPG non e' disponibile.

    Args:
        label: Etichetta del tipo di famiglia.
        idx: Indice dell'unita' (per variare il seed).
        year: Anno di simulazione.
        resolution_minutes: Risoluzione temporale in minuti.

    Returns:
        Series con DatetimeIndex e valori di potenza in Watt.
    """
    n_steps = int(365 * 24 * 60 / resolution_minutes)
    timestamps = pd.date_range(
        start=f"{year}-01-01",
        periods=n_steps,
        freq=f"{resolution_minutes}min",
    )

    seed = (idx * 100 + hash(label) % 1000) % (2**31)
    rng = np.random.default_rng(seed)

    potenza = np.zeros(n_steps)
    ore = np.array([t.hour + t.minute / 60 for t in timestamps])
    giorno_settimana = np.array([t.weekday() for t in timestamps])
    is_weekend = giorno_settimana >= 5

    if "pensionat" in label.lower() or "retir" in label.lower():
        # Profilo pensionati: piu' piatto, picco pranzo
        base = 200 + rng.normal(0, 30, n_steps)
        for i in range(n_steps):
            h = ore[i]
            if 7 <= h < 9:
                potenza[i] = base[i] + 800 * rng.uniform(0.5, 1.2)
            elif 11 <= h < 14:
                potenza[i] = base[i] + 1200 * rng.uniform(0.6, 1.3)
            elif 17 <= h < 21:
                potenza[i] = base[i] + 900 * rng.uniform(0.5, 1.1)
            elif 23 <= h or h < 6:
                potenza[i] = 100 + rng.normal(0, 20)
            else:
                potenza[i] = base[i] + 400 * rng.uniform(0.3, 0.8)

    elif "lavorat" in label.lower() or "coppi" in label.lower():
        # Coppie lavoratori: picchi mattina e sera, basso di giorno feriali
        base = 150 + rng.normal(0, 25, n_steps)
        for i in range(n_steps):
            h = ore[i]
            if is_weekend[i]:
                if 9 <= h < 12:
                    potenza[i] = base[i] + 900 * rng.uniform(0.5, 1.2)
                elif 12 <= h < 15:
                    potenza[i] = base[i] + 1100 * rng.uniform(0.6, 1.2)
                elif 18 <= h < 22:
                    potenza[i] = base[i] + 1000 * rng.uniform(0.5, 1.1)
                else:
                    potenza[i] = base[i] + 200 * rng.uniform(0.2, 0.6)
            else:
                if 6 <= h < 8:
                    potenza[i] = base[i] + 1500 * rng.uniform(0.6, 1.3)
                elif 8 <= h < 17:
                    potenza[i] = 120 + rng.normal(0, 30)
                elif 18 <= h < 22:
                    potenza[i] = base[i] + 1800 * rng.uniform(0.5, 1.3)
                else:
                    potenza[i] = 100 + rng.normal(0, 20)

    else:
        # Famiglie con figli: consumi piu' alti
        base = 250 + rng.normal(0, 40, n_steps)
        for i in range(n_steps):
            h = ore[i]
            if 6 <= h < 8:
                potenza[i] = base[i] + 1200 * rng.uniform(0.6, 1.4)
            elif 12 <= h < 14:
                potenza[i] = base[i] + 800 * rng.uniform(0.4, 1.0)
            elif 17 <= h < 22:
                potenza[i] = base[i] + 2000 * rng.uniform(0.5, 1.3)
            elif 23 <= h or h < 6:
                potenza[i] = 130 + rng.normal(0, 25)
            else:
                potenza[i] = base[i] + 300 * rng.uniform(0.2, 0.7)

    potenza = np.maximum(potenza, 50)  # minimo 50W standby

    return pd.Series(potenza, index=timestamps)


def run_lpg(config: dict) -> pd.DataFrame:
    """Genera profili di carico per tutte le utenze residenziali.

    Usa pyLPG se disponibile, altrimenti genera profili sintetici di fallback.

    Args:
        config: Dizionario di configurazione completo dal YAML.

    Returns:
        DataFrame con DatetimeIndex e una colonna per famiglia in Watt.
    """
    lpg_config = config["lpg"]
    sim_config = config["simulation"]
    year = sim_config["year"]
    resolution_minutes = sim_config["temporal_resolution_minutes"]
    households = lpg_config["households"]
    house_type = lpg_config["house_type"]
    energy_intensity = lpg_config.get("energy_intensity", "Random")

    all_profiles: dict[str, pd.Series] = {}
    global_idx = 0

    for hh_group in households:
        label = hh_group["label"]
        household_ref = hh_group["household_ref"]
        count = hh_group["count"]

        logger.info("Generazione %dx '%s'...", count, label)

        for i in range(count):
            global_idx += 1
            col_name = f"household_{global_idx}"
            seed = hash(f"{label}_{i}") % (2**31)

            if _PYLPG_AVAILABLE:
                logger.info(
                    "  %s (pyLPG, ref=%s, seed=%d)...", col_name, household_ref, seed
                )
                try:
                    result_df = _run_single_lpg_household(
                        year=year,
                        household_ref_name=household_ref,
                        house_type=house_type,
                        seed=seed,
                        resolution_minutes=resolution_minutes,
                        energy_intensity=energy_intensity,
                    )

                    if result_df is not None and not result_df.empty:
                        # Estrai solo la colonna Electricity
                        elec_cols = [
                            c for c in result_df.columns if "Electricity" in c
                        ]
                        if elec_cols:
                            # pyLPG restituisce valori in kWh per timestep (1 min)
                            # Converti in Watt: W = kWh * 1000 / (1/60) = kWh * 60000
                            all_profiles[col_name] = result_df[elec_cols[0]] * 60000.0
                            logger.info("  %s: OK (%d campioni)", col_name, len(result_df))
                            # Breve pausa per permettere a OneDrive di rilasciare i lock
                            time.sleep(2)
                            continue
                        else:
                            logger.warning(
                                "  %s: nessuna colonna 'Electricity' trovata, "
                                "uso fallback sintetico",
                                col_name,
                            )
                    else:
                        logger.warning(
                            "  %s: risultato vuoto, uso fallback sintetico",
                            col_name,
                        )

                except Exception as e:
                    logger.warning(
                        "  %s: errore pyLPG (%s), uso fallback sintetico",
                        col_name,
                        e,
                    )
            else:
                logger.info("  %s (profilo sintetico, label=%s)...", col_name, label)

            # Fallback sintetico
            profile = _generate_synthetic_profile(
                label, i, year, resolution_minutes
            )
            all_profiles[col_name] = profile
            logger.info("  %s: profilo sintetico generato", col_name)

    if not all_profiles:
        logger.warning("Nessun profilo residenziale generato.")
        return pd.DataFrame()

    df = pd.DataFrame(all_profiles)
    df.index.name = "timestamp"

    if not _PYLPG_AVAILABLE:
        logger.warning(
            "pyLPG non disponibile. Tutti i profili residenziali sono sintetici. "
            "Per profili realistici installa: pip install pyloadprofilegenerator "
            "e il runtime .NET 6 (su Linux: sudo apt install dotnet-runtime-6.0)"
        )

    logger.info(
        "LPG completato: %d profili residenziali generati%s",
        len(all_profiles),
        " (sintetici)" if not _PYLPG_AVAILABLE else "",
    )

    return df
