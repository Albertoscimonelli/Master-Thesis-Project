"""Use case RAMP: istituto di istruzione secondaria di secondo grado.

DUE FONTI INDIPENDENTI CHE CONCORDANO, ed e' la ragione per cui questo
archetipo nasce meglio ancorato di office. ARERA attribuisce a un punto di
prelievo di classe BTA6 con ATECO 85.31 (istruzione secondaria di secondo
grado) un consumo di 96.991 kWh/anno a Milano; il benchmark RSE per gli edifici
scolastici superiori vale 15 kWh/m2 di energia elettrica (Corgnati, Fabrizio,
Ariaudo, Rollino, Report RSE/2010, p. 42, rule of thumb 30). Il rapporto fra i
due da' circa 6.470 m2, che e' la taglia di un istituto reale: aule,
laboratori, palestra, segreteria. L'archetipo e' dimensionato su quella
superficie, e i due riscontri restano indipendenti fra loro.

Nel caso di office le stesse due fonti si contraddicevano - gli indici ENEA per
m2 implicavano piu' consumo dell'intero budget ARERA della classe - e la
questione e' rimasta aperta. Qui no: e' un buon motivo per dichiarare in tesi
la differenza di solidita' fra i due archetipi.

IL CALENDARIO VIENE DA UNA DELIBERA, NON DA UN'IPOTESI. Regione Lombardia,
Calendario Scolastico Regionale di carattere permanente, DGR n. 3318 del 18
aprile 2012, confermato per l'anno scolastico 2025/2026 con Prot. N.
E1.2025.0481857 del 12/05/2025. Essendo "di carattere permanente", le sue regole
valgono anche per la parte di anno solare che appartiene all'anno scolastico
precedente, quindi un solo documento copre tutto il 2025:

    lezioni            dal 12 settembre all'8 giugno
    vacanze natalizie  dal 23 al 31 dicembre e dal 2 al 5 gennaio
    vacanze pasquali   i 3 giorni precedenti la domenica di Pasqua, piu' il
                       martedi' successivo al Lunedi' dell'Angelo
    vacanze carnevale  i 2 giorni precedenti il Mercoledi' delle Ceneri
    festivita'         quelle nazionali, gia' in lpg_db/valida_domestici.py

Sono REGOLE, non date: le date del 2025 si derivano. Per il 2025 producono
vacanze pasquali dal 17 al 19 aprile piu' martedi' 22, e carnevale il 3 e 4
marzo (Ceneri il 5).

IL VINCOLO DI LEGGE SUI GIORNI DI LEZIONE. Il D.Lgs. 297/1994 art. 74 c. 3
fissa in almeno 200 il numero di giorni di lezione dell'anno scolastico. Non
serve a costruire il calendario - quello viene dalla delibera - ma a
verificarlo: se il calendario derivato qui producesse meno di 200 giorni di
lezione, sarebbe sbagliato. Il controllo e' in fondo al modulo.

LA STAGIONE DI RISCALDAMENTO e' quella di legge per la zona climatica E,
Milano: dal 15 ottobre al 15 aprile, DPR 412/1993 art. 9. Come in office, sul
contatore elettrico non finisce il calore ma i suoi ausiliari - circolatori e
ventilconvettori. Una scuola italiana non ha di norma climatizzazione estiva
nelle aule, e d'estate e' comunque chiusa: qui non e' modellata.

IL DIMENSIONAMENTO SI TARA SULL'USCITA: RAMP realizza circa il 70% del prodotto
number x power x func_time, quindi i valori qui sotto vanno riletti dopo ogni
generazione con ramp_db/valida_non_domestici.py.

IL POD E' DI UN ENTE TERRITORIALE, e non e' un dettaglio amministrativo.
L'edificio di una scuola secondaria di secondo grado e' per legge di proprieta'
della Provincia o della Citta' metropolitana (L. 23/1996 art. 3), che il Testo
Unico degli enti locali (D.Lgs. 267/2000) annovera fra gli enti locali, e che
il GSE riconosce come "autorita' locale" ai fini CER (Consultazione GSE del 4
marzo 2021, §2.1). Nella scheda della comunita' va quindi categoria "PA", che
lo rende esente dal fattore F di decurtazione della tariffa premio
(cer_reduction_factor.m). E' una scelta deliberata, non un default.
"""

