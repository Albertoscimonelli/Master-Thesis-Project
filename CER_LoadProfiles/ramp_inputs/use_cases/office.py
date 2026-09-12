"""Use case RAMP: ufficio medio italiano, con regimi di calendario.

I gruppi di apparecchi seguono l'albero energetico degli usi finali definito da
ENEA per il settore uffici - ENEA con Assoimmobiliare, "Uffici - Quaderni
dell'Efficienza Energetica", guida alla diagnosi energetica ex Allegato II del
D.Lgs. 102/2014, §4.3 "IPE di secondo livello" - cosi' la lista non e' una
scelta arbitraria ma una citazione. Gli indici, con la loro pagina, stanno in
ramp_db/benchmark_letteratura.csv:

    illuminazione            25,7 +/- 11,8 kWh/m2                    (p. 75)
    climatizzazione          93 +/- 39 kWh/m2 in zona E-F a solo
                             vettore elettrico - Milano e' zona E    (p. 77)
    infrastruttura ICT       21,4 +/- 11,8 kWh/m2, oppure
                             534 +/- 253 kWh/utente                  (p. 77-78)

QUATTRO DIFETTI MISURATI, e come sono corretti qui. La validazione di office
prima di questa riscrittura
(ramp_db/dati/validazione/02_office_prima_correzione.txt) ha trovato 10.957
kWh/anno contro i 6.951 attesi da ARERA, L1 sulla forma mensile 0,0866 contro
una soglia di 0,0407, e TVD identica nelle tre stagioni:

  1. NESSUNA STAGIONALITA'. Il clima girava 8 ore al giorno tutti i giorni
     dell'anno, e la media giornaliera feriale stava fra 40,0 e 43,6 kWh in
     tutti e dodici i mesi, con agosto indistinguibile da gennaio. Ora i
     regimi separano raffrescamento, riscaldamento e mezza stagione.
  2. NESSUN GIORNO FESTIVO. Natale valeva 47,9 kWh, Ferragosto 40,6,
     Capodanno 44,8: giornate di lavoro piene. Ora i festivi nazionali cadono
     nel regime "chiuso" e valgono 1,19 kWh, i soli carichi permanenti.
  3. NESSUNA PAUSA PRANZO. La curva feriale saliva monotona fino al picco
     delle 15:00, contro le 11:00 del profilo GSE. Ora illuminazione, PC e
     clima hanno due finestre, lo stesso schema che la stampante usava gia'.
     Da sola la pausa non bastava a spostare il picco: ci e' riuscita quando
     e' rientrato anche il peso dei mesi estivi.
  4. NESSUNA CHIUSURA ESTIVA. Il modello teneva agosto quasi pari a luglio,
     mentre ARERA misura 6,9% contro 10,5%: gli uffici italiani chiudono, e
     l'aggregato lo vede. Ora le due settimane attorno a Ferragosto sono un
     regime a se'.

Il percorso completo, correzione per correzione e con i numeri di ciascun
passaggio, sta nei file 02, 03 e 04 di ramp_db/dati/validazione/.

IL CALENDARIO CIVILE NON SI RISCRIVE. Le festivita' nazionali sono le stesse
per una famiglia e per un ufficio: si importano da lpg_db/valida_domestici.py
invece di duplicarle. Quello che sta qui e' il CALENDARIO DI APERTURA di questo
edificio, che e' una proprieta' sua e vuole una fonte: la stagione di
riscaldamento e' quella di legge per la zona climatica E (Milano), cioe' dal 15
ottobre al 15 aprile, DPR 412/1993 art. 9. La stagione di raffrescamento non e'
normata e resta un'ipotesi dichiarata.

IL DIMENSIONAMENTO SI TARA SULL'USCITA, NON A TAVOLINO: RAMP realizza circa il
70% del prodotto number x power x func_time, quindi i valori qui sotto vanno
riletti dopo ogni generazione con valida_non_domestici.py. La classe ARERA di
confronto non e' stata fissata prima della correzione, per non scegliere il
bersaglio in modo da far tornare il numero.

QUESTIONE APERTA: IL LIVELLO E' CIRCA IL 30% SOTTO L'ATTESO, e non e' stata
chiusa gonfiando gli apparecchi. Va dichiarata in tesi, con il suo contesto,
perche' il contesto e' la parte che spiega il numero.

ARERA resta il bersaglio giusto per il livello: misura il prelievo medio annuo
di un PUNTO DI PRELIEVO reale, che e' esattamente la grandezza che questo
modulo produce - i kWh che passano da un contatore in un anno. Non e' una
stima, e' una media su POD veri.

ENEA non risolve la questione, e va spiegato perche'. I suoi indici vengono
dalle diagnosi energetiche OBBLIGATORIE ex art. 8 del D.Lgs. 102/2014, cioe'
da grandi imprese ed energivori: il §4.1 del Quaderno descrive un campione in
cui il gruppo dimensionale piu' numeroso sta fra 3.000 e 10.000 m2. Un ufficio
da otto postazioni non appartiene a quella popolazione. Inoltre l'IPE globale
di 201 kWh/m2 comprende TUTTI i vettori, gas incluso, mentre qui si modella il
solo contatore elettrico: confrontarli direttamente sarebbe sbagliato, ed e'
il motivo per cui si usano gli IPE per uso finale e la riga "solo elettrico".

Il confronto che NON dipende dall'ipotesi sui metri quadri e' l'ICT per utente:
ENEA da' 534 +/- 253 kWh/utente, che per otto postazioni farebbero 4.272 kWh di
sola informatica - quasi quanto l'intero archetipo. O le otto postazioni sono
troppe per un BTA4, o il consumo per postazione qui e' basso; ma l'ICT di ENEA
comprende server e apparati di rete che un ufficio di questa taglia non ha.
Chiudere la questione richiede un dato che nessuna delle due fonti fornisce:
quante persone e quanti metri quadri stiano dietro a un POD di classe BTA4.
"""

