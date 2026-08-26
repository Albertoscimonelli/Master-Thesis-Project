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
import shutil
import sys
import time
from datetime import datetime
from pathlib import Path

import yaml

from cer_config_writer import scrivi_bozza_scheda
from lpg_runner import run_lpg
from postprocessing import (
    aggregate_profiles,
    export_to_csv,
    nomi_colonne_esportate,
    resample_to_hourly_energy,
)
from ramp_runner import run_ramp

logger = logging.getLogger(__name__)


def archivia(percorso: Path, cartella_storico: Path, marca: str) -> Path:
    """Salva una copia immutabile di un CSV nella cartella dello storico.

    Il file con nome fisso resta l'ultimo generato, cosi' i percorsi gia'
    scritti in CER_input.txt, nelle schede di CER_configuration/ e in
    optimizer_PV.m continuano a funzionare senza modifiche. La copia
    archiviata porta la marca temporale del run e non viene mai sovrascritta.

    Args:
        percorso: CSV appena scritto, con nome fisso.
        cartella_storico: Cartella in cui archiviare le copie.
        marca: Marca temporale del run, formato YYYYMMDD_HHMMSS.

    Returns:
        Percorso della copia archiviata.

    Raises:
        FileExistsError: Se esiste gia' un archivio con la stessa marca, cosa
            che significherebbe sovrascrivere uno storico.
    """
    cartella_storico.mkdir(parents=True, exist_ok=True)
    destinazione = cartella_storico / f"{percorso.stem}_{marca}{percorso.suffix}"
    if destinazione.exists():
        raise FileExistsError(
            f"Archivio gia' esistente: {destinazione}. Lo storico non va "
            f"sovrascritto: attendi un secondo e rilancia."
        )
    shutil.copy2(percorso, destinazione)
    return destinazione


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
    output_folder = base_path / output_config["folder"]

    logger.info(
        "Anno: %d | Risoluzione: 1h (energia in kWh) | Output: %s",
        sim_config["year"],
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

    # 4. Aggregazione oraria in energia (kWh per ora, 8760 righe/anno).
    #    I runner restituiscono potenze in W a 1 min; qui si integra su
    #    ogni ora producendo l'energia oraria in kWh.
    logger.info("-" * 40)
    logger.info("FASE 3: Aggregazione oraria in energia (kWh)")
    logger.info("-" * 40)

    dfs_to_aggregate: list = []

    if has_ramp:
        df_ramp = resample_to_hourly_energy(df_ramp)
        # Rimuovi timezone per uniformita' con profili LPG
        if df_ramp.index.tz is not None:
            df_ramp.index = df_ramp.index.tz_localize(None)
        # Rimuovi eventuali duplicati nell'indice
        df_ramp = df_ramp[~df_ramp.index.duplicated(keep="first")]
        dfs_to_aggregate.append(df_ramp)

    if has_lpg:
        df_lpg = resample_to_hourly_energy(df_lpg)
        if df_lpg.index.tz is not None:
            df_lpg.index = df_lpg.index.tz_localize(None)
        df_lpg = df_lpg[~df_lpg.index.duplicated(keep="first")]
        dfs_to_aggregate.append(df_lpg)

    # 5. Export CSV individuali
    logger.info("-" * 40)
    logger.info("FASE 4: Export CSV")
    logger.info("-" * 40)

    files_generated: list[str] = []
    archiviati: list[str] = []
    marca = datetime.now().strftime("%Y%m%d_%H%M%S")
    storico = output_folder / output_config.get("history_folder", "storico")
    versionare = output_config.get("versioned", False)

    if output_config.get("individual_profiles", True):
        # I DataFrame sono gia' in kWh/ora -> non convertire W->kW, ma
        # aggiungere il suffisso _kWh alle colonne per chiarezza.
        if has_ramp:
            ramp_path = str(output_folder / "profili_aziende.csv")
            export_to_csv(df_ramp, ramp_path, convert_w_to_kw=False, add_kwh_suffix=True)
            files_generated.append(ramp_path)

        if has_lpg:
            lpg_path = str(output_folder / "profili_famiglie.csv")
            export_to_csv(df_lpg, lpg_path, convert_w_to_kw=False, add_kwh_suffix=True)
            files_generated.append(lpg_path)

    # profili_tutti.csv: una colonna per utenza della CER. E' il file che
    # leggono CER_input.txt, le schede di CER_configuration/ e optimizer_PV.m,
    # quindi ha una chiave sua e resta generabile anche da solo.
    #
    # Il percorso e le colonne di quel CSV servono anche alla bozza di scheda
    # CER (punto 6-bis): restano a None se non viene generato.
    percorso_profili: Path | None = None
    colonne_profili: list[str] = []

    if output_config.get("combined_profiles", True):
        parti = [d for d, presente in ((df_ramp, has_ramp), (df_lpg, has_lpg)) if presente]
        if parti:
            df_all = parti[0]
            for altra in parti[1:]:
                # Join sui timestamp comuni (gestisce eventuali disallineamenti)
                df_all = df_all.join(altra, how="inner")
            all_path = output_folder / "profili_tutti.csv"
            export_to_csv(
                df_all, str(all_path), convert_w_to_kw=False, add_kwh_suffix=True
            )
            files_generated.append(str(all_path))
            percorso_profili = all_path
            colonne_profili = nomi_colonne_esportate(df_all)
            if versionare:
                archivio = archivia(all_path, storico, marca)
                archiviati.append(str(archivio))
                # La scheda punta alla copia archiviata, non al nome fisso: cosi'
                # resta legata ai profili con cui e' nata anche dopo altri run.
                percorso_profili = archivio

    # 6. Export CSV aggregato CER (gia' in kWh/ora: colonna 'total_CER_kWh')
    if output_config.get("aggregate_total", True):
        df_aggregated = aggregate_profiles(dfs_to_aggregate)
        agg_path = output_folder / "profilo_CER_aggregato.csv"
        export_to_csv(df_aggregated, str(agg_path), convert_w_to_kw=False, add_kwh_suffix=False)
        files_generated.append(str(agg_path))
        if versionare:
            archiviati.append(str(archivia(agg_path, storico, marca)))

    # 6-bis. Bozza di scheda CER in CER_configuration/ (facoltativa).
    # Avvolta in try/except di proposito: e' un di piu', e non deve mai poter
    # far fallire una generazione di profili altrimenti riuscita.
    if output_config.get("scheda_cer", False) and percorso_profili is not None:
        try:
            bozza = scrivi_bozza_scheda(
                config=config,
                colonne=colonne_profili,
                percorso_profili=percorso_profili,
                base_path=base_path,
                marca=marca,
            )
            files_generated.append(str(bozza))
        except Exception as e:
            logger.error("Bozza scheda CER non scritta: %s", e, exc_info=True)

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
    logger.info("  Risoluzione output:       1 h (energia in kWh per ora)")
    logger.info("  File generati:            %d", len(files_generated))
    for f in files_generated:
        logger.info("    -> %s", f)
    if archiviati:
        logger.info("  Archiviati nello storico: %d", len(archiviati))
        for f in archiviati:
            logger.info("    -> %s", f)
    logger.info("  Tempo di esecuzione:      %.1f s", elapsed)
    logger.info("=" * 60)


if __name__ == "__main__":
    main()
