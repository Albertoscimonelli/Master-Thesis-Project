"""Collaudo dello strato dei regimi di calendario di ramp_runner.

Due domande, e la prima vale piu' della seconda.

NON REGRESSIONE. Lo strato dei regimi e' stato aggiunto a un generatore che
produceva gia' risultati usati in tesi. Un archetipo che NON dichiara regimi
deve percio' uscire identico bit per bit a come usciva prima: se cambia anche un
solo minuto, la modifica ha toccato il percorso vecchio e va rifatta. Le
impronte qui sotto sono state misurate PRIMA della modifica, con
config/simulation_config.yaml, e vanno aggiornate SOLO quando si cambia
deliberatamente il modello di un archetipo - mai per far passare il test.

CORRETTEZZA DEL PERCORSO NUOVO. Il codice a regimi genera un anno pieno per
ciascun regime e poi sceglie, giorno per giorno, quello dichiarato dallo use
case. Cio' che puo' rompersi e' la contabilita' degli indici: prendere il giorno
sbagliato, o prendere il giorno giusto dal regime sbagliato. Si verifica
confrontando il profilo composto con i profili dei singoli regimi, giorno per
giorno. Il test usa due regimi con la STESSA lista di apparecchi: differiscono
solo per il seed, che dipende dal nome del regime, e la verifica che i due
profili siano davvero diversi impedisce al confronto di diventare vacuo.

Uso:
    ../../venv/Scripts/python.exe collaudo_regimi.py

Esce con codice 1 se qualcosa non torna, cosi' e' utilizzabile come controllo.
"""

from __future__ import annotations

import hashlib
import sys
import types
from pathlib import Path

import numpy as np
import pandas as pd
import yaml

BASE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BASE))
sys.path.insert(0, str(BASE / "ramp_inputs" / "use_cases"))

import ramp_runner  # noqa: E402

# Impronte degli archetipi senza regimi, misurate prima dell'introduzione dello
# strato. Chiave: nome di colonna -> (sha256 dei minuti in Watt, kWh/anno).
BASELINE = {
    "office_1": (
        "d93218f82ae6c6e597f6ae4dc31ee7fe1c7a1af5bc2405fd30d41f8207fe09e6",
        10956.520955),
    "small_industry_1": (
        "e52920ac8a5644210f00bf1e87855e1e85800007a9b558eba8f2b957f3d2fae9",
        61692.091277),
    "retail_1": (
        "b0837ae92b3b1123bec2c8f578cf1cf214753f7785d49fff82b4ae0b30183dcc",
        13630.753483),
}

INIZIO, FINE = "2025-01-01", "2025-12-31"
RIGHE_ATTESE = 525_600


def non_regressione() -> bool:
    """Gli use case senza regimi devono uscire identici a prima."""
    print("=" * 72)
    print("1. NON REGRESSIONE - gli use case senza regimi restano identici")
    print("=" * 72)
    config = yaml.safe_load(
        (BASE / "config" / "simulation_config.yaml").read_text(encoding="utf-8"))
    df = ramp_runner.run_ramp(config, BASE)

    ok = True
    for colonna in df.columns:
        valori = df[colonna].to_numpy()
        sha = hashlib.sha256(valori.tobytes()).hexdigest()
        if colonna not in BASELINE:
            print(f"  {colonna:20} NON IN BASELINE - impronta {sha[:16]}...")
            continue
        atteso_sha, atteso_kwh = BASELINE[colonna]
        uguale = sha == atteso_sha
        ok &= uguale
        print(f"  {colonna:20} {'IDENTICO' if uguale else 'DIVERSO !!':11}"
              f"{sha[:16]}...  {valori.sum() / 60 / 1000:.6f} kWh "
              f"(atteso {atteso_kwh})")

    indice_ok = (len(df) == RIGHE_ATTESE
                 and str(df.index[-1]) == "2025-12-31 23:59:00")
    ok &= indice_ok
    print(f"  indice {df.index[0]} -> {df.index[-1]}, {len(df)} righe "
          f"({'ok' if indice_ok else 'DIVERSO !!'})")
    return ok


def percorso_a_regimi() -> bool:
    """La selezione giorno per giorno prende il giorno giusto dal regime giusto."""
    print()
    print("=" * 72)
    print("2. PERCORSO A REGIMI - un anno per regime, selezione giorno per giorno")
    print("=" * 72)
    import office

    finto = types.ModuleType("finto")
    finto.REGIMI = {"feriale": office.create_user, "chiuso": office.create_user}
    finto.regime = lambda giorno: "chiuso" if giorno.weekday() >= 5 else "feriale"

    composto = ramp_runner._genera_a_regimi(
        finto, "finto", 0, "finto_1", INIZIO, FINE)
    feriale = ramp_runner._genera_un_anno(
        office.create_user, "finto_feriale", 0, "x", INIZIO, FINE)
    chiuso = ramp_runner._genera_un_anno(
        office.create_user, "finto_chiuso", 0, "x", INIZIO, FINE)

    minuti = ramp_runner.MINUTI_AL_GIORNO
    lunghezza_ok = len(composto) == RIGHE_ATTESE
    distinti = not np.array_equal(feriale, chiuso)
    print(f"  lunghezza {len(composto)} ({'ok' if lunghezza_ok else 'ERRORE'})")
    print(f"  i due regimi hanno stocastiche diverse: "
          f"{'si' if distinti else 'NO - il confronto sarebbe vacuo!'}")

    giorni = pd.date_range(INIZIO, FINE, freq="D")
    sbagliati = [
        str(giorno.date()) for numero, giorno in enumerate(giorni)
        if not np.array_equal(
            composto[numero * minuti:(numero + 1) * minuti],
            (chiuso if giorno.weekday() >= 5 else feriale)[
                numero * minuti:(numero + 1) * minuti])
    ]
    print(f"  giorni presi dal regime sbagliato: {len(sbagliati)} su {len(giorni)}"
          f"{' (ok)' if not sbagliati else ' ' + str(sbagliati[:5])}")

    finto.regime = lambda giorno: "inesistente"
    try:
        ramp_runner._genera_a_regimi(finto, "finto", 0, "finto_1", INIZIO, FINE)
        print("  regime non dichiarato: NESSUN ERRORE - la guardia non funziona!")
        guardia_ok = False
    except ValueError:
        print("  regime non dichiarato: rifiutato correttamente")
        guardia_ok = True

    return lunghezza_ok and distinti and not sbagliati and guardia_ok


def main() -> None:
    esito = non_regressione()
    esito &= percorso_a_regimi()
    print()
    print("ESITO:", "TUTTO OK" if esito else "QUALCOSA NON VA")
    sys.exit(0 if esito else 1)


if __name__ == "__main__":
    main()