import datetime as dt
import sys
from pathlib import Path

from ramp.core.core import User

# Il calendario civile italiano vive gia' nel lato domestico: si importa, non si
# riscrive. Stesso idioma di bootstrap che ramp_runner usa per caricare questo
# stesso modulo.
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "lpg_db"))
from valida_domestici import festivi  # noqa: E402

# Orario di ufficio, in minuti dalla mezzanotte: 8:00-13:00 e 14:00-18:00.
# La pausa e' l'ora che manca fra le due finestre.
MATTINA = [480, 780]
POMERIGGIO = [840, 1080]

# Stagione di riscaldamento della zona climatica E (Milano), DPR 412/1993 art. 9.
INIZIO_RISCALDAMENTO = (10, 15)
FINE_RISCALDAMENTO = (4, 15)

# Stagione di raffrescamento: IPOTESI DICHIARATA. A differenza di quella di
# riscaldamento non esiste una norma che la fissi, quindi qui ci sono DUE
# ipotesi sovrapposte: che la stagione cominci il 1 giugno, e che finisca a
# meta' settembre invece che alla fine del mese.
#
# La seconda non viene da una fonte, viene dal dato: ARERA mette settembre al
# 7,6% del consumo annuo, sotto la media, mentre il modello che raffrescava per
# tutto il mese lo portava al 13,4%, il suo mese piu' alto in assoluto. Meta'
# settembre e' il compromesso fra un mese che a Milano comincia caldo e finisce
# mite. Va dichiarata in tesi come ipotesi tarata sull'osservazione, non come
# un dato di calendario.
INIZIO_RAFFRESCAMENTO = (6, 1)
FINE_RAFFRESCAMENTO = (9, 15)

# Chiusura estiva: le due settimane lavorative attorno a Ferragosto. E'
# un'IPOTESI DICHIARATA - nessuna norma la impone - ma l'effetto aggregato lo
# misura ARERA, che da' agosto al 6,9% del consumo annuo contro il 10,5% di
# luglio: senza chiusura il modello teneva i due mesi quasi uguali, ed era il
# contributo singolo piu' grande alla distanza dalla forma mensile reale.
INIZIO_CHIUSURA_ESTIVA = (8, 11)
FINE_CHIUSURA_ESTIVA = (8, 22)


def _carichi_permanenti(user: User) -> None:
    """Router, allarme, luci di emergenza: l'ufficio non e' mai a zero.

    Presenti in ogni regime, weekend compreso. Nella versione precedente
    l'archetipo valeva esattamente 0,000 kWh su 2.496 ore di fine settimana,
    che non e' quello che fa un ufficio reale.
    """
    permanenti = user.add_appliance(
        name="Carichi_permanenti",
        number=1,
        power=50,
        num_windows=1,
        func_time=1440,
        time_fraction_random_variability=0.05,
        wd_we_type=2,          # tutti i giorni, anche sabato e domenica
    )
    permanenti.windows(window_1=[0, 1440], random_var_w=0)


