"""Tipologie familiari lombarde e milanesi dalle fonti ISTAT.

Rigenera ogni numero citato nel §12 del report e nelle intestazioni delle due
configurazioni di societa' (simulation_config.lombardia20.yaml e
simulation_config.milano20.yaml). Nessun numero di quelle sezioni e' scritto a
mano: si ottengono tutti eseguendo questo file.

PERCHE' SERVE. La Fase 3 ha misurato che l'identita' dell'archetipo domina il
seme di 7,6 volte. Ne segue che la composizione della CER - quali famiglie, non
quante - e' il parametro libero piu' importante del modello. Fino alla Fase 3
era stato scelto a occhio: due coppie e due famiglie con figli, nessuna persona
sola. Questo modulo lo deriva dai dati.

LE DUE FONTI E PERCHE' SERVONO ENTRAMBE.

  ISTAT, Aspetti della vita quotidiana 2024 (microdati). Da' la composizione
  COMPLETA di ogni famiglia: l'indagine intervista tutti i componenti, e la
  copertura si verifica qui sotto invece di essere assunta. Per ciascun membro
  si hanno eta' (ETAMi) e condizione professionale (CONDMi), quindi si sa
  quanti adulti restano in casa nei giorni feriali. Limite: i microdati
  pubblici si fermano alla REGIONE. Non esiste il dettaglio provinciale, e le
  variabili METRO e STCOM - che il nome farebbe sembrare territoriali - sono
  domande del questionario.

  ISTAT, Censimento permanente della popolazione 2021 (rilascio 2023), dati per
  sezione. Arriva al singolo comune e alla singola sezione, ma da' solo
  MARGINALI: famiglie per numero di componenti, popolazione per classe di eta',
  occupati. Non dice chi vive con chi.

  Una sola delle due non basta: AVQ ha la struttura ma non la geografia, il
  censimento ha la geografia ma non la struttura. Si combinano per
  post-stratificazione, ricalibrando i pesi AVQ finche' riproducono i marginali
  del comune voluto.

NON CIRCOLARITA'. Qui entrano solo fonti di CALIBRAZIONE. ARERA, che e' il
validatore, non compare: la composizione non viene scelta minimizzando la
distanza dalla curva ARERA, ma dalla demografia. Che poi le due cose si
incontrino e' il risultato da riportare, e sarebbe privo di significato se la
composizione fosse stata adattata al bersaglio.

Uso:
    python tipologie_famiglie.py                 # Lombardia e Milano
    python tipologie_famiglie.py --comune Brescia
    python tipologie_famiglie.py --famiglie 40   # allocazione per N diverso
"""

from __future__ import annotations

import argparse
import re
import sys

import numpy as np
import pandas as pd

import riferimento_istat as ri

# Il file regionale del censimento che contiene tutti i comuni lombardi.
CENSIMENTO = "R03_Lombardia_2023_sezioni.xlsx"

# Colonne del tracciato censuario effettivamente usate.
#   PF3..PF8  famiglie residenti per numero di componenti (1, 2, 3, 4, 5, 6+)
#   P1        popolazione residente totale
#   P27..P29  popolazione 65-69, 70-74, oltre 74
#   P101      occupati 15-64
COLONNE_CENSIMENTO = ("COMUNE", "P1", "P101", "PF3", "PF4", "PF5", "PF6",
                      "PF7", "PF8", "P27", "P28", "P29")

# Etichette delle quattro tipologie, in italiano e nell'ordine in cui si
# riportano nel report.
TIPI = ("tutti gli adulti occupati", "un adulto in casa di giorno",
        "solo anziani non occupati", "nessun occupato, non solo anziani")


def _eta_minima(codice: str, etichette: dict[str, str]) -> int | None:
    """Estremo inferiore della classe di eta' AVQ, in anni.

    ETAMi e' categorica ('da 25 a 34 anni'): si prende il primo numero
    dell'etichetta. Serve solo a separare minori, adulti e anziani, quindi
    l'estremo inferiore basta e non introduce l'arbitrio di un punto centrale.
    """
    numeri = re.findall(r"\d+", etichette.get(codice, ""))
    return int(numeri[0]) if numeri else None


