"""
Modulo per la generazione di profili di carico residenziali tramite pyLPG.

Usa pyLPG (wrapper Python di LoadProfileGenerator) per generare profili
realistici per nuclei familiari. Se pyLPG o il runtime .NET non sono
disponibili, genera profili sintetici di fallback.
"""

import calendar
import logging
import os
import shutil
import sqlite3
import stat
import time
import zlib
from pathlib import Path
from typing import Optional

import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)

# Generazione sempre a 1 minuto (come RAMP); l'aggregazione oraria avviene
# in postprocessing.resample_to_hourly_energy(). Non e' configurabile.
_GENERATION_RESOLUTION_MINUTES = 1

# Flag per disponibilita' pyLPG
_PYLPG_AVAILABLE = False
try:
    from pylpg import lpg_execution, lpgdata
    from pylpg.lpgpythonbindings import (
        EnergyIntensityType,
        HouseholdData,
        HouseholdDataSpecificationType,
        HouseholdNameSpecification,
        JsonReference,
        StrGuid,
    )

    _PYLPG_AVAILABLE = True
except ImportError:
    pass


def _seed_stabile(label: str, indice: int) -> int:
    """Seed riproducibile fra esecuzioni diverse dell'interprete.

    hash() sulle stringhe e' randomizzato a ogni avvio di Python (PEP 456),
    quindi due esecuzioni dello stesso script producevano profili diversi.
    crc32 e' deterministico, e la riproducibilita' e' il prerequisito per
    poter attribuire una differenza fra due run a una modifica del modello
    invece che al generatore casuale.
    """
    return zlib.crc32(f"{label}_{indice}".encode("utf-8")) % (2**31)


def _clean_lpg_results() -> None:
    """Rimuove la cartella results di pyLPG, forzando la rimozione ReadOnly.

    pyLPG (il runtime .NET) crea le sottocartelle di results con attributo
    ReadOnly su Windows. Il suo stesso processo poi fallisce al tentativo di
    cancellarle al run successivo. Questa funzione forza la rimozione
    dell'attributo e cancella l'intera cartella results.
    """
    if not _PYLPG_AVAILABLE:
        return

    lpg_pkg_dir = Path(lpg_execution.__file__).parent
    results_dir = lpg_pkg_dir / "C1" / "results"

    if not results_dir.exists():
        return

    def _force_remove_readonly(func, path, _exc_info):
        """Callback onerror: rimuove ReadOnly e riprova."""
        os.chmod(path, stat.S_IWRITE)
        func(path)

    try:
        shutil.rmtree(results_dir, onerror=_force_remove_readonly)
    except Exception as e:
        logger.debug("Pulizia results pyLPG fallita: %s", e)