def _apparecchi_di_lavoro(user: User) -> None:
    """Illuminazione, postazioni, stampante e macchinetta: i rami non climatici.

    Illuminazione e postazioni hanno due finestre separate dalla pausa pranzo.
    func_time e' minore della somma delle due finestre, cosi' resta margine
    stocastico: con func_time pari all'ampiezza totale l'apparecchio sarebbe
    acceso sempre, e la variabilita' non avrebbe piu' spazio.
    """
    # Illuminazione: 20 punti luce da 40 W (ramo "illuminazione" dell'albero).
    illuminazione = user.add_appliance(
        name="Illuminazione",
        number=20,
        power=40,
        num_windows=2,
        func_time=500,
        time_fraction_random_variability=0.1,
        wd_we_type=0,
    )
    illuminazione.windows(window_1=MATTINA, window_2=POMERIGGIO, random_var_w=0.15)

    # Postazioni PC + monitor: 8 da 200 W (ramo "infrastruttura ICT").
    pc = user.add_appliance(
        name="Postazione_PC",
        number=8,
        power=200,
        num_windows=2,
        func_time=450,
        time_fraction_random_variability=0.15,
        wd_we_type=0,
    )
    pc.windows(window_1=MATTINA, window_2=POMERIGGIO, random_var_w=0.1)

    # Stampante/fotocopiatrice: 2 da 300 W, uso sporadico (ramo ICT).
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

    # Macchinetta caffe: 1 da 1200 W, uso occasionale.
    caffe = user.add_appliance(
        name="Macchinetta_caffe",
        number=1,
        power=1200,
        num_windows=2,
        func_time=30,
        time_fraction_random_variability=0.3,
        occasional_use=0.8,
        wd_we_type=0,
    )
    caffe.windows(window_1=MATTINA, window_2=POMERIGGIO, random_var_w=0.2)


def _ufficio(clima: str) -> User:
    """Un ufficio in uno dei tre regimi feriali.

    Args:
        clima: 'raffrescamento', 'riscaldamento' oppure 'spento'.

    La climatizzazione e' la voce che sposta piu' energia fra un regime e
    l'altro, ed e' il difetto che pesava di piu' nella versione precedente.
    D'estate i due split da 2,5 kW restano ma non girano 8 ore: un impianto
    dimensionato sul picco cicla, e le ore di funzionamento equivalente a pieno
    carico sono molte meno. D'inverno il calore viene dal gas e sul contatore
    elettrico restano i soli ausiliari - ventilconvettori e circolatore - che
    sono un ordine di grandezza piu' piccoli. In mezza stagione non c'e' ne'
    l'uno ne' l'altro.
    """
    user = User(user_name="office", num_users=1)
    _carichi_permanenti(user)
    _apparecchi_di_lavoro(user)

    if clima == "raffrescamento":
        raffrescamento = user.add_appliance(
            name="Climatizzazione_estiva",
            number=2,
            power=2500,
            num_windows=2,
            func_time=270,
            time_fraction_random_variability=0.25,
            wd_we_type=0,
        )
        raffrescamento.windows(window_1=MATTINA, window_2=POMERIGGIO,
                               random_var_w=0.2)
    elif clima == "riscaldamento":
        ausiliari = user.add_appliance(
            name="Ausiliari_riscaldamento",
            number=2,
            power=400,
            num_windows=2,
            func_time=360,
            time_fraction_random_variability=0.2,
            wd_we_type=0,
        )
        ausiliari.windows(window_1=MATTINA, window_2=POMERIGGIO, random_var_w=0.15)
    elif clima != "spento":
        raise ValueError(f"Regime climatico non riconosciuto: '{clima}'")

    return user


def _chiuso() -> User:
    """Giorno di chiusura: restano i soli carichi permanenti."""
    user = User(user_name="office", num_users=1)
    _carichi_permanenti(user)
    return user


REGIMI = {
    "feriale_estate": lambda: _ufficio("raffrescamento"),
    "feriale_inverno": lambda: _ufficio("riscaldamento"),
    "feriale_mezza": lambda: _ufficio("spento"),
    "chiusura_agosto": _chiuso,
    "chiuso": _chiuso,
}


def _in_stagione_di_riscaldamento(giorno: dt.date) -> bool:
    """Vero fra il 15 ottobre e il 15 aprile, estremi inclusi (zona E)."""
    mese_giorno = (giorno.month, giorno.day)
    return mese_giorno >= INIZIO_RISCALDAMENTO or mese_giorno <= FINE_RISCALDAMENTO


def regime(giorno: dt.date) -> str:
    """Quale regime vale in una data.

    I fine settimana e i festivi nazionali sono chiusura; per il resto decide
    la stagione. La stagione di riscaldamento e' quella di legge per la zona
    climatica E; quella di raffrescamento e' un'ipotesi dichiarata.
    """
    if giorno.weekday() >= 5 or giorno in festivi(giorno.year):
        return "chiuso"
    if INIZIO_CHIUSURA_ESTIVA <= (giorno.month, giorno.day) <= FINE_CHIUSURA_ESTIVA:
        # Stesso contenuto di "chiuso", ma tenuto distinto: cosi' il conteggio
        # dei giorni per regime, che ramp_runner stampa a ogni generazione,
        # dice quanti giorni vengono dalla chiusura estiva e quanti dai festivi.
        return "chiusura_agosto"
    if INIZIO_RAFFRESCAMENTO <= (giorno.month, giorno.day) <= FINE_RAFFRESCAMENTO:
        return "feriale_estate"
    if _in_stagione_di_riscaldamento(giorno):
        return "feriale_inverno"
    return "feriale_mezza"
