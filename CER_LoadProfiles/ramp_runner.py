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


def _patch_ramp_numpy2():
    """Patch per compatibilita' RAMP 0.5.0 con NumPy >= 2.0.

    NumPy 2.x non permette int() su array 1-D; RAMP usa int(np.diff(...))
    che restituisce un array di un elemento. Questa patch sostituisce le righe
    problematiche nel metodo windows() di Appliance.
    """
    try:
        from ramp.core.core import Appliance, InvalidWindow

        def _patched_windows(self, window_1=None, window_2=None, random_var_w=0, window_3=None):
            if window_1 is not None:
                self.window_1 = window_1
            if window_2 is None:
                if self.num_windows >= 2:
                    raise InvalidWindow("Windows 2 is not provided although 2+ windows were declared")
            else:
                self.window_2 = window_2
            if window_3 is None:
                if self.num_windows == 3:
                    raise InvalidWindow("Windows 3 is not provided although 3 windows were declared")
            else:
                self.window_3 = window_3

            window_time = 0
            for i in range(1, self.num_windows + 1):
                window_time += int(np.diff(getattr(self, f"window_{i}"))[0])
            if window_time < self.func_time:
                raise InvalidWindow(
                    f"The sum of all windows time intervals for the appliance "
                    f"'{self.name}' of user '{self.user.user_name}' is smaller than "
                    f"the time the appliance is supposed to be on "
                    f"({window_time} < {self.func_time})."
                )

            self.random_var_w = random_var_w
            self.daily_use = np.zeros(1440)
            self.daily_use[self.window_1[0]:self.window_1[1]] = np.full(
                int(np.diff(self.window_1)[0]), 0.001
            )
            self.daily_use[self.window_2[0]:self.window_2[1]] = np.full(
                int(np.diff(self.window_2)[0]), 0.001
            )
            self.daily_use[self.window_3[0]:self.window_3[1]] = np.full(
                int(np.diff(self.window_3)[0]), 0.001
            )

            self.random_var_1 = int(random_var_w * np.diff(self.window_1)[0])
            self.random_var_2 = int(random_var_w * np.diff(self.window_2)[0])
            self.random_var_3 = int(random_var_w * np.diff(self.window_3)[0])
            self.user.App_list.append(self)

            if self.fixed_cycle == 1:
                self.cw11 = self.window_1
                self.cw12 = self.window_2

        Appliance.windows = _patched_windows
        logger.debug("Patch RAMP/NumPy2 applicata.")
    except ImportError:
        pass


def _patch_ramp_pandas3():
    """Patch per compatibilita' RAMP 0.5.0 con Pandas >= 3.0.

    Pandas 3.x ha rimosso l'alias 'T' per i minuti in Timedelta e date_range.
    RAMP usa 'T' in UseCase.initialize(). Questa patch lo sostituisce con 'min'.
    """
    try:
        from ramp.core.core import UseCase

        _original_init = UseCase.initialize

        def _patched_initialize(self):
            import pandas as _pd

            _orig_timedelta = _pd.Timedelta

            def _fixed_timedelta(value, unit=None, **kwargs):
                if unit == "T":
                    unit = "min"
                return _orig_timedelta(value, unit=unit, **kwargs)

            _orig_date_range = _pd.date_range

            def _fixed_date_range(*args, **kwargs):
                if kwargs.get("freq") == "T":
                    kwargs["freq"] = "min"
                return _orig_date_range(*args, **kwargs)

            _pd.Timedelta = _fixed_timedelta
            _pd.date_range = _fixed_date_range
            try:
                return _original_init(self)
            finally:
                _pd.Timedelta = _orig_timedelta
                _pd.date_range = _orig_date_range

        UseCase.initialize = _patched_initialize
        logger.debug("Patch RAMP/Pandas3 applicata.")
    except ImportError:
        pass


_patch_ramp_numpy2()
_patch_ramp_pandas3()


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
