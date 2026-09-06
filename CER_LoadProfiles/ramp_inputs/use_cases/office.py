"""Use case RAMP: ufficio medio italiano.

Orario tipico 8:00-18:00, lunedi-venerdi, chiuso nelle festivita' nazionali.
Dotazione: illuminazione, postazioni PC, climatizzazione, stampante,
macchinetta del caffe'.

BERSAGLIO DI VALIDAZIONE: ARERA Milano 2025, classe ATECO 82.11 "Servizi
integrati di supporto per le funzioni d'ufficio", banda BTA4 (6-10 kW), che
vale 6.840 kWh/anno per punto di prelievo. La classe e la banda sono dichiarate
in simulation_config.yaml, non qui, perche' sono una scelta di confronto e non
una proprieta' dell'archetipo.

CHE COSA HA CORRETTO LA MISURA. La riga zero
(ramp_db/dati/validazione/00_baseline.txt) ha trovato due difetti:

  - LIVELLO 1,60x il bersaglio, 10.957 kWh contro 6.840. Misurando appliance
    per appliance, il condizionamento vale da solo 7.862 kWh, il 72% del
    totale: girava otto ore al giorno da gennaio a dicembre, perche' RAMP non
    ha nessuna nozione di stagione. Ora riceve una potenza giornaliera
    proporzionale ai gradi giorno di raffrescamento del TMY di Milano.

  - FESTIVITA' ASSENTI. wd_we_type=0 esclude i weekend ma non conosce il
    calendario: l'ufficio lavorava a Ferragosto e a Natale. Ora ogni appliance
    riceve una maschera giornaliera che azzera festivita' e domeniche.

Le potenze di targa e le finestre orarie NON sono state toccate: restano quelle
originali, e restano un'assunzione di plausibilita' senza una fonte misurata.
E' il limite dichiarato di questo archetipo, e si chiude solo con dati di
dotazione per ufficio tipo (benchmark ENEA), non con altre tarature.
"""

import sys
from pathlib import Path

from ramp.core.core import User

# ramp_db sta fuori da questa cartella e i moduli use case vengono importati
# per percorso da ramp_runner._import_use_case(): l'import va aiutato.
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "ramp_db"))

from calendario_italiano import maschera, profilo_raffrescamento  # noqa: E402


def create_user() -> User:
    """Crea un utente RAMP rappresentante un ufficio medio."""
    user = User(user_name="office", num_users=1)

    # Giorni di apertura: chiuso la domenica e nelle festivita' nazionali. Il
    # sabato lo esclude gia' wd_we_type=0, che pero' non sa nulla di calendario.
    apertura = maschera(domenica=True, festivi_nazionali=True, potenza=40)

    illuminazione = user.add_appliance(
        name="Illuminazione",
        number=20,
        power=apertura,          # 40 W nei giorni di apertura, 0 negli altri
        num_windows=1,
        func_time=540,
        time_fraction_random_variability=0.1,
        wd_we_type=0,            # solo feriali
    )
    illuminazione.windows(window_1=[480, 1080], random_var_w=0.15)

    pc = user.add_appliance(
        name="Postazione_PC",
        number=8,
        power=maschera(potenza=200),
        num_windows=1,
        func_time=480,
        time_fraction_random_variability=0.15,
        wd_we_type=0,
    )
    pc.windows(window_1=[510, 1050], random_var_w=0.1)

    # Climatizzazione: la potenza del giorno e' proporzionale ai gradi giorno
    # di raffrescamento (base 21 C) sul TMY di Milano, e resta a zero nei
    # giorni di chiusura anche se caldi. E' un proxy ad anello aperto: RAMP non
    # ha un modello termico dell'edificio, quindi niente inerzia e nessuna
    # dipendenza dall'involucro. Va dichiarato come limite.
    clima = user.add_appliance(
        name="Climatizzazione",
        number=2,
        power=profilo_raffrescamento(potenza=2500,
                                     maschera_giorni=maschera(potenza=1)),
        num_windows=1,
        func_time=480,
        time_fraction_random_variability=0.25,
        wd_we_type=0,
    )
    clima.windows(window_1=[480, 1080], random_var_w=0.2)

    stampante = user.add_appliance(
        name="Stampante",
        number=2,
        power=maschera(potenza=300),
        num_windows=2,
        func_time=60,
        time_fraction_random_variability=0.5,
        wd_we_type=0,
    )
    stampante.windows(window_1=[540, 780], window_2=[840, 1020], random_var_w=0.3)

    caffe = user.add_appliance(
        name="Macchinetta_caffe",
        number=1,
        power=maschera(potenza=1200),
        num_windows=1,
        func_time=30,
        time_fraction_random_variability=0.3,
        occasional_use=0.8,
        wd_we_type=0,
    )
    caffe.windows(window_1=[480, 1080], random_var_w=0.2)

    return user
