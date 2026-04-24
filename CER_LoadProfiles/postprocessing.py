"""
Modulo di post-processing per i profili di carico CER.

Funzionalita':
- Ricampionamento alla risoluzione temporale target
- Conversione da potenza istantanea (W) a energia oraria (kWh)
- Aggregazione profili in un profilo CER totale
- Export CSV compatibile con MATLAB
"""

import logging
from pathlib import Path

import pandas as pd

logger = logging.getLogger(__name__)


def resample_to_resolution(
    df: pd.DataFrame, resolution_minutes: int
) -> pd.DataFrame:
    """Ricampiona un DataFrame alla risoluzione temporale target.

    Usa la media per il ricampionamento (appropriato per valori di potenza).

    Args:
        df: DataFrame con DatetimeIndex e colonne di potenza (in Watt).
        resolution_minutes: Risoluzione target in minuti.

    Returns:
        DataFrame ricampionato alla nuova risoluzione (in Watt).
    """
    if df.empty:
        return df

    current_freq = pd.infer_freq(df.index)
    target_freq = f"{resolution_minutes}min"

    if current_freq == target_freq:
        logger.info("Risoluzione gia' a %d min, nessun ricampionamento.", resolution_minutes)
        return df

    logger.info("Ricampionamento a %d min (media)...", resolution_minutes)
    # Rimuovi eventuali duplicati nell'indice prima del resample
    if df.index.duplicated().any():
        df = df[~df.index.duplicated(keep="first")]
    df_resampled = df.resample(target_freq).mean()
    # Rimuovi eventuali NaN al bordo
    df_resampled = df_resampled.dropna(how="all")

    logger.info(
        "Ricampionamento completato: %d -> %d campioni",
        len(df),
        len(df_resampled),
    )

    return df_resampled


def resample_to_hourly_energy(df: pd.DataFrame) -> pd.DataFrame:
    """Aggrega un DataFrame di potenze (W) in energia oraria (kWh).

    Per ogni ora, calcola l'energia consumata integrando la potenza:
        E [kWh] = mean(P [W]) * 1h / 1000
    Numericamente equivalente a sum(P [W] * dt_h) / 1000.

    L'output ha una riga per ora solare (tipicamente 8760 per un anno non
    bisestile) e i valori rappresentano energia in kWh consumata in
    quell'ora.

    Args:
        df: DataFrame con DatetimeIndex a risoluzione arbitraria (<= 1h)
            e colonne di potenza in Watt.

    Returns:
        DataFrame con DatetimeIndex orario e valori in kWh per ora.
    """
    if df.empty:
        return df

    if df.index.duplicated().any():
        df = df[~df.index.duplicated(keep="first")]

    # mean(W) per ora = energia(Wh) consumata in quell'ora (per definizione)
    # Dividendo per 1000 si ottiene kWh per ora.
    hourly_kwh = df.resample("1h").mean() / 1000.0
    hourly_kwh = hourly_kwh.dropna(how="all")

    logger.info(
        "Aggregazione oraria: %d campioni -> %d ore (kWh)",
        len(df),
        len(hourly_kwh),
    )

    return hourly_kwh


def aggregate_profiles(dfs: list[pd.DataFrame]) -> pd.DataFrame:
    """Aggrega tutti i profili in un unico profilo CER totale.

    Somma tutte le colonne di tutti i DataFrame mantenendo le unita' di
    misura dell'input. Se i DataFrame di input sono in kWh per ora, il
    risultato e' in kWh per ora (totale CER).

    Args:
        dfs: Lista di DataFrame con DatetimeIndex e colonne numeriche.
             Ci si aspetta che tutti i DataFrame abbiano la stessa unita'.

    Returns:
        DataFrame con colonna 'total_CER_kWh' e DatetimeIndex.
    """
    # Unisci tutti i DataFrame sugli indici comuni
    combined = dfs[0]
    for df in dfs[1:]:
        combined = combined.join(df, how="inner")

    total = combined.sum(axis=1)

    result = pd.DataFrame({"total_CER_kWh": total})
    result.index.name = "timestamp"

    logger.info(
        "Aggregazione completata: %d profili -> 1 profilo CER totale",
        combined.shape[1],
    )

    return result


def export_to_csv(
    df: pd.DataFrame,
    filepath: str,
    convert_w_to_kw: bool = True,
    add_kwh_suffix: bool = False,
) -> None:
    """Salva un DataFrame in formato CSV compatibile con MATLAB.

    Formato:
    - Separatore: virgola
    - Prima colonna: timestamp ISO8601
    - Nessun indice numerico aggiuntivo

    Args:
        df: DataFrame con DatetimeIndex e colonne numeriche.
        filepath: Percorso del file CSV da creare.
        convert_w_to_kw: Se True, divide tutti i valori numerici per 1000
            (usato quando il DataFrame e' in W). Va posto a False se il
            DataFrame e' gia' nelle unita' desiderate (es. kWh).
        add_kwh_suffix: Se True, rinomina le colonne numeriche aggiungendo
            il suffisso '_kWh' per documentare l'unita' nel CSV.
    """
    output_path = Path(filepath)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    df_export = df.copy()

    if convert_w_to_kw:
        numeric_cols = df_export.select_dtypes(include="number").columns
        df_export[numeric_cols] = df_export[numeric_cols] / 1000.0

    if add_kwh_suffix:
        numeric_cols = df_export.select_dtypes(include="number").columns
        rename_map = {
            c: c if c.endswith("_kWh") else f"{c}_kWh"
            for c in numeric_cols
        }
        df_export = df_export.rename(columns=rename_map)

    # Formatta timestamp come ISO8601
    df_export.index = df_export.index.strftime("%Y-%m-%dT%H:%M:%S")

    df_export.to_csv(
        filepath,
        sep=",",
        index=True,
        index_label="timestamp",
        float_format="%.3f",
    )

    logger.info("CSV esportato: %s (%d righe, %d colonne)", filepath, len(df_export), len(df_export.columns))