def famiglie_avq(regione: str = ri.LOMBARDIA_AVQ) -> pd.DataFrame:
    """Una riga per famiglia AVQ, con la composizione del nucleo.

    Returns:
        DataFrame indicizzato su PROFAM con: peso, n (componenti), occ
        (occupati), adulti, anziani (65+), minori (<18), tipo e cls (classe
        di dimensione, 5 = cinque o piu').

    Raises:
        SystemExit: se l'indagine non copre tutti i componenti di ogni
            famiglia, nel qual caso la composizione non sarebbe ricostruibile
            e ogni numero a valle sarebbe sbagliato.
    """
    d = ri.avq(regione)
    etichette = ri._classificazione("ETAMi")
    d = d.assign(
        eta_min=d["ETAMi"].map(lambda c: _eta_minima(c, etichette)),
        occupato=d["CONDMi"].eq("1"),
    )

    fam = d.groupby("PROFAM").agg(
        peso=("peso", "first"),
        n=("PROFAM", "size"),
        ncomp=("NCOMP", "first"),
        occ=("occupato", "sum"),
        adulti=("eta_min", lambda s: int((s >= 18).sum())),
        anziani=("eta_min", lambda s: int((s >= 65).sum())),
        minori=("eta_min", lambda s: int((s < 18).sum())),
    )

    # Il peso AVQ e' individuale ma costante entro famiglia: 'first' e' quindi
    # il peso della famiglia. Se un'edizione futura cambiasse questa proprieta'
    # tutti i totali per famiglia sarebbero sbagliati, quindi si verifica.
    if d.groupby("PROFAM")["peso"].nunique().max() != 1:
        sys.exit("Il peso AVQ non e' costante entro famiglia: rivedere "
                 "l'aggregazione prima di usare questi risultati.")

    dichiarati = pd.to_numeric(fam["ncomp"], errors="coerce")
    if not (fam["n"] >= dichiarati).all():
        quota = (fam["n"] >= dichiarati).mean() * 100
        sys.exit(f"AVQ copre tutti i componenti solo nel {quota:.1f}% delle "
                 "famiglie: la composizione non e' ricostruibile.")

    def tipo(r: pd.Series) -> str:
        # L'ordine dei test conta: 'solo anziani' e' un sottoinsieme di
        # 'nessun occupato' e va riconosciuto per primo.
        if r["adulti"] > 0 and r["occ"] == 0 and r["anziani"] == r["adulti"]:
            return TIPI[2]
        if r["occ"] == 0:
            return TIPI[3]
        if r["occ"] < r["adulti"]:
            return TIPI[1]
        return TIPI[0]

    fam["tipo"] = fam.apply(tipo, axis=1)
    fam["cls"] = fam["n"].clip(upper=5)
    return fam.drop(columns="ncomp")


def marginali_censimento(comune: str | None = None) -> dict:
    """Marginali demografici di un comune lombardo, o dell'intera regione.

    Args:
        comune: nome del comune come compare nella colonna COMUNE; None per
            l'aggregato regionale.

    Returns:
        {'dimensione': array di 5 quote (1, 2, 3, 4, 5+), 'over65': quota di
        popolazione con 65 anni e piu', 'occupati': occupati 15-64 sulla
        popolazione, 'famiglie': totale, 'popolazione': totale, 'sezioni': n}.
    """
    percorso = ri._percorso(CENSIMENTO)
    d = pd.read_excel(percorso, usecols=lambda c: c in COLONNE_CENSIMENTO)
    if comune is not None:
        d = d[d["COMUNE"].astype(str).str.strip().str.upper() == comune.upper()]
        if d.empty:
            sys.exit(f"Comune '{comune}' assente da {CENSIMENTO}.")

    pf = [d[k].sum() for k in ("PF3", "PF4", "PF5", "PF6", "PF7", "PF8")]
    famiglie = sum(pf)
    # Le classi 5 e 6+ si accorpano: AVQ non distingue oltre il quinto
    # componente in modo affidabile su un campione regionale.
    dimensione = np.array([pf[0], pf[1], pf[2], pf[3], pf[4] + pf[5]]) / famiglie
    popolazione = d["P1"].sum()
    return {
        "dimensione": dimensione,
        "over65": sum(d[c].sum() for c in ("P27", "P28", "P29")) / popolazione,
        "occupati": d["P101"].sum() / popolazione,
        "famiglie": famiglie,
        "popolazione": popolazione,
        "sezioni": len(d),
    }