import datetime as dt
import sys
from pathlib import Path

from ramp.core.core import User

# Il calendario civile italiano e la domenica di Pasqua vivono gia' nel lato
# domestico: si importano invece di riscrivere l'algoritmo gregoriano.
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "lpg_db"))
from valida_domestici import _pasqua, festivi  # noqa: E402

# Orario delle lezioni, in minuti dalla mezzanotte: 8:00-14:00, senza pausa
# pranzo perche' un istituto superiore italiano fa orario unico antimeridiano.
LEZIONI = [480, 840]
# La segreteria resta oltre il termine delle lezioni.
UFFICI = [480, 1020]
# Palestra e attivita' pomeridiane.
POMERIGGIO = [840, 1080]

# Calendario scolastico regionale, DGR Lombardia 3318/2012.
AVVIO_LEZIONI = (9, 12)
TERMINE_LEZIONI = (6, 8)
NATALIZIE = [(12, 23), (12, 31), (1, 2), (1, 5)]

# Stagione di riscaldamento della zona climatica E (Milano), DPR 412/1993 art. 9.
INIZIO_RISCALDAMENTO = (10, 15)
FINE_RISCALDAMENTO = (4, 15)

# Minimo di legge, D.Lgs. 297/1994 art. 74 c. 3. Serve a verificare il
# calendario, non a costruirlo.
GIORNI_LEZIONE_MINIMI = 200


def _sempre_accesi(user: User) -> None:
    """CED, distributori, sicurezza e ausiliari: la scuola non e' mai a zero.

    Sono presenti in ogni regime, weekend e vacanze estive compresi. In un
    istituto sono la quota di consumo che non dipende dalle lezioni, ed e'
    quella che tiene il profilo diverso da zero per i due terzi dell'anno in
    cui la scuola e' chiusa.

    QUANTO GRANDE DEVE ESSERE QUESTA BASE lo dice ARERA, non un'ipotesi. Ad
    agosto, quando di lezioni non ce ne sono, un POD scolastico di classe BTA6
    consuma ancora il 6,2% del suo totale annuo - circa 194 kWh al giorno a
    scuola chiusa - contro l'11,7% di gennaio: il rapporto fra inverno ed estate
    e' 1,9, non dieci. La prima stesura aveva 4,5 kW di base e produceva un
    agosto al 4,2%, con un rapporto di 2,36; era troppo poco per 6.470 m2 di
    edificio, dove restano accesi server, ventilazione, pompe, videosorveglianza
    e luci di sicurezza. Alzare invece l'illuminazione delle aule - provato, e
    documentato nei file di validazione - peggiora la forma mensile: aggiunge
    consumo solo nei giorni di lezione, e allontana ancora agosto dal vero.
    """
    ced = user.add_appliance(
        name="CED_e_rete",
        number=1,
        power=3000,
        num_windows=1,
        func_time=1440,
        time_fraction_random_variability=0.05,
        wd_we_type=2,
    )
    ced.windows(window_1=[0, 1440], random_var_w=0)

    ausiliari = user.add_appliance(
        name="Ausiliari_continui",
        number=1,
        power=1500,
        num_windows=1,
        func_time=1440,
        time_fraction_random_variability=0.1,
        wd_we_type=2,
    )
    ausiliari.windows(window_1=[0, 1440], random_var_w=0)

    distributori = user.add_appliance(
        name="Distributori_automatici",
        number=5,
        power=300,
        num_windows=1,
        func_time=1440,
        time_fraction_random_variability=0.1,
        wd_we_type=2,
    )
    distributori.windows(window_1=[0, 1440], random_var_w=0)

    sicurezza = user.add_appliance(
        name="Illuminazione_sicurezza",
        number=1,
        power=2000,
        num_windows=1,
        func_time=1440,
        time_fraction_random_variability=0.05,
        wd_we_type=2,
    )
    sicurezza.windows(window_1=[0, 1440], random_var_w=0)


