"""
Script orchestratore per la generazione dei profili di carico CER.

Coordina la generazione dei profili tramite RAMP (aziende/PMI)
e pyLPG (famiglie residenziali), li ricampiona alla risoluzione target,
e li esporta in formato CSV compatibile con MATLAB.

Uso:
    python generate_load_profiles.py
    python generate_load_profiles.py --config path/to/config.yaml
"""

import argparse
import logging
import sys
import time
from pathlib import Path

import yaml

from lpg_runner import run_lpg
from postprocessing import aggregate_profiles, export_to_csv, resample_to_resolution
from ramp_runner import run_ramp

logger = logging.getLogger(__name__)


def setup_logging() -> None:
    """Configura il logging strutturato con formato leggibile."""
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        datefmt="%H:%M:%S",
        handlers=[logging.StreamHandler(sys.stdout)],
    )


def load_config(config_path: str) -> dict:
    """Carica la configurazione da file YAML.

    Args:
        config_path: Percorso del file YAML di configurazione.

    Returns:
        Dizionario con la configurazione completa.

    Raises:
        FileNotFoundError: Se il file di configurazione non esiste.
    """
    path = Path(config_path)
    if not path.exists():
        raise FileNotFoundError(f"File di configurazione non trovato: {path}")

    with open(path, "r", encoding="utf-8") as f:
        config = yaml.safe_load(f)

    logger.info("Configurazione caricata da %s", path)
    return config


def main() -> None:
    """Entry point principale: orchestrazione completa della generazione profili."""
    setup_logging()

    parser = argparse.ArgumentParser(
        description="Genera profili di carico per CER (RAMP + pyLPG)"
    )
    parser.add_argument(
        "--config",
        type=str,
        default="config/simulation_config.yaml",
        help="Percorso del file di configurazione YAML",
    )
    args = parser.parse_args()

    logger.info("=" * 60)
    logger.info("GENERAZIONE PROFILI DI CARICO CER")
    logger.info("=" * 60)

    start_time = time.time()

    # Percorso base del progetto
    base_path = Path(__file__).resolve().parent

    # 1. Carica configurazione
    config = load_config(base_path / args.config)
    sim_config = config["simulation"]
    output_config = config["output"]
    resolution = sim_config["temporal_resolution_minutes"]
    output_folder = base_path / output_config["folder"]

    logger.info(
        "Anno: %d | Risoluzione: %d min | Output: %s",
        sim_config["year"],
        resolution,
        output_folder,
    )

    # 2. Genera profili aziende/PMI con RAMP
    logger.info("-" * 40)
    logger.info("FASE 1: Generazione profili RAMP (aziende/PMI)")
    logger.info("-" * 40)
    try:
        df_ramp = run_ramp(config, base_path)
    except ImportError:
        logger.error(
            "RAMP non installato. Installa con: pip install rampdemand"
        )
        df_ramp = None
    except Exception as e:
        logger.error("Errore nella generazione RAMP: %s", e, exc_info=True)
        df_ramp = None

    # 3. Genera profili famiglie con pyLPG
    logger.info("-" * 40)
    logger.info("FASE 2: Generazione profili LPG (famiglie)")
    logger.info("-" * 40)
    try:
        df_lpg = run_lpg(config)
    except Exception as e:
        logger.error("Errore nella generazione LPG: %s", e, exc_info=True)
        df_lpg = None

    # Verifica che almeno un set di profili sia stato generato
    has_ramp = df_ramp is not None and not df_ramp.empty
    has_lpg = df_lpg is not None and not df_lpg.empty

    if not has_ramp and not has_lpg:
        logger.error("Nessun profilo generato. Interruzione.")
        sys.exit(1)

    # 4. Ricampiona alla risoluzione target
    logger.info("-" * 40)
    logger.info("FASE 3: Ricampionamento a %d min", resolution)
    logger.info("-" * 40)

    dfs_to_aggregate: list = []

    if has_ramp:
        df_ramp = resample_to_resolution(df_ramp, resolution)
        # Rimuovi timezone per uniformita' con profili LPG
        if df_ramp.index.tz is not None:
            df_ramp.index = df_ramp.index.tz_localize(None)
        # Rimuovi eventuali duplicati nell'indice
        df_ramp = df_ramp[~df_ramp.index.duplicated(keep="first")]
        dfs_to_aggregate.append(df_ramp)

    if has_lpg:
        df_lpg = resample_to_resolution(df_lpg, resolution)
        if df_lpg.index.tz is not None:
            df_lpg.index = df_lpg.index.tz_localize(None)
        df_lpg = df_lpg[~df_lpg.index.duplicated(keep="first")]
        dfs_to_aggregate.append(df_lpg)

    # 5. Export CSV individuali
    logger.info("-" * 40)
    logger.info("FASE 4: Export CSV")
    logger.info("-" * 40)

    files_generated: list[str] = []

    if output_config.get("individual_profiles", True):
        # CSV con tutti i profili individuali (aziende)
        if has_ramp:
            ramp_path = str(output_folder / "profili_aziende.csv")
            export_to_csv(df_ramp, ramp_path, convert_w_to_kw=True)
            files_generated.append(ramp_path)

        # CSV con tutti i profili individuali (famiglie)
        if has_lpg:
            lpg_path = str(output_folder / "profili_famiglie.csv")
            export_to_csv(df_lpg, lpg_path, convert_w_to_kw=True)
            files_generated.append(lpg_path)

        # CSV combinato con tutti i profili
        if has_ramp and has_lpg:
            # Join sui timestamp comuni (gestisce eventuali disallineamenti)
            df_all = df_ramp.join(df_lpg, how="inner")
            all_path = str(output_folder / "profili_tutti.csv")
            export_to_csv(df_all, all_path, convert_w_to_kw=True)
            files_generated.append(all_path)

    # 6. Export CSV aggregato CER
    if output_config.get("aggregate_total", True):
        df_aggregated = aggregate_profiles(dfs_to_aggregate)
        agg_path = str(output_folder / "profilo_CER_aggregato.csv")
        export_to_csv(df_aggregated, agg_path, convert_w_to_kw=False)
        files_generated.append(agg_path)

    # 7. Riepilogo finale
    elapsed = time.time() - start_time
    n_ramp = df_ramp.shape[1] if has_ramp else 0
    n_lpg = df_lpg.shape[1] if has_lpg else 0

    logger.info("=" * 60)
    logger.info("GENERAZIONE COMPLETATA")
    logger.info("=" * 60)
    logger.info("  Profili aziende (RAMP):   %d", n_ramp)
    logger.info("  Profili famiglie (LPG):   %d", n_lpg)
    logger.info("  Totale utenti CER:        %d", n_ramp + n_lpg)
    logger.info("  Anno:                     %d", sim_config["year"])
    logger.info("  Risoluzione:              %d min", resolution)
    logger.info("  File generati:            %d", len(files_generated))
    for f in files_generated:
        logger.info("    -> %s", f)
    logger.info("  Tempo di esecuzione:      %.1f s", elapsed)
    logger.info("=" * 60)


if __name__ == "__main__":
    main()
