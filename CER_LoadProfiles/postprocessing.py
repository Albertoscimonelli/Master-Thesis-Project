"""
Modulo di post-processing per i profili di carico CER.

Funzionalita':
- Ricampionamento alla risoluzione temporale target
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
        DataFrame ricampionato alla nuova risoluzione.
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


def aggregate_profiles(dfs: list[pd.DataFrame]) -> pd.DataFrame:
    """Aggrega tutti i profili in un unico profilo CER totale.

    Somma tutte le colonne di tutti i DataFrame e converte da Watt a kW.

    Args:
        dfs: Lista di DataFrame con DatetimeIndex e colonne in Watt.

    Returns:
        DataFrame con colonna 'total_CER_kW' e DatetimeIndex.
    """
    # Unisci tutti i DataFrame sugli indici comuni
    combined = dfs[0]
    for df in dfs[1:]:
        combined = combined.join(df, how="inner")

    # Somma tutte le colonne e converti W -> kW
    total = combined.sum(axis=1) / 1000.0

    result = pd.DataFrame({"total_CER_kW": total})
    result.index.name = "timestamp"

    logger.info(
        "Aggregazione completata: %d profili -> 1 profilo CER totale",
        combined.shape[1],
    )

    return result


def export_to_csv(
    df: pd.DataFrame, filepath: str, convert_w_to_kw: bool = True
) -> None:
    """Salva un DataFrame in formato CSV compatibile con MATLAB.

    Formato:
    - Separatore: virgola
    - Prima colonna: timestamp ISO8601
    - Valori in kW (convertiti da Watt se richiesto)
    - Nessun indice numerico aggiuntivo

    Args:
        df: DataFrame con DatetimeIndex e colonne di potenza.
        filepath: Percorso del file CSV da creare.
        convert_w_to_kw: Se True, divide tutti i valori numerici per 1000.
    """
    output_path = Path(filepath)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    df_export = df.copy()

    if convert_w_to_kw:
        numeric_cols = df_export.select_dtypes(include="number").columns
        df_export[numeric_cols] = df_export[numeric_cols] / 1000.0

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
