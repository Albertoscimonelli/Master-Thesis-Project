"""Costruisce profilegenerator.IT.db3 dal catalogo LPG originale.

Il database italiano e' un ARTEFATTO DERIVATO: non va versionato.
Si versiona QUESTO script, che lo ricostruisce da zero a ogni esecuzione.

    cd CER_LoadProfiles/lpg_db
    ../../venv/Scripts/python build_italian_db.py

Perche' cosi' e non con il .db3 sotto git:
  - lo script pesa qualche KB invece di 53 MB per revisione
  - ogni modifica e' una riga leggibile in diff, non un blob binario
  - sopravvive a 'pip install --force-reinstall': basta rilanciarlo
  - il file MIGRAZIONI e' la documentazione di cosa e' stato cambiato e perche'
  - permette il confronto A/B: originale tedesco contro build italiana, per
    quantificare l'effetto di ogni singola correzione

Per aggiungere una modifica: appendi una voce a MIGRAZIONI e rilancia.
Non modificare mai il .db3 a mano: la prossima build cancellerebbe tutto.
"""

from __future__ import annotations

import hashlib
import json
import shutil
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

QUI = Path(__file__).resolve().parent
DESTINAZIONE = QUI / "profilegenerator.IT.db3"
MANIFESTO = QUI / "build_manifest.json"

# ID delle localita geografiche nel catalogo LPG.
MILANO = 19
PALERMO = 20
ROMA = 21


def _finestra(voce: int, inizio: str, fine: str, rand: int | None = None) -> str:
    """SQL per spostare la finestra oraria di UNA voce di time limit.

    Si agisce sempre per ID di voce, mai per TimeLimitID: diversi time limit
    hanno voci gerarchiche legate da ParentEntryID con logica AND/OR, e un
    UPDATE di gruppo la romperebbe.

    Args:
        voce: ID in tblTimeLimitEntries.
        inizio: ora di inizio, formato "HH:MM".
        fine: ora di fine, formato "HH:MM".
        rand: se indicato, aggiorna anche RandomizeTimeAmount (in minuti).
            Va ridotto quando si stringe una finestra, altrimenti l'attivita'
            continua a poter cadere fuori dall'intervallo voluto.
    """
    campi = [
        f"StartTime = '1900-01-01 {inizio}:00'",
        f"EndTime = '1900-01-01 {fine}:00'",
    ]
    if rand is not None:
        campi.append(f"RandomizeTimeAmount = {rand}")
    return f"UPDATE tblTimeLimitEntries SET {', '.join(campi)} WHERE ID = {voce};"


# ---------------------------------------------------------------------------
# MIGRAZIONI
#
# Ogni voce e' (identificativo, descrizione, lista di istruzioni SQL).
# Vengono applicate in ordine su una copia fresca dell'originale.
# L'identificativo non va mai riusato ne' cambiato: e' il riferimento
# stabile a cui puntare nella tesi o nella documentazione del modello.
# ---------------------------------------------------------------------------

