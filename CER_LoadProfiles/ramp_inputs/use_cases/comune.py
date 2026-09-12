"""Use case RAMP: municipio di un comune piccolo o medio.

Il bersaglio e' ARERA, ATECO 84.11 (attivita' generali di amministrazione
pubblica), classe BTA5 a Milano: 13.695 kWh/anno per punto di prelievo. E' la
cella MEGLIO CAMPIONATA dell'intera colonna - rumore di fonte -0,9% e L1 0,0504
fra il 2024 e il 2025 - quindi qui la soglia di accettazione e' stretta e
difendibile, al contrario di quanto succede per l'istruzione, dove i livelli
ARERA non sono nemmeno monotoni nella potenza.

IL SECONDO PARERE NON TORNA, e va detto invece di nasconderlo. RSEview stima
per gli uffici della Pubblica Amministrazione 113,5 kWh/m2 in Italia e 119,7 in
Lombardia (valori DERIVATI dalla Tabella 3.8, non citati: si veda
ramp_db/benchmark_letteratura.csv). Applicati a un POD da 13.695 kWh darebbero
un edificio di circa 120 m2, che per un municipio con sportello e sala
consiglio e' implausibile. Le due letture possibili sono entrambe legittime:
l'indicatore RSEview aggrega l'intero patrimonio della PA, ministeri con data
center compresi, e sovrastima un municipio di provincia; oppure un municipio
reale ha PIU' DI UN POD - uno per ala o per servizio - e la classe BTA5 ne
descrive uno solo. In entrambi i casi il confronto in kWh/m2 va riportato come
ordine di grandezza e non come bersaglio, e la superficie resta un'ipotesi
dichiarata. E' la stessa situazione di office, e l'opposto di
scuola_superiore, dove ARERA e il benchmark RSE concordavano.

COSA DISTINGUE UN MUNICIPIO DA UN UFFICIO QUALSIASI, ed e' il motivo per cui
questo archetipo esiste invece di riusare office:

  lo SPORTELLO AL PUBBLICO ha un orario proprio, piu' corto di quello degli
  uffici interni, e apre anche il SABATO MATTINA per anagrafe e stato civile:
  e' l'unico archetipo non domestico della comunita' che consuma di sabato.

  la SALA CONSIGLIO si accende DI SERA, un paio di volte al mese. E' l'unico
  carico serale non domestico dell'intera CER, e conta piu' del suo peso in
  kWh: cade in fascia F3 e in ore in cui il fotovoltaico non produce, quindi
  incide sull'energia condivisa in modo sproporzionato rispetto al consumo.

  il CED CON VIDEOSORVEGLIANZA non si spegne mai, nemmeno a Ferragosto.

AGOSTO NON E' CHIUSURA, E' PERSONALE RIDOTTO. Un municipio non chiude: riduce.
ARERA lo conferma - agosto e' il minimo dell'anno al 7,2% contro il 9,7% di
dicembre, ma il rapporto fra massimo e minimo e' appena 1,35, molto piu' piatto
di una scuola (1,9) e di un ufficio privato. Per questo il regime di agosto
tiene aperti sportello e uffici a organico dimezzato invece di spegnerli.

La stagione di riscaldamento e' quella di legge per la zona climatica E,
Milano: dal 15 ottobre al 15 aprile, DPR 412/1993 art. 9. Come negli altri
archetipi, sul contatore elettrico non finisce il calore ma i suoi ausiliari.

IL POD E' DI UN ENTE TERRITORIALE IN SENSO PROPRIO. Il comune e' il primo degli
enti locali elencati dal Testo Unico (D.Lgs. 267/2000), e il GSE lo riconosce
come "autorita' locale" ai fini CER (Consultazione GSE del 4 marzo 2021, §2.1).
Nella scheda della comunita' va quindi categoria "PA", che rende il punto di
prelievo esente dal fattore F di decurtazione della tariffa premio. E' una
scelta deliberata, non un default.

IL DIMENSIONAMENTO SI TARA SULL'USCITA: RAMP realizza circa il 70% del prodotto
number x power x func_time, quindi i valori vanno riletti dopo ogni generazione
con ramp_db/valida_non_domestici.py.
"""

import datetime as dt
import sys
from pathlib import Path

from ramp.core.core import User

# Il calendario civile italiano vive gia' nel lato domestico: si importa.
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "lpg_db"))
from valida_domestici import festivi  # noqa: E402

# Orari, in minuti dalla mezzanotte.
UFFICI = [480, 1020]          # 8:00-17:00, personale interno
SPORTELLO = [510, 780]        # 8:30-13:00, apertura al pubblico
SPORTELLO_SABATO = [510, 750]  # 8:30-12:30, anagrafe e stato civile
SALA_CONSIGLIO = [1200, 1410]  # 20:00-23:30

# Il consiglio comunale si riunisce circa due sere al mese su ventidue giorni
# lavorativi: 2/22 = 0,09. E' una frequenza tipica, non una norma.
FREQUENZA_CONSIGLIO = 0.09

# Stagione di riscaldamento della zona climatica E (Milano), DPR 412/1993 art. 9.
INIZIO_RISCALDAMENTO = (10, 15)
FINE_RISCALDAMENTO = (4, 15)


