"""
Modulo per la generazione di profili di carico commerciali/industriali tramite RAMP.

Importa dinamicamente i file use_case dalla cartella ramp_inputs/use_cases/
e genera profili stocastici individuali per ogni utente configurato.
"""

import importlib
import logging
import random
import sys
import zlib
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)


def _seed_stabile(use_case: str, indice: int) -> int:
    """Seed riproducibile fra esecuzioni diverse dell'interprete.

    Gemella di lpg_runner._seed_stabile, e per la stessa ragione: hash() sulle
    stringhe e' randomizzato a ogni avvio di Python (PEP 456), quindi due
    esecuzioni dello stesso script producevano profili diversi. crc32 e'
    deterministico.

    Le famiglie LPG erano gia' state messe al riparo; le aziende RAMP no, e si
    vedeva: fra due run a un giorno di distanza, con la stessa configurazione,
    household_1..3 restavano identiche byte per byte mentre retail_1 cambiava
    in 8712 ore su 8759. Con profili che cambiano da soli non si puo'
    attribuire una differenza fra due run a una modifica del modello.
    """
    return zlib.crc32(f"{use_case}_{indice}".encode("utf-8")) % (2**31)


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
                    raise InvalidWindow(
                        "Windows 2 is not provided although 2+ windows were declared"
                    )
            else:
                self.window_2 = window_2
            if window_3 is None:
                if self.num_windows == 3:
                    raise InvalidWindow(
                        "Windows 3 is not provided although 3 windows were declared"
                    )
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

    Un modulo use_case puo' dichiararsi in due forme, entrambe valide:

        create_user() -> User                    forma semplice, un solo regime
        REGIMI: dict[str, Callable[[], User]]    forma a regimi di calendario
        regime(giorno: date) -> str

    La seconda serve agli archetipi che cambiano comportamento nel corso
    dell'anno - una scuola chiusa d'estate, un ufficio senza climatizzazione in
    mezza stagione - che RAMP 0.5.0 non sa rappresentare da solo: la finestra di
    un Appliance e' definita in minuti del giorno, non in giorni dell'anno.

    Returns:
        Il modulo importato, in una delle due forme.

    Raises:
        ImportError: Se il modulo non viene trovato o non dichiara nessuna
            delle due forme.
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

    ha_semplice = hasattr(module, "create_user")
    ha_regimi = hasattr(module, "REGIMI") and hasattr(module, "regime")

    if not (ha_semplice or ha_regimi):
        raise ImportError(
            f"Il modulo '{use_case_name}' non contiene ne' la funzione "
            f"create_user() ne' la coppia REGIMI / regime()"
        )

    return module


MINUTI_AL_GIORNO = 1440


def _genera_un_anno(crea_utente, chiave_seed: str, indice: int, nome: str,
                    date_start: str, date_end: str) -> np.ndarray:
    """Un anno pieno di profilo, in Watt a un minuto.

    Args:
        crea_utente: funzione senza argomenti che restituisce uno User RAMP.
        chiave_seed: stringa che identifica la sorgente di casualita'. Per uno
            use case semplice e' il suo nome; per un regime e' nome_regime,
            cosi' due regimi dello stesso archetipo non producono la stessa
            identica giornata.
        nome: etichetta passata a UseCase, usata solo per i messaggi.
    """
    from ramp.core.core import UseCase

    # Seed per riproducibilita' (vedi _seed_stabile). Vanno seminati ENTRAMBI i
    # generatori: ramp/core/core.py fa "import random" e pesca dalla libreria
    # standard (random.uniform, randint, gauss, normalvariate, choice), mentre
    # altrove usa np.random. Seminare solo numpy - com'era prima - lasciava
    # scoperta la parte che decide finestre di accensione e durate, cioe' quasi
    # tutto il profilo: i due run restavano diversi.
    seed = _seed_stabile(chiave_seed, indice)
    np.random.seed(seed)
    random.seed(seed)

    user = crea_utente()

    # UseCase si auto-inizializza quando date_start e date_end sono forniti.
    use_case = UseCase(
        name=nome,
        users=[user],
        date_start=date_start,
        date_end=date_end,
        peak_enlarge=0.15,
    )
    return use_case.generate_daily_load_profiles(flat=True)


