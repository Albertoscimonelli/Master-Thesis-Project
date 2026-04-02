"""
Use case RAMP: Piccola industria italiana.

Orario tipico: 6:00-20:00, lunedi-sabato.
Elettrodomestici: macchinari CNC, compressore, illuminazione industriale, ufficio annesso.
"""

from ramp.core.core import User


def create_user() -> User:
    """Crea un utente RAMP rappresentante una piccola industria."""
    user = User(user_name="small_industry", num_users=1)

    # Macchinari CNC: 3 da 5000W, attivi 12 ore (6:00-20:00)
    cnc = user.add_appliance(
        name="Macchinario_CNC",
        number=3,
        power=5000,
        num_windows=1,
        func_time=720,
        time_fraction_random_variability=0.15,
        wd_we_type=2,  # tutti i giorni
    )
    cnc.windows(window_1=[360, 1200], random_var_w=0.1)

    # Compressore aria: 1 da 3000W con ciclo di duty
    compressore = user.add_appliance(
        name="Compressore_aria",
        number=1,
        power=3000,
        num_windows=1,
        func_time=600,
        time_fraction_random_variability=0.2,
        fixed_cycle=1,
        wd_we_type=2,
    )
    compressore.windows(window_1=[360, 1200], random_var_w=0.1)
    compressore.specific_cycle_1(p_11=3000, t_11=30, p_12=200, t_12=15, r_c1=0.1)

    # Illuminazione industriale: 40 punti luce da 60W, attivi 14 ore
    illuminazione = user.add_appliance(
        name="Illuminazione_industriale",
        number=40,
        power=60,
        num_windows=1,
        func_time=840,
        time_fraction_random_variability=0.05,
        wd_we_type=2,
    )
    illuminazione.windows(window_1=[360, 1200], random_var_w=0.1)

    # Ufficio annesso (PC): 3 postazioni da 200W, solo feriali 8:00-18:00
    ufficio = user.add_appliance(
        name="Ufficio_annesso_PC",
        number=3,
        power=200,
        num_windows=1,
        func_time=480,
        time_fraction_random_variability=0.15,
        wd_we_type=0,  # solo feriali
    )
    ufficio.windows(window_1=[480, 1080], random_var_w=0.1)

    return user