def _sempre_acceso(user: User) -> None:
    """CED e videosorveglianza: non si spengono mai, nemmeno a Ferragosto.

    ARERA misura ad agosto il 7,2% del consumo annuo contro il 9,7% di
    dicembre: un rapporto di 1,35, molto piu' piatto di una scuola. Un municipio
    e' un edificio con una base continua importante rispetto al suo picco, e
    sottodimensionarla e' l'errore che sul lato scuola ha richiesto due giri di
    correzione per essere trovato.
    """
    ced = user.add_appliance(
        name="CED_e_videosorveglianza",
        number=1,
        power=800,
        num_windows=1,
        func_time=1440,
        time_fraction_random_variability=0.05,
        wd_we_type=2,
    )
    ced.windows(window_1=[0, 1440], random_var_w=0)


def _uffici(user: User, quota: float = 1.0) -> None:
    """Uffici interni: illuminazione e postazioni.

    Args:
        quota: frazione di organico presente. Vale 0,5 nel regime di agosto,
            che e' riduzione e non chiusura.
    """
    luci = user.add_appliance(
        name="Illuminazione_uffici",
        number=max(1, int(60 * quota)),
        power=50,
        num_windows=1,
        func_time=420,
        time_fraction_random_variability=0.1,
        wd_we_type=0,
    )
    luci.windows(window_1=UFFICI, random_var_w=0.15)

    postazioni = user.add_appliance(
        name="Postazioni_PC",
        number=max(1, int(12 * quota)),
        power=200,
        num_windows=1,
        func_time=400,
        time_fraction_random_variability=0.15,
        wd_we_type=0,
    )
    postazioni.windows(window_1=UFFICI, random_var_w=0.1)


def _sportello(user: User, finestra: list[int], quota: float = 1.0) -> None:
    """Sportello al pubblico: anagrafe, protocollo, stato civile."""
    banconi = user.add_appliance(
        name="Sportello",
        number=max(1, int(4 * quota)),
        power=250,
        num_windows=1,
        func_time=int((finestra[1] - finestra[0]) * 0.8),
        time_fraction_random_variability=0.2,
        wd_we_type=0,
    )
    banconi.windows(window_1=finestra, random_var_w=0.1)


def _ausiliari_riscaldamento(user: User) -> None:
    """Circolatori e ventilconvettori: la parte elettrica del riscaldamento."""
    ausiliari = user.add_appliance(
        name="Ausiliari_riscaldamento",
        number=2,
        power=500,
        num_windows=1,
        func_time=480,
        time_fraction_random_variability=0.15,
        wd_we_type=0,
    )
    ausiliari.windows(window_1=[420, 1020], random_var_w=0.1)


def _sala_consiglio(user: User) -> None:
    """L'unico carico serale non domestico della comunita'.

    Pesa poco in kWh ma cade in fascia F3 e in ore senza sole: sull'energia
    condivisa incide piu' di quanto il suo consumo suggerisca.
    """
    consiglio = user.add_appliance(
        name="Sala_consiglio",
        number=1,
        power=3000,
        num_windows=1,
        func_time=180,
        time_fraction_random_variability=0.3,
        occasional_use=FREQUENZA_CONSIGLIO,
        wd_we_type=0,
    )
    consiglio.windows(window_1=SALA_CONSIGLIO, random_var_w=0.15)


def _feriale(riscaldamento: bool) -> User:
    user = User(user_name="comune", num_users=1)
    _sempre_acceso(user)
    _uffici(user)
    _sportello(user, SPORTELLO)
    _sala_consiglio(user)
    if riscaldamento:
        _ausiliari_riscaldamento(user)
    return user


def _sabato() -> User:
    """Solo anagrafe e stato civile, la mattina: niente uffici, niente consiglio."""
    user = User(user_name="comune", num_users=1)
    _sempre_acceso(user)
    _sportello(user, SPORTELLO_SABATO, quota=0.5)
    return user


def _agosto() -> User:
    """Organico dimezzato, non chiusura: il municipio ad agosto resta aperto."""
    user = User(user_name="comune", num_users=1)
    _sempre_acceso(user)
    _uffici(user, quota=0.5)
    _sportello(user, SPORTELLO, quota=0.5)
    return user


def _chiuso() -> User:
    """Domeniche e festivi: restano CED e videosorveglianza."""
    user = User(user_name="comune", num_users=1)
    _sempre_acceso(user)
    return user


REGIMI = {
    "feriale_inverno": lambda: _feriale(riscaldamento=True),
    "feriale_mezza": lambda: _feriale(riscaldamento=False),
    "sabato": _sabato,
    "agosto": _agosto,
    "chiuso": _chiuso,
}


def _in_stagione_di_riscaldamento(giorno: dt.date) -> bool:
    """Vero fra il 15 ottobre e il 15 aprile, estremi inclusi (zona E)."""
    corrente = (giorno.month, giorno.day)
    return corrente >= INIZIO_RISCALDAMENTO or corrente <= FINE_RISCALDAMENTO


def regime(giorno: dt.date) -> str:
    """Quale regime vale in una data.

    L'ordine conta: la domenica e i festivi chiudono comunque; il sabato ha il
    suo regime anche ad agosto, perche' lo sportello del sabato non dipende
    dalla stagione.
    """
    if giorno.weekday() == 6 or giorno in festivi(giorno.year):
        return "chiuso"
    if giorno.weekday() == 5:
        return "sabato"
    if giorno.month == 8:
        return "agosto"
    if _in_stagione_di_riscaldamento(giorno):
        return "feriale_inverno"
    return "feriale_mezza"