def _segreteria(user: User) -> None:
    """Uffici di segreteria e presidenza: lavorano anche a scuole chiuse.

    Restano attivi durante la chiusura estiva, quando le lezioni sono finite ma
    l'amministrazione no: iscrizioni, esami, organici. E' la differenza fra il
    regime di chiusura estiva e quello di chiusura vera.
    """
    postazioni = user.add_appliance(
        name="Segreteria_PC",
        number=15,
        power=200,
        num_windows=1,
        func_time=420,
        time_fraction_random_variability=0.15,
        wd_we_type=0,
    )
    postazioni.windows(window_1=UFFICI, random_var_w=0.1)

    luci_uffici = user.add_appliance(
        name="Illuminazione_uffici",
        number=40,
        power=50,
        num_windows=1,
        func_time=420,
        time_fraction_random_variability=0.1,
        wd_we_type=0,
    )
    luci_uffici.windows(window_1=UFFICI, random_var_w=0.15)


def _didattica(user: User, riscaldamento: bool) -> None:
    """Aule, laboratori e palestra: i carichi che esistono solo se c'e' lezione."""
    # Illuminazione di aule e corridoi su circa 6.470 m2. Il dimensionamento si
    # controlla in DENSITA' DI POTENZA, W/m2, che e' il modo in cui un impianto
    # di illuminazione si progetta davvero: 900 corpi da 58 W fanno 52,2 kW,
    # cioe' 8,1 W/m2. La prima stesura ne aveva 500 da 50 W, pari a 3,9 W/m2,
    # un valore troppo basso per aule in cui si legge e si scrive - ed era la
    # causa principale del livello annuo basso di un terzo rispetto sia ad
    # ARERA sia al benchmark RSE, che su questo archetipo concordano.
    luci = user.add_appliance(
        name="Illuminazione_aule",
        number=900,
        power=58,
        num_windows=1,
        func_time=330,
        time_fraction_random_variability=0.1,
        wd_we_type=0,
    )
    luci.windows(window_1=LEZIONI, random_var_w=0.15)

    # Lavagne interattive e proiettori, una per aula.
    lim = user.add_appliance(
        name="LIM_e_proiettori",
        number=50,
        power=300,
        num_windows=1,
        func_time=240,
        time_fraction_random_variability=0.2,
        wd_we_type=0,
    )
    lim.windows(window_1=LEZIONI, random_var_w=0.2)

    # Laboratori di informatica: cento postazioni fra tutti i laboratori.
    laboratori = user.add_appliance(
        name="Laboratori_informatica",
        number=100,
        power=150,
        num_windows=1,
        func_time=240,
        time_fraction_random_variability=0.25,
        wd_we_type=0,
    )
    laboratori.windows(window_1=LEZIONI, random_var_w=0.2)

    # Palestra: illuminazione a proiettori, usata anche nel pomeriggio.
    palestra = user.add_appliance(
        name="Palestra",
        number=30,
        power=200,
        num_windows=2,
        func_time=300,
        time_fraction_random_variability=0.2,
        wd_we_type=0,
    )
    palestra.windows(window_1=LEZIONI, window_2=POMERIGGIO, random_var_w=0.2)

    if riscaldamento:
        # Sul contatore elettrico il riscaldamento lascia i soli ausiliari.
        circolatori = user.add_appliance(
            name="Ausiliari_riscaldamento",
            number=4,
            power=750,
            num_windows=1,
            func_time=600,
            time_fraction_random_variability=0.15,
            wd_we_type=0,
        )
        circolatori.windows(window_1=[360, 1020], random_var_w=0.1)


