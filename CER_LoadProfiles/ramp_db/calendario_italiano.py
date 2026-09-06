"""Calendario e stagionalita' italiani per i profili non domestici RAMP.

PERCHE' SERVE. RAMP non ha nozione di festivita', ferie o stagioni: 'wd_we_type'
distingue solo feriale, weekend e sempre, e non sa nemmeno separare il sabato
dalla domenica (get_day_type in ramp/core/utils.py). Un profilo generato senza
altro consuma uguale il 15 agosto e il 15 marzo, e a Natale come di martedi'.
La riga zero lo misura: l'officina consuma l'8,5% dell'anno ad agosto contro il
3,5% della sua classe ATECO, e il 13,7% di domenica, cioe' un settimo esatto.

LA LEVA E' UNA SOLA. Il parametro 'power' di Appliance accetta un DataFrame di
366 valori, uno per giorno, e RAMP lo indicizza per giorno del profilo
(ramp/core/core.py, generate_single_load_profile). Un vettore giornaliero da'
quindi in un colpo solo domeniche, festivita', ferie e stagionalita' termica.

ATTENZIONE, TRAPPOLA VERIFICATA: 'power' viene IGNORATO se l'appliance ha
fixed_cycle > 0. Misurato su un caso di prova - stessa maschera con agosto a
zero: senza duty cycle agosto consuma 0,0 kWh, con duty cycle ne consuma 241,8.
Il duty cycle usa i propri p_11/p_12 e non guarda 'power'. Le appliance con
ciclo vanno quindi convertite a potenza media equivalente PRIMA di ricevere una
maschera, altrimenti la maschera non ha alcun effetto e nulla lo segnala.

FONTI

  Festivita' nazionali: si riusa festivi() del validatore domestico, che
  implementa le dodici ricorrenze civili piu' il Lunedi' dell'Angelo. Una
  seconda copia divergerebbe.

  Calendario scolastico: Regione Lombardia, Calendario Scolastico Regionale di
  carattere permanente, DGR n. 3318 del 18 aprile 2012, confermato per il
  2025/2026 con nota del Direttore Generale Istruzione, Formazione e Lavoro
  Prot. N. E1.2025.0481857 del 12 maggio 2025. Lezioni dal 12 settembre all'8
  giugno; vacanze natalizie dal 23 al 31 dicembre e dal 2 al 5 gennaio;
  vacanze pasquali i tre giorni precedenti la domenica di Pasqua piu' il
  martedi' successivo al Lunedi' dell'Angelo; vacanze di carnevale i due giorni
  antecedenti l'avvio della Quaresima.

  Chiusura estiva industriale: quindici giorni consecutivi centrati su
  Ferragosto. E' la consuetudine italiana delle ferie collettive, ed e'
  un'ASSUNZIONE DICHIARATA su indicazione, non un dato misurato: la si tiene
  esplicita e modificabile con il parametro 'giorni' invece di nasconderla
  dentro un numero.

REGOLA DI NON CIRCOLARITA'. Questi calendari si derivano dalle fonti sopra e
MAI cercando la chiusura che minimizza la distanza dalla forma mensile ARERA.
ARERA e' il giudice: tararci sopra la chiusura di agosto significherebbe
validare il modello contro se stesso. Se dopo la calibrazione la forma non
combacia, si corregge un parametro con una fonte diversa, non si sposta la
chiusura finche' torna.

Uso:
    python calendario_italiano.py --anno 2025
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import sys
from pathlib import Path

import pandas as pd

QUI = Path(__file__).resolve().parent

# ANNO DELLA SIMULAZIONE. Deve coincidere con simulation.year in
# simulation_config.yaml: gli use case costruiscono le maschere per QUESTO
# anno, e un disallineamento sposterebbe festivita' e ferie di qualche giorno
# senza che nulla lo segnali. verifica_anno() lo controlla.
ANNO = 2025

# Santo patrono di Milano: Sant'Ambrogio, 7 dicembre. Il calendario regionale
# lo elenca fra le chiusure scolastiche ("Festa del Santo Patrono").
PATRONO_MILANO = (12, 7)

# Sorgente climatica: lo stesso TMY che alimenta il profilo di temperatura di
# LoadProfileGenerator e il calcolo fotovoltaico di optimizer_PV.m. Usarne una
# diversa farebbe divergere i due lati del modello sullo stesso anno.
TMY = QUI.parent / "lpg_db" / "dati" / "tmy_45.464_9.190_2005_2023.csv"


def _abilita_lpg_db() -> None:
    percorso = str((QUI.parent / "lpg_db").resolve())
    if percorso not in sys.path:
        sys.path.insert(0, percorso)


_abilita_lpg_db()

from valida_domestici import festivi  # noqa: E402


def giorni_anno(anno: int = ANNO) -> pd.DatetimeIndex:
    """I 366 giorni che RAMP si aspetta.

    RAMP costruisce l'utente prima di conoscere le date e assume 366 giorni
    (User.num_days), quindi un vettore di 365 valori viene rifiutato con
    'Wrong number of power values'. Per gli anni non bisestili il 366-esimo
    valore non viene mai usato: si ripete l'ultimo giorno.
    """
    reali = pd.date_range(f"{anno}-01-01", f"{anno}-12-31", freq="D")
    if len(reali) == 366:
        return reali
    return reali.append(pd.DatetimeIndex([reali[-1]]))


def pasqua(anno: int) -> dt.date:
    """Domenica di Pasqua, algoritmo di Meeus/Butcher."""
    a, b, c = anno % 19, anno // 100, anno % 100
    d, e = b // 4, b % 4
    f, g = (b + 8) // 25, (b - (b + 8) // 25 + 1) // 3
    h = (19 * a + b - d - g + 15) % 30
    i, k = c // 4, c % 4
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) // 451
    mese = (h + l - 7 * m + 114) // 31
    giorno = ((h + l - 7 * m + 114) % 31) + 1
    return dt.date(anno, mese, giorno)


def chiusura_agosto(anno: int = ANNO, giorni: int = 15) -> set[dt.date]:
    """Ferie collettive estive: N giorni consecutivi centrati su Ferragosto.

    Con il default di quindici giorni la chiusura va dall'8 al 22 agosto.
    E' la consuetudine industriale italiana, dichiarata come assunzione: non
    esiste un dato che la misuri per la singola impresa, e va tenuta visibile
    perche' e' uno dei parametri che spostano di piu' la forma mensile.
    """
    centro = dt.date(anno, 8, 15)
    prima = (giorni - 1) // 2
    return {centro + dt.timedelta(days=k)
            for k in range(-prima, giorni - prima)}


def vacanze_scolastiche(anno: int = ANNO) -> set[dt.date]:
    """Giorni in cui le scuole lombarde sono chiuse, oltre a domeniche e festivi.

    Fonte: Regione Lombardia, calendario regionale permanente (DGR 3318/2012),
    confermato per il 2025/2026 dalla nota Prot. E1.2025.0481857 del 12 maggio
    2025.

    Un anno solare attraversa DUE anni scolastici: da gennaio a giugno vale il
    calendario iniziato l'anno prima, da settembre a dicembre quello che inizia
    a settembre. Le regole sono pero' permanenti, quindi si applicano le stesse
    date a entrambi i tronconi.

    Nota sul carnevale: il calendario prevede "i 2 giorni antecedenti l'avvio
    del periodo quaresimale". Milano segue il rito ambrosiano, in cui la
    Quaresima comincia la domenica DOPO il Mercoledi' delle Ceneri: i due
    giorni sono quindi il venerdi' e il sabato successivi alle Ceneri, non
    quelli precedenti come nel rito romano.
    """
    chiusi: set[dt.date] = set()

    # Vacanze estive: dal giorno dopo la fine delle lezioni (8 giugno) fino al
    # giorno prima dell'inizio (12 settembre).
    fine = dt.date(anno, 6, 8)
    inizio = dt.date(anno, 9, 12)
    giorno = fine + dt.timedelta(days=1)
    while giorno < inizio:
        chiusi.add(giorno)
        giorno += dt.timedelta(days=1)

    # Vacanze natalizie: 23-31 dicembre e 2-5 gennaio.
    chiusi |= {dt.date(anno, 12, g) for g in range(23, 32)}
    chiusi |= {dt.date(anno, 1, g) for g in range(2, 6)}

    # Vacanze pasquali: i tre giorni precedenti la domenica di Pasqua e il
    # martedi' successivo al Lunedi' dell'Angelo.
    p = pasqua(anno)
    chiusi |= {p - dt.timedelta(days=k) for k in (1, 2, 3)}
    chiusi.add(p + dt.timedelta(days=2))

    # Carnevale ambrosiano: venerdi' e sabato dopo il Mercoledi' delle Ceneri.
    ceneri = p - dt.timedelta(days=46)
    chiusi |= {ceneri + dt.timedelta(days=2), ceneri + dt.timedelta(days=3)}

    # Santo patrono.
    chiusi.add(dt.date(anno, *PATRONO_MILANO))

    return {g for g in chiusi if g.year == anno}


def maschera(anno: int = ANNO, *, domenica: bool = True, sabato: bool = False,
             festivi_nazionali: bool = True,
             chiusure: set[dt.date] | None = None,
             potenza: float = 1.0) -> pd.DataFrame:
    """Vettore giornaliero di potenza da passare ad Appliance(power=...).

    Args:
        domenica: se True la domenica la potenza e' zero.
        sabato: se True anche il sabato e' zero.
        festivi_nazionali: se True le festivita' civili sono a zero.
        chiusure: date aggiuntive a zero (ferie, calendario scolastico).
        potenza: valore nei giorni di apertura, in Watt.

    Returns:
        DataFrame di 366 righe a una colonna, come RAMP pretende: un ndarray o
        una Series vengono rifiutati con 'Wrong data type for power'.
    """
    giorni = giorni_anno(anno)
    rossi = festivi(anno) if festivi_nazionali else set()
    extra = chiusures if (chiusures := chiusure) else set()

    valori = []
    for g in giorni:
        chiuso = (
            (domenica and g.weekday() == 6)
            or (sabato and g.weekday() == 5)
            or (g.date() in rossi)
            or (g.date() in extra)
        )
        valori.append(0.0 if chiuso else float(potenza))
    return pd.DataFrame({"power": valori})


def temperature_giornaliere(anno: int = ANNO) -> pd.Series:
    """Temperatura media giornaliera di Milano dal TMY PVGIS.

    Stessa sorgente e stesso calcolo del profilo di temperatura installato in
    LoadProfileGenerator da build_italian_db.py: cosi' i due lati del modello
    non possono descrivere due climi diversi nello stesso anno.
    """
    if not TMY.exists():
        sys.exit(f"File TMY non trovato: {TMY}")

    # Stessa lettura di build_italian_db._sql_temperatura_milano(): separatore
    # ';', colonna time(UTC) nel formato AAAAMMGG:hhmm, righe di metadati che
    # PVGIS scrive in coda e che si riconoscono dalla lunghezza del campo.
    # La logica e' replicata invece che condivisa per non toccare un modulo
    # gia' validato: se una delle due cambia, va cambiata anche l'altra, e il
    # controllo e' che le medie giornaliere coincidano.
    somme: dict[str, float] = {}
    conteggi: dict[str, int] = {}
    with open(TMY, newline="", encoding="utf-8-sig") as f:
        for riga in csv.DictReader(f, delimiter=";"):
            istante = (riga.get("time(UTC)") or "").strip()
            if len(istante) != 13 or ":" not in istante:
                continue
            giorno = istante[4:8]                      # MMGG
            somme[giorno] = somme.get(giorno, 0.0) + float(riga["T2m"])
            conteggi[giorno] = conteggi.get(giorno, 0) + 1

    if not somme:
        sys.exit(f"Nessuna riga oraria valida in {TMY.name}: tracciato PVGIS "
                 "diverso da quello atteso.")

    medie = {g: somme[g] / conteggi[g] for g in somme}
    giorni = giorni_anno(anno)
    valori = []
    for g in giorni:
        chiave = f"{g.month:02d}{g.day:02d}"
        # Il TMY non ha il 29 febbraio: negli anni bisestili si ripete il 28.
        valori.append(medie.get(chiave, medie.get("0228", 0.0)))
    return pd.Series(valori, index=giorni)


def profilo_raffrescamento(anno: int = ANNO, base: float = 21.0,
                           potenza: float = 1.0,
                           maschera_giorni: pd.DataFrame | None = None) -> pd.DataFrame:
    """Potenza giornaliera del condizionamento, proporzionale ai gradi giorno.

    Gradi giorno di raffrescamento: massimo fra zero e (temperatura media del
    giorno meno la temperatura base). La potenza del giorno piu' caldo vale
    'potenza', gli altri in proporzione: e' un proxy ad anello aperto, senza
    inerzia dell'edificio, ed e' il limite da dichiarare - RAMP non ha un
    modello termico, a differenza di LoadProfileGenerator.

    Args:
        base: temperatura oltre la quale si raffresca. 21 C e' la convenzione
            italiana per i gradi giorno di raffrescamento.
        maschera_giorni: se data, i giorni chiusi restano a zero anche se caldi.
    """
    t = temperature_giornaliere(anno)
    gradi = (t - base).clip(lower=0)
    if gradi.max() == 0:
        sys.exit("Nessun grado giorno di raffrescamento: temperatura base "
                 f"{base} C troppo alta per questo TMY.")
    valori = (gradi / gradi.max() * potenza).values
    if maschera_giorni is not None:
        valori = valori * (maschera_giorni["power"].values > 0)
    return pd.DataFrame({"power": valori})


def verifica_anno(anno_config: int) -> None:
    """Ferma tutto se la configurazione simula un anno diverso da ANNO."""
    if anno_config != ANNO:
        sys.exit(
            f"simulation.year vale {anno_config} ma calendario_italiano.ANNO "
            f"vale {ANNO}. Le maschere di calendario sarebbero costruite per "
            "l'anno sbagliato e festivita' e ferie cadrebbero su giorni "
            "diversi. Allineare i due valori."
        )


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--anno", type=int, default=ANNO)
    parser.add_argument("--giorni-agosto", type=int, default=15)
    args = parser.parse_args()

    a = args.anno
    print(f"\nCALENDARIO {a}\n")
    print(f"  Pasqua: {pasqua(a)}")
    print(f"  festivita' nazionali: {len(festivi(a))}")

    ag = sorted(chiusura_agosto(a, args.giorni_agosto))
    print(f"\n  chiusura industriale ({args.giorni_agosto} giorni): "
          f"dal {ag[0]} al {ag[-1]}")

    sc = vacanze_scolastiche(a)
    print(f"\n  giorni di chiusura scolastica (oltre a domeniche e festivi): "
          f"{len(sc)}")
    for etichetta, mesi in (("estive", (6, 7, 8, 9)), ("natalizie", (12, 1)),
                            ("pasquali/carnevale", (3, 4))):
        g = sorted(x for x in sc if x.month in mesi)
        if g:
            print(f"    {etichetta:20} {len(g):3d} giorni, "
                  f"dal {g[0]} al {g[-1]}")

    print("\n  MASCHERE (giorni con potenza > 0 su 366)")
    for nome, m in (
        ("ufficio (chiuso dom+festivi)", maschera(a)),
        ("officina (dom+festivi+ferie)", maschera(a, chiusure=chiusura_agosto(a, args.giorni_agosto))),
        ("negozio (aperto sempre)", maschera(a, domenica=False, festivi_nazionali=False)),
        ("scuola", maschera(a, chiusure=vacanze_scolastiche(a))),
    ):
        aperti = int((m["power"] > 0).sum())
        print(f"    {nome:32} {aperti:3d} giorni aperti")

    t = temperature_giornaliere(a)
    r = profilo_raffrescamento(a)
    print(f"\n  CLIMA: temperatura media {t.mean():.1f} C, "
          f"massima giornaliera {t.max():.1f} C")
    quota_estate = float(r["power"][151:243].sum() / r["power"].sum())
    print(f"    il profilo di raffrescamento concentra il "
          f"{quota_estate * 100:.0f}% del suo totale fra giugno e agosto")


if __name__ == "__main__":
    main()