MIGRAZIONI: list[tuple[str, str, list[str]]] = [
    (
        "H01",
        "Rimuove dal calendario di Milano le festivita non italiane: "
        "Venerdi Santo e Lunedi di Pentecoste (festivi in Germania ma non "
        "in Italia) e le tre voci greche rimaste agganciate per errore.",
        [
            f"DELETE FROM tblGeographicLocHolidays "
            f"WHERE GeographicLocationID = {MILANO} "
            f"AND HolidayID IN (4, 8, 20, 21, 22);"
        ],
    ),
    (
        "H02",
        "Rimuove Sa Die de Sa Sardigna (28 aprile): festivita regionale "
        "sarda, non osservata a Milano.",
        [
            f"DELETE FROM tblGeographicLocHolidays "
            f"WHERE GeographicLocationID = {MILANO} AND HolidayID = 23;"
        ],
    ),
    (
        "H03",
        "Attiva su Milano le tre festivita italiane gia' presenti nel "
        "catalogo ma non agganciate: 2 giugno (25), Immacolata (26), "
        "Ferragosto (27). Calendario finale: 12 voci.",
        [
            f"INSERT INTO tblGeographicLocHolidays "
            f"(GeographicLocationID, HolidayID, Guid) VALUES "
            f"({MILANO}, 25, '1f4a2c60-9b31-4d7e-8a55-2c0e7b19d401'), "
            f"({MILANO}, 26, '2a7b3d71-8c42-4e6f-9b66-3d1f8c2ae512'), "
            f"({MILANO}, 27, '3b8c4e82-7d53-4f5a-ac77-4e2a9d3bf623');"
        ],
    ),
    # -----------------------------------------------------------------------
    # ORARI
    #
    # I Time Limit sono oggetti CONDIVISI: modificarne uno agisce su tutte le
    # 66 famiglie del catalogo insieme. E' questo che rende inutile lo scambio
    # dei tratti famiglia per famiglia.
    #
    # Prima di scrivere una migrazione su tblTimeLimitEntries, ISPEZIONA:
    #
    #   SELECT ID, StartTime, EndTime, RepeaterType, RandomizeTimeAmount,
    #          ParentEntryID, AnyAll
    #     FROM tblTimeLimitEntries WHERE TimeLimitID = <id>;
    #
    # Alcuni time limit hanno piu' voci legate da ParentEntryID con logica
    # AND/OR (campo AnyAll): un UPDATE cieco sull'intero TimeLimitID la
    # romperebbe. Sotto, le migrazioni che agiscono per ID di voce lo fanno
    # perche' il time limit e' gerarchico; le voci 00:00-20:00 sono
    # contenitori e non vanno toccate.
    # -----------------------------------------------------------------------
    (
        "L01",
        "Lavoro: sposta l'orario di ingresso dalle 08:00-10:00 alle "
        "09:00-11:00. Il time limit 12 e' condiviso da 8 tratti di lavoro "
        "(inclusi i due Work - Teacher School) usati da circa 40 famiglie. "
        "I time limit 41, 92 e 93 sono gia' su orario italiano e non "
        "vengono toccati.",
        [
            _finestra(86, "09:00", "11:00"),   # TL 12  08:00-10:00
            _finestra(90, "07:00", "09:00"),   # TL 14  06:00-08:00
            _finestra(78, "08:00", "21:00"),   # TL  7  07:00-21:00
        ],
    ),
    (
        "L02",
        "Cena: sposta la cottura e il pasto serale di circa un'ora, dalle "
        "18:00-21:00 tedesche alle 19:00-21:30 italiane. Il time limit 121 "
        "e' quello effettivo, imposto dal tratto Cooking Dinner for the "
        "Family via tblHHTAffordances.TimeLimitID.",
        [
            _finestra(353, "19:00", "21:30"),  # TL 121 18:00-21:00
            _finestra(147, "19:00", "20:30"),  # TL  40 16:30-17:30
            _finestra(227, "18:30", "22:00"),  # TL  66 16:00-21:00
            _finestra(271, "18:30", "22:00"),  # TL  82 16:30-21:00
            _finestra(291, "19:00", "21:00"),  # TL  88 17:00-19:00
            # TL 57 (grigliate, T>15C) e' gerarchico: tutte e tre le voci
            # portano la stessa finestra 17:00-21:00.
            _finestra(180, "19:00", "23:00"),
            _finestra(221, "19:00", "23:00"),
            _finestra(222, "19:00", "23:00"),
        ],
    ),
    (
        "L03",
        "Pranzo: 12:30-14:30 nei feriali e 12:30-15:00 nel weekend. La "
        "randomizzazione scende da 60 a 45 minuti sulle finestre 119/120/122: "
        "lasciandola a 60 il pranzo continuerebbe a cadere alle 11:30 "
        "nonostante lo spostamento.",
        [
            _finestra(292, "12:30", "15:00"),  # TL  89 weekend 11:00-13:00
            _finestra(294, "12:30", "14:30"),  # TL  91 11:00-14:00
            _finestra(351, "12:30", "14:30", rand=45),  # TL 119
            _finestra(352, "12:30", "15:00", rand=45),  # TL 120 domenica
            _finestra(354, "12:30", "15:00", rand=45),  # TL 122 weekend
        ],
    ),
    (
        "L04",
        "Scuola a tempo normale. I tratti Primary school 1/2/3 durano 6 ore "
        "con partenza 07:00-09:00 e finiscono quindi fra le 13 e le 14: sono "
        "gia' italiani e non vengono toccati. Si sposta il pomeriggio libero "
        "dalle 12:00 (scuola tedesca che finisce a mezzogiorno) alle 13:30, "
        "e le sveglie scolastiche di circa un'ora mantenendone la diversita' "
        "fra famiglie.",
        [
            # TL 44 - pomeriggio libero, tre voci con la stessa finestra
            _finestra(153, "13:30", "21:00"),
            _finestra(154, "13:30", "21:00"),
            _finestra(155, "13:30", "21:00"),
            # Sveglie: +1h, con la piu' tardiva limitata per non collidere
            # con l'inizio delle lezioni alle 8:00.
            _finestra(366, "06:30", "07:00"),  # TL 131 05:30-06:00
            _finestra(367, "07:00", "07:30"),  # TL 131 variante vacanze
            _finestra(328, "07:00", "07:30"),  # TL 113 06:00-06:30
            _finestra(329, "07:00", "07:30"),
            _finestra(330, "07:00", "07:30"),
            _finestra(332, "07:15", "07:45"),  # TL 114 06:30-07:00
            _finestra(333, "07:15", "07:45"),
            # TL 72 - compiti: fine alle 21:00 invece che alle 22:00
            _finestra(245, "15:00", "21:00"),
        ],
    ),
    (
        "L05",
        "Bambini a letto piu' tardi: dalle 19:30-20:30 tedesche alle 21:00 "
        "italiane. Il sonno degli adulti (time limit 19, 22:00-02:00) e' "
        "gia' compatibile e non viene toccato.",
        [
            _finestra(269, "21:00", "23:59"),  # TL 80 19:30-23:59
            _finestra(285, "21:00", "23:30"),  # TL 85 20:30-23:30
            # TL 87 - "dopo il buio", gerarchico
            _finestra(288, "21:00", "23:00"),
            _finestra(289, "21:00", "23:59"),
            _finestra(290, "21:00", "23:00"),
        ],
    ),
    (
        "L06",
        "Colazione: inizio alle 07:00 invece che alle 06:00. Non si tocca il "
        "tratto Breakfast 1h: la durata e' una questione diversa dall'orario "
        "e accorciarla ridurrebbe il consumo per assunzione, non per dato.",
        [
            # TL 5 - feriale + weekend (la voce 76 e' la radice, AnyAll=0/OR)
            _finestra(76, "07:00", "10:00"),
            _finestra(87, "07:00", "10:00"),
            _finestra(88, "07:30", "14:00"),  # weekend, fino alle 14
            # TL 83 - colazione che interrompe, giorni di scuola
            _finestra(272, "07:00", "10:00"),
            _finestra(273, "07:15", "08:15"),
            _finestra(275, "07:00", "10:00"),
            _finestra(276, "07:00", "10:00"),
            # TL 84 - giorni non scolastici
            _finestra(277, "07:00", "10:00"),
            _finestra(278, "07:30", "10:00"),
            _finestra(279, "07:00", "10:00"),
            _finestra(282, "07:00", "10:00"),
            _finestra(283, "07:00", "10:00"),
            _finestra(284, "07:00", "10:00"),
        ],
    ),
    (
        "V01",
        "Vacanze italiane su tutte le 66 famiglie. Oggi 18 famiglie su 66 "
        "vanno in vacanza ad aprile e solo 10 in agosto: l'opposto della "
        "realta' italiana. Lavoratori e famiglie ad agosto; pensionati e non "
        "occupati alternati fra giugno e settembre, per mantenere diversita' "
        "di occupazione fra i membri della CER; studenti su agosto-settembre. "
        "CHR62 (casa vacanza, VacationID 3484) resta invariata.",
        [
            # 1. tutti ad agosto, tranne la casa vacanza
            "UPDATE tblModularHouseholds SET VacationID = 18 "
            "WHERE VacationID <> 3484;",
            # 2. pensionati e non occupati: giugno / settembre alternati
            "UPDATE tblModularHouseholds "
            "SET VacationID = CASE WHEN ID % 2 = 0 THEN 7 ELSE 10 END "
            "WHERE VacationID <> 3484 AND ("
            "  Name LIKE '%Retired%' OR Name LIKE '%over 65%' "
            "  OR Name LIKE '%no work%' OR Name LIKE '%without work%' "
            "  OR Name LIKE '%Jobless%' OR Name LIKE '%unemploy%');",
            # 3. studenti: periodo lungo agosto-settembre
            "UPDATE tblModularHouseholds SET VacationID = 14 "
            "WHERE VacationID <> 3484 AND ("
            "  Name LIKE '%Student%' OR Name LIKE '%Philosophy%' "
            "  OR Name LIKE '%Flatshar%');",
        ],
    ),
]