def calibra(fam: pd.DataFrame, marg: dict, iterazioni: int = 300) -> np.ndarray:
    """Ripondera le famiglie AVQ sui marginali del censimento (IPF).

    Due marginali, e non uno solo: la sola dimensione familiare non basta.
    Calibrando solo su quella, le unipersonali milanesi ereditano la struttura
    per eta' di quelle regionali, che sono molto piu' anziane, e la quota di
    65+ risulta 27,6% contro il 22,2% reale. Il secondo marginale corregge
    proprio questo.

    Il tasso di occupazione NON e' un vincolo: resta libero e serve da verifica
    indipendente della calibrazione.

    Args:
        fam: uscita di famiglie_avq().
        marg: uscita di marginali_censimento().
        iterazioni: cicli di scalatura alternata.

    Returns:
        Vettore di pesi, allineato alle righe di fam.
    """
    w = fam["peso"].to_numpy(dtype=float)
    cls = fam["cls"].to_numpy()
    n = fam["n"].to_numpy(dtype=float)
    anziani = fam["anziani"].to_numpy(dtype=float)
    con_anziani = anziani > 0

    for _ in range(iterazioni):
        for c in range(1, 6):
            m = cls == c
            w[m] *= marg["dimensione"][c - 1] / (w[m].sum() / w.sum())
        quota = (w * anziani).sum() / (w * n).sum()
        # Esponente 1/2: smorza il passo e impedisce che i due marginali
        # oscillino invece di convergere.
        w[con_anziani] *= (marg["over65"] / quota) ** 0.5
    return w


def sintesi(fam: pd.DataFrame, pesi: np.ndarray) -> dict:
    """Quote per tipologia e indicatori di controllo, in percentuale."""
    totale = pesi.sum()
    persone = (pesi * fam["n"]).sum()
    quote = {t: float(pesi[(fam["tipo"] == t).to_numpy()].sum() / totale * 100)
             for t in TIPI}
    return {
        "quote": quote,
        "in_casa": 100 - quote[TIPI[0]],
        "over65": float((pesi * fam["anziani"]).sum() / persone * 100),
        "occupati": float((pesi * fam["occ"]).sum() / persone * 100),
        "con_minori": float(pesi[(fam["minori"] > 0).to_numpy()].sum() / totale * 100),
    }


def _resto_maggiore(quote: pd.Series, totale: int) -> pd.Series:
    """Arrotonda quote continue a interi che sommano esattamente a totale."""
    interi = np.floor(quote).astype(int)
    avanzo = totale - int(interi.sum())
    for chiave in (quote - interi).sort_values(ascending=False).index[:avanzo]:
        interi[chiave] += 1
    return interi


