"""
Use case RAMP: Negozio al dettaglio italiano.

Orario tipico: 9:00-19:30, tutti i giorni.
Elettrodomestici: illuminazione, cassa/POS, frigoriferi espositori, climatizzazione.
"""

from ramp.core.core import User


def create_user() -> User:
    """Crea un utente RAMP rappresentante un negozio al dettaglio."""
    user = User(user_name="retail", num_users=1)

    # Illuminazione vetrina + interno: 30 punti da 50W, attivi 10.5 ore
    illuminazione = user.add_appliance(
        name="Illuminazione_vetrina",
        number=30,
        power=50,
        num_windows=1,
        func_time=630,
        time_fraction_random_variability=0.05,
        wd_we_type=2,  # tutti i giorni
    )
    illuminazione.windows(window_1=[540, 1170], random_var_w=0.1)

    # Cassa + POS: 2 da 100W, attivi durante apertura
    cassa = user.add_appliance(
        name="Cassa_POS",
        number=2,
        power=100,
        num_windows=1,
        func_time=630,
        time_fraction_random_variability=0.1,
        wd_we_type=2,
    )
    cassa.windows(window_1=[540, 1170], random_var_w=0.05)

    # Frigorifero espositore: 2 da 350W, sempre acceso con ciclo di duty
    frigo = user.add_appliance(
        name="Frigorifero_espositore",
        number=2,
        power=350,
        num_windows=1,
        func_time=1440,
        fixed_cycle=1,
        wd_we_type=2,
    )
    frigo.windows(window_1=[0, 1440])
    frigo.specific_cycle_1(p_11=350, t_11=25, p_12=10, t_12=15, r_c1=0.05)

    # Climatizzazione: 1 unita da 2000W, attiva durante apertura
    clima = user.add_appliance(
        name="Climatizzazione",
        number=1,
        power=2000,
        num_windows=1,
        func_time=600,
        time_fraction_random_variability=0.2,
        wd_we_type=2,
    )
    clima.windows(window_1=[540, 1170], random_var_w=0.15)

    return user