def trova_originale() -> Path:
    """Individua il profilegenerator.db3 originale dentro il pacchetto pylpg."""
    try:
        from pylpg import lpg_execution
    except ImportError:
        sys.exit(
            "pylpg non importabile. Lancia lo script con il Python del venv:\n"
            "    ../../venv/Scripts/python build_italian_db.py"
        )

    sorgente = Path(lpg_execution.__file__).parent / "C1" / "profilegenerator.db3"
    if not sorgente.exists():
        sys.exit(
            f"Originale non trovato in {sorgente}.\n"
            "pyLPG scarica i binari alla prima esecuzione: lancia almeno una "
            "generazione di profili prima di ricostruire il database."
        )
    return sorgente


def impronta(percorso: Path) -> str:
    """SHA-256 di un file, letto a blocchi per non caricarlo tutto in memoria."""
    h = hashlib.sha256()
    with open(percorso, "rb") as f:
        for blocco in iter(lambda: f.read(1 << 20), b""):
            h.update(blocco)
    return h.hexdigest()


def calendario_milano(conn: sqlite3.Connection, anno: int = 2025) -> list[tuple]:
    """Festivita attive su Milano, con la data effettiva nell'anno indicato."""
    righe = conn.execute(
        """
        SELECT ho.ID, ho.Name,
               (SELECT MIN(hd.DateAndTime) FROM tblHolidayDates hd
                 WHERE hd.HolidayID = ho.ID AND hd.DateAndTime LIKE ?)
          FROM tblGeographicLocHolidays glh
          JOIN tblHolidays ho ON ho.ID = glh.HolidayID
         WHERE glh.GeographicLocationID = ?
        """,
        (f"{anno}%", MILANO),
    ).fetchall()
    return sorted(righe, key=lambda r: (r[2] or "9999"))


