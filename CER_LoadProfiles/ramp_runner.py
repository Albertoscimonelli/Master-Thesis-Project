"""
Modulo per la generazione di profili di carico commerciali/industriali tramite RAMP.

Importa dinamicamente i file use_case dalla cartella ramp_inputs/use_cases/
e genera profili stocastici individuali per ogni utente configurato.
"""

import importlib
import logging
import sys
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)


def _import_use_case(use_case_name: str, base_path: Path) -> Any:
    """Importa dinamicamente un modulo use_case dalla cartella ramp_inputs/use_cases/.

    Args:
        use_case_name: Nome del file use_case (senza .py).
        base_path: Percorso base del progetto CER_LoadProfiles.

    Returns:
        Il modulo importato contenente la funzione create_user().

    Raises:
        ImportError: Se il modulo non viene trovato o non contiene create_user().
    """
    use_cases_dir = base_path / "ramp_inputs" / "use_cases"
    module_path = use_cases_dir / f"{use_case_name}.py"

    if not module_path.exists():
        raise ImportError(
            f"Use case '{use_case_name}' non trovato in {use_cases_dir}"
        )

    # Aggiungi il percorso al sys.path se necessario
    str_path = str(use_cases_dir)
    if str_path not in sys.path:
        sys.path.insert(0, str_path)

    module = importlib.import_module(use_case_name)

    if not hasattr(module, "create_user"):
        raise ImportError(
            f"Il modulo '{use_case_name}' non contiene la funzione create_user()"
        )

    return module


def run_ramp(config: dict, base_path: Path) -> pd.DataFrame:
    """Genera profili di carico per tutte le utenze commerciali/industriali.

    Per ogni use_case configurato, genera N profili individuali stocastici
    usando RAMP. Ogni profilo e' generato con User(num_users=1) per ottenere
    profili distinti grazie alla natura stocastica di RAMP.

    Args:
        config: Dizionario di configurazione (sezione 'ramp' del YAML).
        base_path: Percorso base del progetto CER_LoadProfiles.

    Returns:
        DataFrame con DatetimeIndex (1 minuto) e una colonna per utente in Watt.
    """
    from ramp.core.core import UseCase

    ramp_config = config["ramp"]
    sim_config = config["simulation"]
    date_start = ramp_config["date_start"]
    date_end = ramp_config["date_end"]

    all_profiles: dict[str, np.ndarray] = {}

    for uc_config in ramp_config["use_cases"]:
        use_case_name = uc_config["name"]
        num_users = uc_config["num_users"]

        logger.info(
            "Generazione %dx '%s' con RAMP...", num_users, use_case_name
        )

        # Importa il modulo use_case
        module = _import_use_case(use_case_name, base_path)

        for i in range(num_users):
            col_name = f"{use_case_name}_{i + 1}"
            logger.info("  Profilo %s...", col_name)

            # Seed per riproducibilita'
            seed = hash(f"{use_case_name}_{i}") % (2**31)
            np.random.seed(seed)

            # Crea utente fresco per ogni istanza
            user = module.create_user()

            # Crea e configura il UseCase
            # UseCase si auto-inizializza quando date_start e date_end sono forniti
            use_case = UseCase(
                name=col_name,
                users=[user],
                date_start=date_start,
                date_end=date_end,
                peak_enlarge=0.15,
            )

            # Genera profilo: array 1D in Watt, risoluzione 1 minuto
            profile = use_case.generate_daily_load_profiles(flat=True)
            all_profiles[col_name] = profile

            logger.info("  %s: %d campioni generati", col_name, len(profile))

    if not all_profiles:
        logger.warning("Nessun profilo RAMP generato.")
        return pd.DataFrame()

    # Costruisci DatetimeIndex a 1 minuto
    first_profile = next(iter(all_profiles.values()))
    n_steps = len(first_profile)
    timestamps = pd.date_range(
        start=date_start,
        periods=n_steps,
        freq="1min",
        tz=sim_config.get("timezone"),
    )

    df = pd.DataFrame(all_profiles, index=timestamps)
    df.index.name = "timestamp"

    logger.info(
        "RAMP completato: %d profili, %d campioni ciascuno",
        len(all_profiles),
        n_steps,
    )

    return df