def _get_household_ref(ref_name: str) -> object:
    """Ottieni il JsonReference dalla classe lpgdata.Households.

    Args:
        ref_name: Nome dell'attributo in lpgdata.Households
            (es. 'CHR02_Couple_30_64_age_with_work').

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


def _risolvi(classe_lpgdata, nome_attributo: Optional[str], etichetta: str):
    """Risolve un nome di attributo in un oggetto del catalogo lpgdata.

    Args:
        classe_lpgdata: Classe di lpgdata (GeographicLocations, HouseTypes...).
        nome_attributo: Nome dell'attributo, oppure None per non impostare nulla.
        etichetta: Nome del parametro, usato nel messaggio d'errore.

    Returns:
        L'oggetto corrispondente, o None se nome_attributo e' None.

    Raises:
        AttributeError: Se il nome non esiste nel catalogo.
    """
    if nome_attributo is None:
        return None
    if not hasattr(classe_lpgdata, nome_attributo):
        disponibili = [a for a in dir(classe_lpgdata) if not a.startswith("_")]
        raise AttributeError(
            f"{etichetta} '{nome_attributo}' non trovato in "
            f"lpgdata.{classe_lpgdata.__name__}. Primi disponibili: "
            f"{disponibili[:8]}..."
        )
    return getattr(classe_lpgdata, nome_attributo)


def _risolvi_temperatura(nome: Optional[str], database: Optional[str]):
    """Risolve il profilo di temperatura, anche se non e' nei binding Python.

    lpgdata.TemperatureProfiles e' generato dal catalogo ORIGINALE, quindi non
    contiene i profili aggiunti dalle nostre migrazioni. Invece di rigenerare
    lpgdata.py dentro venv/ (file non versionato, che si perde a ogni
    reinstallazione di pyLPG) si cerca il profilo per nome nel database
    configurato e si costruisce il JsonReference a mano: e' solo Name + Guid.

    Args:
        nome: Nome dell'attributo in lpgdata.TemperatureProfiles oppure valore
            del campo Name in tblTemperatureProfiles. None per non impostarlo.
        database: Percorso del .db3 in uso, o None per il catalogo di default.

    Returns:
        JsonReference al profilo, o None se nome e' None.

    Raises:
        LookupError: Se il profilo non esiste ne' fra i binding ne' nel database.
    """
    if nome is None:
        return None
    if hasattr(lpgdata.TemperatureProfiles, nome):
        return getattr(lpgdata.TemperatureProfiles, nome)

    # sqlite3.connect() CREA il file se non esiste: si interroga il database
    # solo dopo aver verificato che ci sia, per non lasciare in giro .db3 vuoti.
    esiste = bool(database) and Path(database).is_file()
    if esiste:
        with sqlite3.connect(database) as conn:
            riga = conn.execute(
                "SELECT Name, Guid FROM tblTemperatureProfiles WHERE Name = ?",
                (nome,),
            ).fetchone()
        if riga:
            logger.info("Profilo di temperatura dal catalogo: %s", riga[0])
            return JsonReference(riga[0], StrGuid(riga[1]))

    disponibili = [a for a in dir(lpgdata.TemperatureProfiles) if not a.startswith("_")]
    if esiste:
        with sqlite3.connect(database) as conn:
            disponibili += [
                r[0] for r in conn.execute("SELECT Name FROM tblTemperatureProfiles")
            ]
    raise LookupError(
        f"temperature_profile '{nome}' non trovato. Disponibili: {disponibili}"
    )


def _run_single_lpg_household(
    year: int,
    household_ref_name: str,
    house_type: str,
    seed: int,
    energy_intensity: str,
    database: Optional[str] = None,
    geographic_location: str = "Italy_Mailand",
    temperature_profile: Optional[str] = None,
) -> Optional[pd.DataFrame]:
    """Esegue pyLPG per un singolo nucleo familiare.

    Replica il corpo di lpg_execution.execute_lpg_single_household() perche'
    quella funzione non espone tre cose che ci servono:

    - PathToDatabase, per usare il catalogo italiano invece di quello tedesco
      originale dentro venv/;
    - CalcSpec.TemperatureProfile, che pyLPG non valorizza mai;
    - House.TargetHeatDemand / TargetCoolingDemand, che make_default_lpg_settings()
      imposta a 0 e 10000 e che execute_lpg_single_household() non sovrascrive,
      mettendoli in conflitto con l'HouseTypeCode scelto.

    Args:
        year: Anno di simulazione.
        household_ref_name: Nome attributo in lpgdata.Households.
        house_type: Nome attributo in lpgdata.HouseTypes.
        seed: Seed random per riproducibilita'.
        energy_intensity: Nome attributo in EnergyIntensityType.
        database: Percorso del profilegenerator.db3 da usare. None = quello
            di default dentro il pacchetto pylpg (catalogo tedesco originale).
        geographic_location: Nome attributo in lpgdata.GeographicLocations.
        temperature_profile: Nome attributo in lpgdata.TemperatureProfiles,
            oppure None per lasciare il default interno di LPG.

    Returns:
        DataFrame con DatetimeIndex e colonne per tipo di carico, o None se fallisce.
    """
    household_ref = _get_household_ref(household_ref_name)
    house_type_code = _risolvi(lpgdata.HouseTypes, house_type, "house_type")
    geo = _risolvi(
        lpgdata.GeographicLocations, geographic_location, "geographic_location"
    )
    temp = _risolvi_temperatura(temperature_profile, database)
    intensity = getattr(EnergyIntensityType, energy_intensity)

    _clean_lpg_results()

    esecutore = lpg_execution.LPGExecutor(1, False)
    richiesta = esecutore.make_default_lpg_settings(year)

    richiesta.House.HouseTypeCode = house_type_code
    # Lascia decidere all'house type: i default 0 / 10000 di
    # make_default_lpg_settings() descrivono una casa senza riscaldamento e
    # con 10 MWh di raffrescamento, che non e' quella che abbiamo scelto.
    richiesta.House.TargetHeatDemand = None
    richiesta.House.TargetCoolingDemand = None
    richiesta.House.Households.append(
        HouseholdData(
            None,
            None,
            HouseholdNameSpecification(household_ref),
            "hhid",
            "hhname",
            None,
            None,
            None,
            None,
            HouseholdDataSpecificationType.ByHouseholdName,
        )
    )

    spec = richiesta.CalcSpec
    spec.RandomSeed = seed
    spec.set_StartDate(f"{year}-01-01")
    spec.set_EndDate(f"{year}-12-31")
    spec.EnergyIntensityType = intensity
    spec.GeographicLocation = geo
    spec.TemperatureProfile = temp
    # Genera sempre a 1 minuto (come RAMP), il postprocessing ricampionera'
    spec.ExternalTimeResolution = "00:01:00"

    if database:
        percorso_db = Path(database).expanduser().resolve()
        if not percorso_db.exists():
            raise FileNotFoundError(
                f"Database LPG non trovato: {percorso_db}. Ricostruiscilo con "
                f"CER_LoadProfiles/lpg_db/build_italian_db.py"
            )
        richiesta.PathToDatabase = str(percorso_db)

    Path(esecutore.calculation_directory, "calcspec.json").write_text(
        richiesta.to_json(indent=4), encoding="utf-8"
    )
    esecutore.execute_lpg_binaries()
    result = esecutore.read_all_json_results_in_directory()

    # Pulisci subito dopo il run per evitare che il prossimo trovi cartelle
    # ReadOnly bloccate dal processo .NET appena terminato.
    time.sleep(2)
    _clean_lpg_results()

    return result


def _generate_synthetic_profile(
    label: str,
    idx: int,
    year: int,
) -> pd.Series:
    """Genera un profilo sintetico di fallback per un nucleo familiare.

    Produce un profilo realistico basato su pattern tipici italiani
    quando pyLPG non e' disponibile. Generato sempre a 1 minuto, come i
    profili pyLPG e RAMP.

    Args:
        label: Etichetta del tipo di famiglia.
        idx: Indice dell'unita' (per variare il seed).
        year: Anno di simulazione.

    Returns:
        Series con DatetimeIndex e valori di potenza in Watt.
    """
    days_in_year = 366 if calendar.isleap(year) else 365
    n_steps = int(days_in_year * 24 * 60 / _GENERATION_RESOLUTION_MINUTES)
    timestamps = pd.date_range(
        start=f"{year}-01-01",
        periods=n_steps,
        freq=f"{_GENERATION_RESOLUTION_MINUTES}min",
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


def _scrivi_dettaglio(
    config: dict, componenti: dict[str, dict[str, pd.Series]]
) -> None:
    """Salva la scomposizione del POD nelle sue due meta', se richiesta.

    Il file ha tre colonne per famiglia: la componente degli elettrodomestici,
    quella degli impianti di casa e la loro somma, cioe' quello che misura il
    contatore. Serve a capire da dove viene uno scarto rispetto ad ARERA:
    un eccesso sulla componente casa e' un problema di dimensionamento degli
    impianti, uno sulla componente famiglia e' un problema di dotazione o di
    orari.

    Lo scrive run_lpg() invece di generate_load_profiles.py perche' la
    scomposizione esiste solo qui: a valle sopravvive la sola somma. La
    funzione e' spenta di default e non tocca nulla del flusso principale.
    """
    if not config.get("output", {}).get("dettaglio_domestici"):
        return
    if not componenti:
        logger.warning(
            "dettaglio_domestici richiesto ma nessuna scomposizione "
            "disponibile: i profili sono sintetici o pyLPG non ha risposto."
        )
        return

    from postprocessing import export_to_csv, resample_to_hourly_energy

    colonne = {}
    for etichetta, parti in componenti.items():
        colonne[f"{etichetta}_famiglia"] = parti["famiglia"]
        colonne[f"{etichetta}_casa"] = parti["casa"]
        colonne[f"{etichetta}_POD"] = parti["famiglia"] + parti["casa"]

    orario = resample_to_hourly_energy(pd.DataFrame(colonne))
    cartella = Path(__file__).parent / config["output"]["folder"]
    percorso = cartella / "profili_famiglie_dettaglio.csv"
    export_to_csv(orario, str(percorso), convert_w_to_kw=False, add_kwh_suffix=True)


def run_lpg(config: dict) -> pd.DataFrame:
    """Genera profili di carico per tutte le utenze residenziali.

    Usa pyLPG se disponibile, altrimenti genera profili sintetici di fallback.

    Ogni colonna e' il prelievo del POD, cioe' la somma di Electricity_HH1
    (elettrodomestici della famiglia) e Electricity_House (pompa di
    circolazione del riscaldamento e, con gli house type che lo prevedono,
    condizionatore). E' la grandezza che misura il contatore e l'unica
    confrontabile con il prelievo ARERA.

    Args:
        config: Dizionario di configurazione completo dal YAML.

    Returns:
        DataFrame con DatetimeIndex e una colonna per famiglia, in Watt.
    """
    lpg_config = config["lpg"]
    sim_config = config["simulation"]
    year = sim_config["year"]
    households = lpg_config["households"]
    house_type = lpg_config["house_type"]
    energy_intensity = lpg_config.get("energy_intensity", "Random")
    geographic_location = lpg_config.get("geographic_location", "Italy_Mailand")
    temperature_profile = lpg_config.get("temperature_profile")

    # Percorso relativo alla cartella CER_LoadProfiles, cosi' il progetto
    # resta spostabile.
    database = lpg_config.get("database")
    if database:
        database = str((Path(__file__).parent / database).resolve())
        logger.info("Catalogo LPG: %s", database)
    else:
        logger.warning(
            "Nessun 'database' in config.lpg: uso il catalogo originale di "
            "pyLPG, che ha orari, vacanze e festivita' tedeschi."
        )

    all_profiles: dict[str, pd.Series] = {}
    # Le due meta' del contatore, tenute da parte per il file di dettaglio:
    # servono a diagnosticare se uno scarto viene dagli elettrodomestici o
    # dagli impianti di casa. Restano vuote per i profili sintetici, che non
    # hanno questa scomposizione.
    componenti: dict[str, dict[str, pd.Series]] = {}
    sintetici: list[str] = []
    global_idx = 0

    for hh_group in households:
        label = hh_group["label"]
        household_ref = hh_group["household_ref"]
        count = hh_group["count"]

        logger.info("Generazione %dx '%s'...", count, label)

        for i in range(count):
            global_idx += 1
            col_name = f"household_{global_idx}"
            seed = _seed_stabile(label, i)

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
                        energy_intensity=energy_intensity,
                        database=database,
                        geographic_location=geographic_location,
                        temperature_profile=temperature_profile,
                    )

                    if result_df is not None and not result_df.empty:
                        # Valida robustamente il risultato pyLPG: in alcuni casi
                        # puo' restituire dati stale di un anno precedente.
                        result_df = result_df.copy()
                        if not isinstance(result_df.index, pd.DatetimeIndex):
                            parsed_idx = pd.to_datetime(result_df.index, errors="coerce")
                            if parsed_idx.isna().all():
                                logger.warning(
                                    "  %s: indice temporale non interpretabile, "
                                    "uso fallback sintetico",
                                    col_name,
                                )
                                result_df = None
                            else:
                                result_df.index = parsed_idx

                        if result_df is not None:
                            # Filtra l'anno richiesto e invalida il run se non
                            # c'e' alcun dato valido.
                            year_mask = result_df.index.year == year
                            if not year_mask.any():
                                logger.warning(
                                    "  %s: pyLPG ha restituito dati fuori anno (%s), "
                                    "uso fallback sintetico",
                                    col_name,
                                    sorted(set(result_df.index.year.tolist())),
                                )
                                result_df = None
                            else:
                                if not year_mask.all():
                                    logger.warning(
                                        "  %s: trovati campioni fuori anno, filtro solo anno %d",
                                        col_name,
                                        year,
                                    )
                                result_df = result_df.loc[year_mask]
                                result_df = result_df[~result_df.index.duplicated(keep="first")]
                                result_df = result_df.sort_index()

                    if result_df is not None and not result_df.empty:
                        # Estrai la colonna Electricity della famiglia (HH1).
                        # Il match dev'essere sul prefisso esatto: "Electricity"
                        # e' sottostringa anche di "Electricity for Heating" e
                        # "Electricity for Car Charging", che comparirebbero con
                        # pompa di calore o trasporto attivo.
                        elec_cols = [
                            c for c in result_df.columns
                            if c.startswith("Electricity_HH")
                        ]
                        if elec_cols:
                            # pyLPG restituisce valori in kWh per timestep (1 min)
                            # Converti in Watt: W = kWh * 1000 / (1/60) = kWh * 60000
                            famiglia = result_df[elec_cols[0]] * 60000.0

                            # Electricity_House e' l'altra meta' del contatore:
                            # pompa di circolazione del riscaldamento e, con gli
                            # house type che lo prevedono, condizionatore. Il POD
                            # misura la somma delle due, quindi e' la somma che va
                            # confrontata con il prelievo ARERA e usata nel
                            # bilancio della CER.
                            #
                            # Limite noto: HT06 e HT07 modellano un impianto
                            # autonomo. Per il 27,1% delle abitazioni lombarde,
                            # che ha riscaldamento centralizzato (ISTAT AVQ 2024,
                            # variabile TRISC), la pompa non sta sul contatore
                            # della singola famiglia.
                            casa_cols = [
                                c for c in result_df.columns
                                if c == "Electricity_House"
                            ]
                            if casa_cols:
                                casa = result_df[casa_cols[0]] * 60000.0
                            else:
                                casa = pd.Series(0.0, index=result_df.index)
                                logger.info(
                                    "  %s: nessuna colonna Electricity_House, "
                                    "il POD coincide con la sola componente famiglia",
                                    col_name,
                                )

                            all_profiles[col_name] = famiglia + casa
                            etichetta = label if count == 1 else f"{label}_{i + 1}"
                            componenti[etichetta] = {
                                "famiglia": famiglia,
                                "casa": casa,
                            }
                            # Il gas non entra nel profilo elettrico, ma serve
                            # al controllo di coerenza della migrazione D01:
                            # spostando il piano cottura da elettrico a gas, il
                            # calo di elettricita' deve corrispondere al gas che
                            # compare. I fuochi si accendono le stesse volte, su
                            # un altro vettore. Va letto qui perche' i file JSON
                            # vengono cancellati due secondi dopo il run.
                            gas_cols = [
                                c for c in result_df.columns
                                if c.startswith("Gas_HH")
                            ]
                            gas_kwh = (
                                result_df[gas_cols[0]].sum() if gas_cols else 0.0
                            )
                            logger.info(
                                "  %s: OK (%d campioni, POD = famiglia %.0f kWh "
                                "+ casa %.0f kWh | gas famiglia %.0f kWh)",
                                col_name,
                                len(result_df),
                                famiglia.sum() / 60000.0,
                                casa.sum() / 60000.0,
                                gas_kwh,
                            )
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

            # Fallback sintetico (a 1 min, come RAMP)
            profile = _generate_synthetic_profile(label, i, year)
            all_profiles[col_name] = profile
            sintetici.append(col_name)
            logger.info("  %s: profilo sintetico generato", col_name)

    if not all_profiles:
        logger.warning("Nessun profilo residenziale generato.")
        return pd.DataFrame()

    df = pd.DataFrame(all_profiles)
    df.index.name = "timestamp"

    _scrivi_dettaglio(config, componenti)

    if not _PYLPG_AVAILABLE:
        logger.warning(
            "pyLPG non disponibile. Tutti i profili residenziali sono sintetici. "
            "Per profili realistici installa: pip install pyloadprofilegenerator "
            "e il runtime .NET 6 (su Linux: sudo apt install dotnet-runtime-6.0)"
        )
    elif sintetici:
        # Il fallback e' un warning fra centinaia di righe di log ed e' facile
        # non vederlo. Un profilo sintetico non ha nulla a che vedere con il
        # catalogo LPG: se ne resta anche uno solo, ogni confronto A/B fra
        # cataloghi misura il fallback invece della modifica.
        logger.error(
            "%d profili su %d sono SINTETICI, non generati da LPG: %s. "
            "Le impostazioni del catalogo (database, orari, vacanze) non hanno "
            "avuto effetto su questi. Controlla i warning qui sopra prima di "
            "usare questi profili per un confronto.",
            len(sintetici),
            len(all_profiles),
            ", ".join(sintetici),
        )

    logger.info(
        "LPG completato: %d profili residenziali generati%s",
        len(all_profiles),
        " (sintetici)" if not _PYLPG_AVAILABLE else "",
    )

    return df