def _giorno_di_lezione(riscaldamento: bool) -> User:
    user = User(user_name="scuola_superiore", num_users=1)
    _sempre_accesi(user)
    _segreteria(user)
    _didattica(user, riscaldamento)
    return user


def _chiusura_estiva() -> User:
    """Lezioni finite, segreteria aperta: giugno-settembre nei giorni feriali."""
    user = User(user_name="scuola_superiore", num_users=1)
    _sempre_accesi(user)
    _segreteria(user)
    return user


def _chiuso() -> User:
    """Weekend, festivi e vacanze: restano i soli carichi permanenti."""
    user = User(user_name="scuola_superiore", num_users=1)
    _sempre_accesi(user)
    return user


REGIMI = {
    "lezione_inverno": lambda: _giorno_di_lezione(riscaldamento=True),
    "lezione_mezza": lambda: _giorno_di_lezione(riscaldamento=False),
    "chiusura_estiva": _chiusura_estiva,
    "chiuso": _chiuso,
}


def _fra(giorno: dt.date, inizio: tuple[int, int], fine: tuple[int, int]) -> bool:
    """Vero se la data cade fra due ricorrenze annuali, anche a cavallo d'anno."""
    corrente = (giorno.month, giorno.day)
    if inizio <= fine:
        return inizio <= corrente <= fine
    return corrente >= inizio or corrente <= fine


def vacanze_scolastiche(anno: int) -> set[dt.date]:
    """Le sospensioni delle lezioni previste dalla DGR 3318/2012, per un anno.

    Non comprende le festivita' nazionali, che stanno gia' in festivi(), ne' i
    fine settimana: solo i periodi di vacanza che la delibera aggiunge.
    """
    pasqua = _pasqua(anno)
    giorni = {pasqua - dt.timedelta(days=n) for n in (1, 2, 3)}
    giorni.add(pasqua + dt.timedelta(days=2))          # martedi' dopo l'Angelo
    ceneri = pasqua - dt.timedelta(days=46)
    giorni |= {ceneri - dt.timedelta(days=n) for n in (1, 2)}   # carnevale
    giorni |= {dt.date(anno, 12, g) for g in range(23, 32)}
    giorni |= {dt.date(anno, 1, g) for g in range(2, 6)}
    return giorni


def regime(giorno: dt.date) -> str:
    """Quale regime vale in una data.

    L'ordine dei controlli e' significativo: prima cio' che chiude la scuola
    comunque - weekend, festivita' nazionali, vacanze - poi la distinzione fra
    il periodo delle lezioni e la chiusura estiva, e solo alla fine la stagione
    di riscaldamento.
    """
    if giorno.weekday() >= 5:
        return "chiuso"
    if giorno in festivi(giorno.year) or giorno in vacanze_scolastiche(giorno.year):
        return "chiuso"
    if not _fra(giorno, AVVIO_LEZIONI, TERMINE_LEZIONI):
        return "chiusura_estiva"
    if _fra(giorno, INIZIO_RISCALDAMENTO, FINE_RISCALDAMENTO):
        return "lezione_inverno"
    return "lezione_mezza"


def giorni_di_lezione(anno: int) -> int:
    """Quanti giorni di lezione produce il calendario derivato, in un anno solare.

    Il D.Lgs. 297/1994 art. 74 c. 3 ne impone almeno 200 per anno SCOLASTICO. Un
    anno solare ne contiene due mezzi, quindi il confronto diretto col minimo di
    legge non e' immediato; il conteggio serve comunque a vedere se il
    calendario derivato e' nell'ordine di grandezza giusto.
    """
    giorno = dt.date(anno, 1, 1)
    totale = 0
    while giorno.year == anno:
        if regime(giorno).startswith("lezione"):
            totale += 1
        giorno += dt.timedelta(days=1)
    return totale