def allocazione(fam: pd.DataFrame, pesi: np.ndarray, n_famiglie: int) -> pd.DataFrame:
    """Quante famiglie per cella (dimensione x tipologia) su n_famiglie totali.

    Allocazione GERARCHICA: prima si ripartisce il totale fra le classi di
    dimensione, poi entro ciascuna classe fra le tipologie. Il resto maggiore
    applicato direttamente alle venti celle non conserverebbe il marginale
    delle dimensioni - che e' il dato censuario, misurato sull'intera
    popolazione del comune - e lo sacrificherebbe a favore di celle campionarie
    molto piu' incerte. In Lombardia, per esempio, darebbe 7 famiglie
    unipersonali invece delle 8 che il censimento impone.

    Con N piccolo un residuo resta comunque, e va dichiarato: si riporta anche
    il valore esatto di ogni cella per renderlo visibile.
    """
    f = fam.assign(w=pesi)
    tabella = f.pivot_table(index="cls", columns="tipo", values="w",
                            aggfunc="sum").fillna(0)
    quote_cella = tabella.stack() / f["w"].sum() * n_famiglie

    per_dimensione = _resto_maggiore(
        tabella.sum(axis=1) / f["w"].sum() * n_famiglie, n_famiglie)

    assegnate = {}
    for cls, quanti in per_dimensione.items():
        riga = tabella.loc[cls]
        if quanti == 0 or riga.sum() == 0:
            entro = pd.Series(0, index=riga.index, dtype=int)
        else:
            entro = _resto_maggiore(riga / riga.sum() * quanti, int(quanti))
        for tipo_, k in entro.items():
            assegnate[(cls, tipo_)] = int(k)

    return pd.concat([
        quote_cella.rename("esatto"),
        pd.Series(assegnate).reindex(quote_cella.index).rename("assegnate"),
    ], axis=1)


def _stampa(nome: str, fam: pd.DataFrame, pesi: np.ndarray, marg: dict,
            n_famiglie: int) -> None:
    s = sintesi(fam, pesi)
    print(f"\n{'=' * 70}\n{nome}\n{'=' * 70}")
    print(f"  censimento: {marg['sezioni']:,} sezioni, {marg['famiglie']:,.0f} "
          f"famiglie, {marg['popolazione']:,.0f} residenti")
    print("  famiglie per componenti:  " + "  ".join(
        f"{i}{'+' if i == 5 else ''} {v * 100:.1f}%"
        for i, v in enumerate(marg["dimensione"], start=1)))
    print("\n  TIPOLOGIE (% di famiglie)")
    for t in TIPI:
        print(f"    {t:36} {s['quote'][t]:5.1f}%")
    print(f"    {'-' * 42}")
    print(f"    {'almeno un adulto in casa nei feriali':36} {s['in_casa']:5.1f}%")
    print(f"\n  controlli: 65+ {s['over65']:.1f}% (censimento "
          f"{marg['over65'] * 100:.1f}%), occupati {s['occupati']:.1f}% "
          f"(censimento {marg['occupati'] * 100:.1f}%, NON calibrato), "
          f"con minori {s['con_minori']:.1f}%")

    print(f"\n  ALLOCAZIONE SU {n_famiglie} FAMIGLIE")
    alloc = allocazione(fam, pesi, n_famiglie)
    for (c, t), riga in alloc[alloc["assegnate"] > 0].iterrows():
        print(f"    {c}{'+' if c == 5 else ' '} comp. | {t:36} "
              f"{int(riga['assegnate']):2d}   (esatto {riga['esatto']:.2f})")
    print(f"    totale {int(alloc['assegnate'].sum())}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--comune", default="Milano",
                        help="comune per la post-stratificazione (default Milano)")
    parser.add_argument("--famiglie", type=int, default=20,
                        help="numero di famiglie da allocare (default 20)")
    args = parser.parse_args()

    fam = famiglie_avq()
    print(f"AVQ 2024 Lombardia: {len(fam):,} famiglie, "
          f"{int(fam['n'].sum()):,} individui, copertura dei componenti 100%")
    print(f"pesi COEFIN: {fam['peso'].sum() / 1e6:.2f} milioni di famiglie")

    reg = marginali_censimento(None)
    print(f"censimento Lombardia: {reg['famiglie'] / 1e6:.2f} milioni "
          "(se i due totali divergono, i pesi non reggono)")

    _stampa("LOMBARDIA - pesi AVQ originali", fam,
            fam["peso"].to_numpy(dtype=float), reg, args.famiglie)

    com = marginali_censimento(args.comune)
    _stampa(f"{args.comune.upper()} - AVQ post-stratificata su due marginali",
            fam, calibra(fam, com), com, args.famiglie)


if __name__ == "__main__":
    main()
