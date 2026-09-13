"""Valida i profili non domestici generati da RAMP contro ARERA e GSE.

Gemello non domestico di `lpg_db/valida_domestici.py`, e stesso metodo. Cambia
solo il fatto che il bersaglio viene da DUE fonti invece che da una, perche'
nessuna delle due lo fornisce per intero:

    livello annuo e peso dei mesi  ->  ARERA per ATECO e classe BTA (mensile)
    forma oraria dentro il mese    ->  profili standard GSE

SI NORMALIZZA PRIMA DI CONFRONTARE. Ogni curva viene riportata a somma unitaria,
cosi' la FORMA si valida separatamente dal LIVELLO: consumare troppo e consumare
nel momento sbagliato sono due errori diversi, e un confronto su curve non
normalizzate li mescola in un numero che non dice quale dei due sia il problema.

SE NON COMBACIA SI CORREGGE L'ARCHETIPO, MAI L'USCITA. Nessun fattore correttivo
orario: sistemerebbe la somma rendendo meno plausibile il profilo individuale, e
la ripartizione dell'energia condivisa nella CER vive esattamente sulle forme
individuali.

LA SOGLIA E' IL RUMORE DELLA FONTE, non un numero scelto a tavolino: quanto
cambia ARERA fra il 2024 e il 2025 sullo stesso ATECO e classe. Misurato su
Milano ATECO 82.11: da -4,5% a +3,8% sul livello annuo secondo la classe, e da
0,041 a 0,074 di L1 sulla forma mensile.

QUATTRO AVVERTENZE, da riportare in tesi accanto ai numeri:

  1. Il profilo GSE dei non domestici e' UNO SOLO per tutta la categoria "altri
     usi" (codice PAU): non distingue un ufficio da una scuola da un municipio.
     Uno scarto sulla forma di un archetipo con stagionalita' marcata e' quindi
     atteso anche se l'archetipo e' corretto.
  2. Il profilo GSE IGNORA IL GIORNO DELLA SETTIMANA: la distanza fra la sua
     giornata feriale media e quella domenicale vale 0,001. La chiusura nel fine
     settimana di un archetipo non e' percio' validabile su questa fonte, e le
     TVD per tipo di giorno vanno lette sapendolo.
  3. La classe di potenza e l'ATECO di un archetipo sono un'ASSUNZIONE
     DICHIARATA, non un dato: ARERA non pubblica il numero di POD per classe.
     Per questo si riporta anche la classe adiacente.
  4. La superficie in m2 serve solo al confronto con i benchmark di letteratura
     ed e' anch'essa un'ipotesi dichiarata: nessun file la contiene.

Uso:
    python valida_non_domestici.py ../outputs/csv/profili_tutti.csv
    python valida_non_domestici.py profili.csv --colonne office_1:82.11:BTA4:180
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "lpg_db"))
from confronta_profili import STAGIONI, carica, curve_medie  # noqa: E402
from valida_domestici import fasce_profilo, festivi, tvd  # noqa: E402

import riferimento_arera_nd as nd  # noqa: E402
import riferimento_gse_nd as gse  # noqa: E402

# Assegnazione predefinita colonna -> (ATECO, classe BTA, superficie m2).
# E' un'IPOTESI DICHIARATA, non un dato. office: 9,2 kW installati fra
# illuminazione, postazioni, clima, stampanti e macchinetta, quindi BTA4 (6-10
# kW); ATECO 82.11 "Servizi integrati di supporto per le funzioni d'ufficio";
# 180 m2 e' l'ipotesi di superficie del piano, e serve solo al kWh/m2.
ASSEGNAZIONE_PREDEFINITA = {
    "office_1": ("82.11", "BTA4", 180),
}

# I mesi di ciascuna stagione, con la convenzione di confronta_profili.STAGIONI.
MESI_STAGIONE: dict[str, list[int]] = {}
for _mese, _stagione in STAGIONI.items():
    MESI_STAGIONE.setdefault(_stagione, []).append(_mese)

GIORNI = {"lun-ven": (0, 1, 2, 3, 4), "sabato": (5,), "domenica": (6,)}


def controlla_indice(df: pd.DataFrame, percorso: Path) -> None:
    """L'anno deve avere 8760 ore consecutive, senza buchi ne' doppioni.

    Non e' pignoleria: in outputs/ e' sopravvissuto a lungo un CSV di 8759 righe,
    generato prima della correzione sull'ora legale, a cui mancava
    2025-03-30 02:00. Un file cosi' non da' errore da nessuna parte, sposta
    solo di un'ora meta' dell'anno.
    """
    if len(df) != 8760:
        sys.exit(f"{percorso.name}: {len(df)} righe invece di 8760. "
                 f"Probabilmente e' un file generato prima della correzione "
                 f"sull'ora legale: rigenerarlo.")
    salti = df.index.to_series().diff().dropna()
    anomali = salti[salti != pd.Timedelta(hours=1)]
    if not anomali.empty:
        sys.exit(f"{percorso.name}: l'indice non e' orario continuo, "
                 f"{len(anomali)} salti anomali (primo: {anomali.index[0]}).")


def curva_oraria(serie: pd.Series, giorni: tuple[int, ...],
                 mesi: list[int] | None = None) -> pd.Series:
    """Giornata media normalizzata a somma unitaria, 24 valori.

    I festivi nazionali vengono esclusi dai feriali: non sono giorni di lavoro,
    e tenerli dentro appiattirebbe proprio la differenza che si sta misurando.
    ARERA non documenta come li classifichi, quindi la scelta va dichiarata.
    """
    esclusi = set()
    for anno in serie.index.year.unique():
        esclusi |= festivi(int(anno))
    date = pd.Series(serie.index.date, index=serie.index)
    filtro = serie.index.weekday.isin(giorni)
    if giorni == GIORNI["lun-ven"]:
        filtro &= ~date.isin(esclusi).to_numpy()
    if mesi is not None:
        filtro &= serie.index.month.isin(mesi)
    parte = serie[filtro]
    if parte.empty:
        return pd.Series(dtype=float)
    curva = parte.groupby(parte.index.hour).mean()
    totale = float(curva.sum())
    if totale <= 0:
        # L'archetipo e' SPENTO in questi giorni: la curva normalizzata non
        # esiste. Restituirla come zeri o NaN darebbe una TVD di 0,000, cioe'
        # "forma perfetta", proprio dove il modello non consuma nulla - office
        # ha wd_we_type=0 e nel fine settimana vale 0,000 kWh su 2.496 ore.
        # Meglio nessun numero che un numero che dice il contrario del vero.
        return pd.Series(dtype=float)
    return curva / totale


def _fmt(valore: float, larghezza: int = 8) -> str:
    """Formatta una TVD, distinguendo 'non calcolabile' da 'zero'."""
    if valore != valore:      # NaN: nessuna ora in comune fra le due curve
        return f"{'spento':>{larghezza}}"
    return f"{valore:>{larghezza}.3f}"


def curva_gse(anno: int, giorni: tuple[int, ...],
              mesi: list[int] | None = None) -> pd.Series:
    """La stessa grandezza, presa dal profilo standard GSE degli altri usi.

    Nota: GSE ignora il giorno della settimana, quindi il parametro `giorni` non
    cambia praticamente nulla (TVD feriale/domenica = 0,001). Lo si passa
    comunque, cosi' il confronto resta omologo e il giorno in cui il GSE
    dovesse iniziare a distinguerli non serve toccare questo codice.
    """
    if mesi is None:
        return gse.curva_giornaliera(anno, gse.CODICE_NON_DOMESTICO,
                                     giorni_settimana=giorni)
    pezzi = [gse.curva_giornaliera(anno, gse.CODICE_NON_DOMESTICO, mese=m,
                                   giorni_settimana=giorni) for m in mesi]
    media = pd.concat(pezzi, axis=1).mean(axis=1)
    return media / media.sum()


def forma_mensile_modello(serie: pd.Series) -> pd.Series:
    """Quota di ciascun mese sul totale annuo del profilo generato."""
    per_mese = serie.groupby(serie.index.month).sum()
    return per_mese / per_mese.sum()


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("profili", type=Path, help="CSV prodotto dalla pipeline")
    parser.add_argument("--provincia", default="Milano")
    parser.add_argument("--anni", type=int, nargs="+", default=[2024, 2025])
    parser.add_argument("--colonne", nargs="*", default=None,
                        help="terne colonna:ateco:classe[:superficie_m2], "
                             "es. office_1:82.11:BTA4:180")
    args = parser.parse_args()

    if not args.profili.exists():
        sys.exit(f"File non trovato: {args.profili}")
    anni = tuple(args.anni)
    anno_gse = anni[-1]

    df = carica(args.profili)
    controlla_indice(df, args.profili)

    if args.colonne:
        assegnazione = {}
        for voce in args.colonne:
            pezzi = voce.split(":")
            if len(pezzi) < 3:
                sys.exit(f"Formato atteso colonna:ateco:classe[:m2], "
                         f"ricevuto '{voce}'")
            colonna, ateco, classe = pezzi[0], pezzi[1], pezzi[2]
            superficie = float(pezzi[3]) if len(pezzi) > 3 else None
            assegnazione[colonna] = (ateco, classe, superficie)
    else:
        assegnazione = {c: v for c, v in ASSEGNAZIONE_PREDEFINITA.items()
                        if c in df.columns or f"{c}_kWh" in df.columns}
        print("\nAVVISO: nessun --colonne indicato, si usa l'assegnazione "
              "predefinita.\nATECO, classe di potenza e superficie sono "
              "IPOTESI DICHIARATE, non dati.")

    if not assegnazione:
        sys.exit("Nessuna colonna non domestica riconosciuta. Usare --colonne.")

    nd.mensili(args.provincia)      # popola la cache prima di stampare

    print(f"\nVALIDAZIONE NON DOMESTICI - {args.profili.name}")
    print(f"livello e forma mensile: ARERA {args.provincia}, anni "
          f"{' e '.join(map(str, anni))}")
    print(f"forma oraria: profili standard GSE {anno_gse}, "
          f"codice {gse.CODICE_NON_DOMESTICO} ({gse.PROFILI[gse.CODICE_NON_DOMESTICO]})\n")

    # --- 1. livello e forma oraria, una riga per colonna ---------------------
    print(f"{'colonna':14} {'ATECO':7} {'classe':7} {'kWh/anno':>10} "
          f"{'atteso':>10} {'scarto':>8} {'kWh/m2':>8}  "
          f"{'TVD fer.':>8} {'sab.':>6} {'dom.':>6}")
    print("-" * 104)

    risultati = {}
    for colonna, (ateco, classe, superficie) in assegnazione.items():
        nome = colonna if colonna in df.columns else f"{colonna}_kWh"
        if nome not in df.columns:
            print(f"{colonna:14} colonna assente nel file, saltata")
            continue
        serie = df[nome]
        kwh = float(serie.sum())
        atteso = float(nd.livello_annuo(args.provincia, ateco, classe, anni).mean())

        tvd_giorno = {}
        for etichetta, giorni in GIORNI.items():
            tvd_giorno[etichetta] = tvd(curva_oraria(serie, giorni),
                                        curva_gse(anno_gse, giorni))

        risultati[colonna] = {"serie": serie, "ateco": ateco, "classe": classe,
                              "kwh": kwh, "atteso": atteso}
        per_m2 = f"{kwh / superficie:>8.1f}" if superficie else f"{'n.d.':>8}"
        print(f"{colonna:14} {ateco:7} {nd.SIGLA.get(nd.risolvi_classe(classe), classe):7} "
              f"{kwh:>10,.0f} {atteso:>10,.0f} {kwh / atteso:>7.2f}x {per_m2}  "
              f"{_fmt(tvd_giorno['lun-ven'], 8)} {_fmt(tvd_giorno['sabato'], 6)} "
              f"{_fmt(tvd_giorno['domenica'], 6)}")

    if not risultati:
        sys.exit("Nessuna colonna validata.")

    # --- 2. la soglia, e la classe adiacente --------------------------------
    print("\nSOGLIA DI ACCETTAZIONE - rumore della fonte ARERA fra i due anni")
    print(f"{'ATECO':7} {'classe':8} {'scarto livello':>15} {'L1 mensile':>12}")
    for colonna, r in risultati.items():
        for classe in (r["classe"], nd.ADIACENTI[nd.risolvi_classe(r["classe"])]):
            sigla = nd.SIGLA.get(nd.risolvi_classe(classe), classe)
            try:
                rumore = nd.rumore_fonte(args.provincia, r["ateco"], classe,
                                         (anni[0], anni[-1]))
            except SystemExit:
                print(f"{r['ateco']:7} {sigla:8} {'(nessun dato)':>15}")
                continue
            adiacente = "" if classe == r["classe"] else "  <- adiacente"
            print(f"{r['ateco']:7} {sigla:8} "
                  f"{rumore['scarto_livello_pct']:>14.1f}% "
                  f"{rumore['l1_mensile']:>12.4f}{adiacente}")

    # --- 3. forma mensile: la metrica di testa del lato non domestico -------
    print("\nFORMA MENSILE - quota di ciascun mese sul totale annuo (%)")
    print("  " + " ".join(f"{m:>5}" for m in range(1, 13)) + f" {'L1':>8}")
    for colonna, r in risultati.items():
        modello = forma_mensile_modello(r["serie"])
        arera = nd.forma_mensile(args.provincia, r["ateco"], r["classe"],
                                 anni).mean(axis=0)
        arera.index = [int(m) for m in arera.index]
        l1 = float((modello - arera).abs().sum())
        print(f"  {colonna}")
        print("    RAMP " + " ".join(f"{modello.get(m, 0) * 100:>5.1f}"
                                     for m in range(1, 13)))
        print("    ARERA" + " ".join(f"{arera.get(m, 0) * 100:>5.1f}"
                                     for m in range(1, 13))
              + f" {l1:>8.4f}")

    # --- 4. TVD per stagione e tipo di giorno -------------------------------
    print("\nTVD PER STAGIONE E TIPO DI GIORNO - dove il modello sbaglia")
    print(f"  {'colonna':14} {'stagione':10} "
          + " ".join(f"{g:>9}" for g in GIORNI))
    for colonna, r in risultati.items():
        for stagione, mesi in sorted(MESI_STAGIONE.items()):
            valori = []
            for giorni in GIORNI.values():
                valori.append(tvd(curva_oraria(r["serie"], giorni, mesi),
                                  curva_gse(anno_gse, giorni, mesi)))
            print(f"  {colonna:14} {stagione:10} "
                  + " ".join(_fmt(v, 9) for v in valori))

    # --- 5. fasce orarie e ora di picco -------------------------------------
    print("\nFASCE ORARIE (% del consumo annuo) E ORA DI PICCO")
    for colonna, r in risultati.items():
        quote = fasce_profilo(r["serie"])
        pesi = nd.forma_mensile(args.provincia, r["ateco"], r["classe"],
                                (anni[-1],)).loc[anni[-1]]
        attese = gse.fasce(anno_gse, gse.CODICE_NON_DOMESTICO, pesi_mensili=pesi)
        feriali = curva_oraria(r["serie"], GIORNI["lun-ven"])
        picco_gse = curva_gse(anno_gse, GIORNI["lun-ven"])
        print(f"  {colonna}")
        print(f"    RAMP   F1 {quote.get('f1', 0):5.2f}  F2 {quote.get('f2', 0):5.2f}"
              f"  F3 {quote.get('f3', 0):5.2f}   picco feriale ore "
              f"{int(feriali.idxmax()):02d}")
        print(f"    GSE    F1 {attese.get('f1', 0):5.2f}  F2 {attese.get('f2', 0):5.2f}"
              f"  F3 {attese.get('f3', 0):5.2f}   picco feriale ore "
              f"{int(picco_gse.idxmax()):02d}")

    # --- 6. le righe di cautela ---------------------------------------------
    print("\nCome si leggono questi numeri:")
    print("  - il profilo GSE degli altri usi e' UNO SOLO per tutti i non")
    print("    domestici e IGNORA il giorno della settimana (TVD feriale contro")
    print("    domenica = 0,001): le TVD per tipo di giorno vanno lette sapendolo,")
    print("    e la chiusura nel fine settimana non e' validabile su questa fonte;")
    print("  - 'spento' non e' uno zero: vuol dire che l'archetipo non consuma")
    print("    nulla in quei giorni, quindi la curva normalizzata non esiste e")
    print("    la TVD non e' calcolabile. Stamparla come 0,000 direbbe 'forma")
    print("    perfetta' proprio dove il modello e' fermo;")
    print("  - ATECO, classe di potenza e superficie sono ipotesi dichiarate:")
    print("    per questo si riporta anche la classe adiacente;")
    print("  - se la forma non combacia si corregge l'archetipo, mai l'uscita.")


if __name__ == "__main__":
    main()