def build() -> None:
    sorgente = trova_originale()
    impronta_sorgente = impronta(sorgente)

    print(f"Originale : {sorgente}")
    print(f"            sha256 {impronta_sorgente[:16]}...")
    print(f"Copia in  : {DESTINAZIONE}")
    print()

    shutil.copy2(sorgente, DESTINAZIONE)

    applicate = []
    conn = sqlite3.connect(DESTINAZIONE)
    try:
        for identificativo, descrizione, istruzioni in MIGRAZIONI:
            righe = 0
            for sql in istruzioni:
                righe += conn.execute(sql).rowcount
            conn.commit()
            applicate.append(
                {
                    "id": identificativo,
                    "descrizione": descrizione,
                    "righe_modificate": righe,
                }
            )
            print(f"  [{identificativo}] {righe:4d} righe  {descrizione[:58]}...")

        conn.execute("VACUUM")
        conn.commit()

        stato = conn.execute("PRAGMA integrity_check").fetchone()[0]
        if stato != "ok":
            sys.exit(f"\nIntegrita del database compromessa: {stato}")

        print(f"\nintegrity_check: {stato}")
        print("\nCalendario risultante per Milano (2025):")
        for hid, nome, data in calendario_milano(conn):
            giorno = (data or "")[:10] or "(nessuna data)"
            print(f"  {giorno}  id={hid:3d}  {nome}")
    finally:
        conn.close()

    # L'originale non deve essere stato toccato in nessun caso.
    if impronta(sorgente) != impronta_sorgente:
        sys.exit("\nERRORE GRAVE: il database originale risulta modificato.")

    MANIFESTO.write_text(
        json.dumps(
            {
                "costruito_il": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                "sorgente": str(sorgente),
                "sha256_sorgente": impronta_sorgente,
                "sha256_risultato": impronta(DESTINAZIONE),
                "migrazioni": applicate,
            },
            indent=2,
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )

    print(f"\nOriginale verificato intatto.")
    print(f"Manifesto scritto in {MANIFESTO.name}")


if __name__ == "__main__":
    build()