def _genera_a_regimi(module: Any, use_case_name: str, indice: int,
                     col_name: str, date_start: str, date_end: str) -> np.ndarray:
    """Profilo annuale di un archetipo che cambia regime nel corso dell'anno.

    Si genera UN ANNO INTERO PER OGNI REGIME e poi si sceglie, giorno per
    giorno, quello che il modulo dichiara. Non si concatenano segmenti: con due
    o quattro regimi il costo sono due o quattro generazioni, e in cambio ogni
    regime pesca dalla propria stocastica su anno pieno, senza spezzare il
    flusso di numeri casuali a ogni cambio di stagione ne' moltiplicare le
    inizializzazioni di UseCase.
    """
    giorni = pd.date_range(start=date_start, end=date_end, freq="D")

    per_regime = {
        nome_regime: _genera_un_anno(
            crea, f"{use_case_name}_{nome_regime}", indice,
            f"{col_name}_{nome_regime}", date_start, date_end)
        for nome_regime, crea in module.REGIMI.items()
    }

    lunghezza = len(giorni) * MINUTI_AL_GIORNO
    profilo = np.zeros(lunghezza)
    conteggio: dict[str, int] = {}
    for numero_giorno, giorno in enumerate(giorni):
        nome_regime = module.regime(giorno.date())
        if nome_regime not in per_regime:
            raise ValueError(
                f"Lo use case '{use_case_name}' ha dichiarato il regime "
                f"'{nome_regime}' per il {giorno.date()}, ma REGIMI contiene "
                f"solo {sorted(per_regime)}"
            )
        inizio = numero_giorno * MINUTI_AL_GIORNO
        fine = inizio + MINUTI_AL_GIORNO
        profilo[inizio:fine] = per_regime[nome_regime][inizio:fine]
        conteggio[nome_regime] = conteggio.get(nome_regime, 0) + 1

    logger.info("  %s: giorni per regime %s", col_name, dict(sorted(conteggio.items())))
    return profilo


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
    date_start = ramp_config["date_start"]
    date_end = ramp_config["date_end"]

    all_profiles: dict[str, np.ndarray] = {}

    for uc_config in ramp_config["use_cases"]:
        use_case_name = uc_config["name"]

        # Interruttore per archetipo. La chiave assente vale ACCESO, cosi' le
        # configurazioni che non la dichiarano restano valide senza modifiche:
        # spegnere per omissione avrebbe azzerato in silenzio baseline,
        # campione20, lombardia20 e milano20.
        if not uc_config.get("enabled", True):
            logger.info("  '%s' disattivato nella configurazione, saltato.",
                        use_case_name)
            continue

        num_users = uc_config["num_users"]

        logger.info(
            "Generazione %dx '%s' con RAMP...", num_users, use_case_name
        )

        # Importa il modulo use_case
        module = _import_use_case(use_case_name, base_path)

        a_regimi = hasattr(module, "REGIMI")

        for i in range(num_users):
            col_name = f"{use_case_name}_{i + 1}"
            logger.info("  Profilo %s...", col_name)

            if a_regimi:
                profile = _genera_a_regimi(module, use_case_name, i, col_name,
                                           date_start, date_end)
            else:
                # Il percorso semplice resta identico a prima, seed compreso:
                # gli archetipi senza regimi devono uscire bit per bit come
                # uscivano, ed e' l'oracolo con cui si collauda questo strato.
                profile = _genera_un_anno(module.create_user, use_case_name, i,
                                          col_name, date_start, date_end)

            all_profiles[col_name] = profile

            logger.info("  %s: %d campioni generati", col_name, len(profile))

    if not all_profiles:
        logger.warning("Nessun profilo RAMP generato.")
        return pd.DataFrame()

    # Costruisci DatetimeIndex a 1 minuto
    first_profile = next(iter(all_profiles.values()))
    n_steps = len(first_profile)
    # INDICE TZ-NAIVE, e non e' un dettaglio di forma.
    #
    # RAMP costruisce un array PIATTO di 525.600 minuti giorno per giorno, e i
    # suoi use case sono definiti in ORA CIVILE LOCALE: "l'ufficio apre alle 8"
    # vuol dire le 8 dell'orologio, non le 8 UTC. Appiccicare a quell'array un
    # indice tz-aware fa avanzare le etichette in tempo ASSOLUTO, e siccome
    # l'orologio civile salta avanti il 30 marzo, tutta la meta' estiva
    # dell'anno finiva etichettata UN'ORA PIU' TARDI di quanto RAMP intendesse.
    # Misurato: il minuto che RAMP genera come "15 luglio ore 12:00" riceveva
    # l'etichetta 13:00, e cosi' ogni minuto fra il 30 marzo e il 26 ottobre.
    #
    # Due conseguenze, entrambe silenziose:
    #   - i profili aziendali risultavano sfasati di un'ora per SETTE MESI
    #     rispetto alle famiglie LPG (che sono gia' tz-naive), alla produzione
    #     PVsyst e alla griglia dei prezzi zonali - cioe' proprio rispetto alle
    #     serie con cui devono sovrapporsi per produrre energia condivisa;
    #   - l'ora del cambio (2025-03-30 02:00) spariva dall'indice civile, e
    #     un'ora reale del rientro (26 ottobre) veniva poi scartata come
    #     duplicata, lasciando 8759 righe invece di 8760.
    #
    # La chiave 'timezone' del config resta, ma NON governa piu' questo indice:
    # dichiara il fuso civile che i profili rappresentano, ed e' documentata in
    # simulation_config.yaml.
    timestamps = pd.date_range(
        start=date_start,
        periods=n_steps,
        freq="1min",
    )

    df = pd.DataFrame(all_profiles, index=timestamps)
    df.index.name = "timestamp"

    logger.info(
        "RAMP completato: %d profili, %d campioni ciascuno",
        len(all_profiles),
        n_steps,
    )

    return df
