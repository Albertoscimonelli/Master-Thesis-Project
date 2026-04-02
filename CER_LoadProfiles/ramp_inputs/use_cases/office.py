"""
Use case RAMP: Ufficio medio italiano.

Orario tipico: 8:00-18:00, lunedi-venerdi.
Elettrodomestici: illuminazione, PC, climatizzazione, stampante, macchinetta caffe.
"""

from ramp.core.core import User


def create_user() -> User:
    """Crea un utente RAMP rappresentante un ufficio medio."""
    user = User(user_name="office", num_users=1)

    # Illuminazione: 20 punti luce da 40W, attivi 9 ore (8:00-18:00)
    illuminazione = user.add_appliance(
        name="Illuminazione",
        number=20,
        power=40,
        num_windows=1,
        func_time=540,
        time_fraction_random_variability=0.1,
        wd_we_type=0,  # solo feriali
    )
    illuminazione.windows(window_1=[480, 1080], random_var_w=0.15)

    # Postazioni PC + monitor: 8 da 200W, attive 8 ore (8:30-17:30)
    pc = user.add_appliance(
        name="Postazione_PC",
        number=8,
        power=200,
        num_windows=1,
        func_time=480,
        time_fraction_random_variability=0.15,
        wd_we_type=0,
    )
    pc.windows(window_1=[510, 1050], random_var_w=0.1)

    # Climatizzazione: 2 unita da 2500W, attive 8 ore (8:00-18:00)
    clima = user.add_appliance(
        name="Climatizzazione",
        number=2,
        power=2500,
        num_windows=1,
        func_time=480,
        time_fraction_random_variability=0.25,
        wd_we_type=0,
    )
    clima.windows(window_1=[480, 1080], random_var_w=0.2)

    # Stampante/Fotocopiatrice: 2 da 300W, uso sporadico mattina e pomeriggio
    stampante = user.add_appliance(
        name="Stampante",
        number=2,
        power=300,
        num_windows=2,
        func_time=60,
        time_fraction_random_variability=0.5,
        wd_we_type=0,
    )
    stampante.windows(window_1=[540, 780], window_2=[840, 1020], random_var_w=0.3)

    # Macchinetta caffe: 1 da 1200W, uso occasionale durante orario ufficio
    caffe = user.add_appliance(
        name="Macchinetta_caffe",
        number=1,
        power=1200,
        num_windows=1,
        func_time=30,
        time_fraction_random_variability=0.3,
        occasional_use=0.8,
        wd_we_type=0,
    )
    caffe.windows(window_1=[480, 1080], random_var_w=0.2)

    return user
