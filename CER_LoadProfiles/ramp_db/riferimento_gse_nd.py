"""Forma oraria di riferimento: i profili standard GSE, per i non domestici.

Complemento di `riferimento_arera_nd.py`, che porta il livello ma solo su base
mensile. Qui si legge la forma oraria da una fonte diversa: i profili standard
che il GSE pubblica ogni anno per prelievo e immissione.

PERCHE' QUESTI PROFILI CONTANO PIU' DI UN BENCHMARK QUALSIASI. Non sono una
stima di letteratura: sono il meccanismo con cui l'energia condivisa viene
calcolata davvero. Secondo il Testo Integrato Autoconsumo Diffuso (TIAD,
allegato alla delibera ARERA 727/2022/R/eel), quando il gestore di rete non e'
tecnicamente in grado di raccogliere i dati di misura orari, il GSE profila i
dati a partire da quelli disponibili per tipologia di utenza presso il Sistema
Informativo Integrato, secondo i profili standard. Per un socio di CER non
trattato orario - cioe' la maggior parte delle piccole utenze non domestiche -
la curva oraria che entra nel settlement E' questa.

MA RESTANO UN METRO, NON UNA SORGENTE. Sostituirli a RAMP renderebbe identici in
forma tutti i membri della stessa categoria, ricreando il collasso gia' visto in
letteratura: e' proprio la varieta' delle forme individuali a distinguere
Shapley, Nucleolo e VLC da una ripartizione volumetrica. RAMP resta il
generatore; questi profili sono il bersaglio contro cui si misura.

COME SONO NORMALIZZATI I COEFFICIENTI, verificato sui file e non assunto. Non
sull'anno: dentro ciascun MESE, e per i profili a fasce dentro ciascuna coppia
(mese, fascia). Sul file 2024, che non ha il difetto di arrotondamento descritto
piu' sotto, le somme mensili sono esatte:

    PAUM, PDMM, PACM (monorari)  ->  1,000000 per mese
    PAUF, PDMF, PACF (a fasce)   ->  3,000000 per mese, cioe' 1 per fascia

Il profilo piatto IAFM vale 0,00134408... per ogni ora di gennaio, che e'
esattamente 1/744: la conferma piu' diretta che l'unita' di normalizzazione e'
il mese. Ne segue la divisione dei compiti fra le due fonti:

    forma ORARIA dentro il mese  -> GSE (questo modulo)
    peso di ciascun MESE         -> ARERA (riferimento_arera_nd.py)

Un profilo annuale completo si ottiene componendo le due cose:
profilo_orario(anno, codice, pesi_mensili=forma_mensile ARERA).

PERCHE' IL PROFILO PREDEFINITO E' QUELLO MONORARIO. Un profilo a fasce
redistribuisce separatamente l'energia di ciascuna fascia, quindi per comporlo
servirebbe il consumo mensile **per fascia**. Il file ARERA non domestico non lo
pubblica: ha la sola colonna "Prelievo medio mensile", a differenza del file
domestico che porta anche F1/F2/F3. Il profilo monorario redistribuisce invece
il totale del mese, che e' esattamente il dato che ARERA fornisce. La scelta di
PAUM non e' una preferenza sul tipo di misuratore: e' l'unica che si compone
correttamente con la fonte di livello disponibile.

UN DIFETTO DEL FILE 2025, da conoscere prima di usarlo. La colonna "Data ora"
del file 2025 accumula errore di virgola mobile nelle date seriali di Excel:
l'ultimo istante vale 2025-12-31 22:59:59,998 invece di 23:00, e verso fine anno
l'ora del timestamp resta indietro di uno rispetto alla colonna "Ora". Indicizzare
su "Data ora" produce una curva giornaliera traslata di un'ora e somme mensili
che non chiudono a 1. Qui l'indice viene percio' ricostruito dalle colonne intere
Anno / Mese / Giorno / Ora, che sono esatte in entrambi gli anni.

LA CODIFICA DELLE COLONNE. I nomi di colonna sono codici di quattro caratteri
XZZY, documentati in "Modalita' di profilazione dei dati di misura e relative
modalita' di utilizzo ai sensi dell'articolo 9 dell'Allegato A alla Delibera
318/2020/R/eel", GSE, versione 1 del 04/04/2022 (il file Autoconsumatori.pdf
nella cartella dei dati):

    X = P prelievo puro | M punto misto | I immissione pura
    ZZ = tipologia di utenza o impianto
    Y = M misuratore monorario | F misuratore a fasce

Quel documento precede il TIAD e cita ancora la delibera 318/2020 e l'art. 13
del TIS: si usa per decodificare la STRUTTURA dei codici, che nei file 2024 e
2025 e' identica, mentre la base normativa corrente dell'applicazione dei
profili e' il TIAD.

FONTE DEI DATI. GSE, "Modalita' di profilazione dei dati di misura - profili
standard GSE in prelievo e immissione", annualita' 2024 e 2025, scaricati
dall'area CACER del portale GSE. I due xlsx del 2025 in cartella sono stati
verificati identici per dimensione a quelli dello zip ufficiale
`profili GSE_prelievo e immissione_2025.zip` pubblicato dal GSE.

UN LIMITE CHE VA DICHIARATO IN TESI. Il profilo dei non domestici e' UNO SOLO
per tutta la categoria "altri usi" (codice PAU): non distingue un ufficio da una
scuola da un municipio. Uno scarto sulla forma di un archetipo con stagionalita'
marcata - la scuola chiusa d'estate - e' quindi atteso anche se l'archetipo e'
corretto, perche' la popolazione aggregata degli altri usi non chiude in massa
ad agosto. Va riportato accanto al risultato, non confuso con un difetto.

Uso:
    python riferimento_gse_nd.py
    python riferimento_gse_nd.py --codice PAUF --anni 2024 2025
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pandas as pd

from riferimento_arera_nd import impronta, radice

# Le funzioni di calendario e di fascia oraria vivono gia' nel lato domestico:
# si importano invece di riscriverle, perche' la maschera dei festivi e la
# classificazione in fasce devono essere lo stesso oggetto o prima o poi
# divergono. E' lo stesso idioma di bootstrap che ramp_runner.py usa per
# caricare gli use case.
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "lpg_db"))
from valida_domestici import fasce_profilo  # noqa: E402

# I codici, come li definisce il documento GSE citato nel docstring.
PROFILI = {
    # prelievo puro
    "PDMM": "domestico, misuratore monorario",
    "PDMF": "domestico, misuratore a fasce",
    "PAUM": "altri usi (non domestico BT), monorario",
    "PAUF": "altri usi (non domestico BT), a fasce",
    "PIRM": "illuminazione pubblica residuale, monorario",
    "PIRF": "illuminazione pubblica residuale, a fasce",
    "PACM": "punti con sistema di accumulo, monorario (profilo piatto)",
    "PACF": "punti con sistema di accumulo, a fasce (profilo piatto)",
    # prelievo su punti misti con impianto fotovoltaico
    "MDMM": "misto domestico, monorario",
    "MDMF": "misto domestico, a fasce",
    "MAUM": "misto altri usi, monorario",
    "MAUF": "misto altri usi, a fasce",
    # immissione pura
    "IFVM": "immissione fotovoltaico, monorario",
    "IFVF": "immissione fotovoltaico, a fasce",
    "IAFM": "immissione altre FER, monorario (profilo piatto)",
    "IAFF": "immissione altre FER, a fasce (profilo piatto)",
    "MFAM": "immissione FTV su punti misti, monorario",
    "MFAF": "immissione FTV su punti misti, a fasce",
    "MFDM": "immissione FTV su punti misti domestici, monorario",
    "MFDF": "immissione FTV su punti misti domestici, a fasce",
}

# Il profilo di riferimento per office, scuola_superiore e comune: "altri usi",
# variante monoraria. La ragione della variante e' nel docstring: e' l'unica che
# si compone con un livello mensile senza richiedere il dettaglio per fascia,
# che ARERA non pubblica per i non domestici.
CODICE_NON_DOMESTICO = "PAUM"

COLONNE_CALENDARIO = ["Data ora", "Anno", "Mese", "Giorno", "Ora"]

_memoria: dict[tuple[int, str], pd.DataFrame] = {}


def somma_attesa(codice: str) -> int:
    """Quanto deve sommare un profilo dentro un mese: 1 se monorario, 3 se a fasce.

    L'ultimo carattere del codice e' il tipo di misuratore (M monorario,
    F a fasce) e un profilo a fasce e' normalizzato a 1 dentro ciascuna delle
    tre fasce.
    """
    return 3 if codice.endswith("F") else 1


def file_profili(anno: int, verso: str = "prelievo") -> Path:
    """Percorso dell'xlsx GSE di un anno, cercato per nome sotto la radice."""
    schema = f"profili GSE_{verso}_{anno}.xlsx"
    trovati = sorted(radice().glob(f"**/{schema}"))
    if not trovati:
        sys.exit(f"File GSE non trovato: {schema}\n  cercato sotto {radice()}")
    return trovati[0]


def carica(anno: int, verso: str = "prelievo", verboso: bool = False) -> pd.DataFrame:
    """Coefficienti orari GSE di un anno, indicizzati per istante.

    Returns:
        DataFrame con DatetimeIndex orario e una colonna per codice di profilo.

    Due trappole di questi file, entrambe verificate:

      - il foglio si chiama 'Sheet 1' nel 2024 e 'Foglio1' nel 2025, per questo
        si apre sempre il primo foglio per posizione e mai per nome;
      - la colonna 'Data ora' del 2025 e' corrotta da errore di virgola mobile
        (finisce a 22:59:59,998 del 31 dicembre) e verso fine anno resta
        indietro di un'ora rispetto alla colonna 'Ora'. L'indice si ricostruisce
        percio' dalle colonne intere Anno/Mese/Giorno/Ora, mai da 'Data ora'.
    """
    chiave = (anno, verso)
    if chiave in _memoria:
        return _memoria[chiave]

    percorso = file_profili(anno, verso)
    if verboso:
        print(f"  lettura {percorso.name}")
    d = pd.read_excel(percorso, sheet_name=0)
    indice = pd.to_datetime(dict(year=d["Anno"], month=d["Mese"],
                                 day=d["Giorno"], hour=d["Ora"]))
    d = d.set_index(pd.DatetimeIndex(indice))
    d = d.drop(columns=[c for c in COLONNE_CALENDARIO if c in d.columns])
    _memoria[chiave] = d
    return d


def verifica_normalizzazione(anno: int, verso: str = "prelievo") -> pd.DataFrame:
    """Somma dei coefficienti per mese e per profilo.

    Deve valere somma_attesa(codice) per ogni colonna e ogni mese: 1 per i
    profili monorari, 3 per quelli a fasce.

    E' il controllo strutturale che tiene onesto tutto il resto del modulo. Se
    il GSE cambiasse convenzione e normalizzasse sull'anno invece che sul mese,
    ogni confronto costruito qui sopra sarebbe sbagliato di un fattore dodici
    senza dare errore; e un indice orario ricostruito male sposta le ore di
    confine fra un mese e l'altro, facendo deviare queste somme da 1. Il
    difetto della colonna 'Data ora' del 2025 e' stato trovato cosi'.
    """
    d = carica(anno, verso)
    return d.groupby(d.index.month).sum()


def curva_giornaliera(anno: int, codice: str = CODICE_NON_DOMESTICO,
                      mese: int | None = None,
                      giorni_settimana: tuple[int, ...] | None = None) -> pd.Series:
    """Curva media di una giornata, 24 valori normalizzati a somma unitaria.

    Args:
        mese: 1-12 per un singolo mese, None per la media dell'anno.
        giorni_settimana: es. (0,1,2,3,4) per i soli feriali, None per tutti.
    """
    d = carica(anno)
    if codice not in d.columns:
        sys.exit(f"Profilo '{codice}' assente nel file {anno}. "
                 f"Disponibili: {', '.join(d.columns)}")
    serie = d[codice]
    if mese is not None:
        serie = serie[serie.index.month == mese]
    if giorni_settimana is not None:
        serie = serie[serie.index.weekday.isin(giorni_settimana)]
    curva = serie.groupby(serie.index.hour).mean()
    return curva / curva.sum()


def profilo_orario(anno: int, codice: str = CODICE_NON_DOMESTICO,
                   pesi_mensili: pd.Series | None = None) -> pd.Series:
    """Profilo orario dell'anno intero, normalizzato a somma unitaria.

    Args:
        pesi_mensili: quota di ciascun mese sul totale annuo, indicizzata 1-12,
            tipicamente da riferimento_arera_nd.forma_mensile(). Se assente,
            tutti i mesi pesano uguale - che NON e' realistico, perche' i
            coefficienti GSE sono normalizzati dentro il mese e non portano
            alcuna informazione sul livello relativo dei mesi.

    Returns:
        Serie oraria che somma a 1 sull'anno.
    """
    d = carica(anno)
    if codice not in d.columns:
        sys.exit(f"Profilo '{codice}' assente nel file {anno}.")
    if pesi_mensili is not None and somma_attesa(codice) != 1:
        sys.exit(
            f"'{codice}' e' un profilo a fasce: ciascuna delle tre fasce e'\n"
            f"normalizzata separatamente dentro il mese, quindi per comporlo "
            f"servirebbe il\nconsumo mensile PER FASCIA. Il file ARERA non "
            f"domestico pubblica il solo\ntotale mensile. Usare la variante "
            f"monoraria ({codice[:-1]}M)."
        )
    serie = d[codice].copy()

    if pesi_mensili is None:
        return serie / serie.sum()

    pesi = pd.Series(pesi_mensili).astype(float)
    pesi.index = [int(m) for m in pesi.index]
    pesi = pesi / pesi.sum()
    fattori = pd.Series(serie.index.month, index=serie.index).map(pesi)
    if fattori.isna().any():
        sys.exit("pesi_mensili non copre tutti i dodici mesi.")
    # Ogni mese somma gia' a 1: moltiplicarlo per la sua quota annua lo porta
    # al peso giusto senza doverlo rinormalizzare.
    return serie * fattori


def fasce(anno: int, codice: str = CODICE_NON_DOMESTICO,
          pesi_mensili: pd.Series | None = None) -> pd.Series:
    """Ripartizione F1 / F2 / F3 in percentuale del profilo GSE.

    Senza pesi_mensili la ripartizione assume che tutti i mesi pesino uguale:
    e' la forma pura. Con i pesi ARERA diventa la ripartizione attesa per una
    utenza di quella classe e ATECO, ed e' quella da confrontare con RAMP.
    """
    return fasce_profilo(profilo_orario(anno, codice, pesi_mensili))


def tvd(a: pd.Series, b: pd.Series) -> float:
    """Total Variation Distance fra due curve gia' normalizzate a somma 1."""
    comuni = a.index.intersection(b.index)
    if len(comuni) == 0:
        return float("nan")
    return float((a[comuni] - b[comuni]).abs().sum()) / 2


def rumore_fonte_forma(codice: str = CODICE_NON_DOMESTICO,
                       anni: tuple[int, int] = (2024, 2025)) -> dict:
    """Quanto cambia la forma GSE da un anno all'altro: la soglia sulla forma.

    E' il gemello, sul lato forma, di riferimento_arera_nd.rumore_fonte(), e a
    differenza di quello e' calcolabile subito: i profili GSE sono disponibili
    per entrambe le annualita'.

    Il confronto e' fatto sulle curve giornaliere medie di ciascun mese, non
    sulle serie orarie intere: il 2024 e' bisestile e ha 8784 ore contro 8760,
    quindi le due serie non sono allineabili una a una.

    Returns:
        {'tvd_per_mese': {mese: valore}, 'tvd_medio': float, 'tvd_max': float}
    """
    a, b = anni
    per_mese = {}
    for mese in range(1, 13):
        per_mese[mese] = tvd(curva_giornaliera(a, codice, mese),
                             curva_giornaliera(b, codice, mese))
    valori = pd.Series(per_mese)
    return {
        "tvd_per_mese": per_mese,
        "tvd_medio": float(valori.mean()),
        "tvd_max": float(valori.max()),
    }


def distingue_giorno_settimana(anno: int,
                               codice: str = CODICE_NON_DOMESTICO) -> float:
    """TVD fra la giornata feriale media e quella domenicale media.

    Diagnostica necessaria prima di usare questi profili come metro: se il GSE
    non distinguesse il giorno della settimana, la chiusura nel fine settimana
    di un archetipo non sarebbe validabile contro questa fonte, e andrebbe
    dichiarato come limite invece che inseguito come errore.
    """
    return tvd(curva_giornaliera(anno, codice, giorni_settimana=(0, 1, 2, 3, 4)),
               curva_giornaliera(anno, codice, giorni_settimana=(6,)))


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--codice", default=CODICE_NON_DOMESTICO,
                        help=f"codice di profilo GSE (default {CODICE_NON_DOMESTICO})")
    parser.add_argument("--anni", type=int, nargs="+", default=[2024, 2025])
    args = parser.parse_args()

    anni = tuple(args.anni)
    codice = args.codice
    if codice not in PROFILI:
        sys.exit(f"Codice non riconosciuto: {codice}\n"
                 f"Ammessi: {', '.join(sorted(PROFILI))}")

    print(f"\nRIFERIMENTO GSE - profilo {codice}: {PROFILI[codice]}")
    print(f"anni {' e '.join(map(str, anni))}\n")

    for anno in anni:
        percorso = file_profili(anno)
        print(f"  {anno}: {percorso.name}")
        print(f"        sha256 {impronta(percorso)[:16]}...")

    atteso = somma_attesa(codice)
    print(f"\nCONTROLLO STRUTTURALE - dentro ogni mese i coefficienti devono "
          f"sommare a {atteso}")
    for anno in anni:
        somme = verifica_normalizzazione(anno)[codice]
        scarto = float((somme - atteso).abs().max())
        esito = ("esatta" if scarto < 1e-6
                 else "arrotondamento nella fonte" if scarto < 5e-3
                 else "ANOMALIA")
        print(f"  {anno}: min {somme.min():.6f}  max {somme.max():.6f}  "
              f"scarto {scarto:.2e}  ({esito})")

    print("\nCURVA GIORNALIERA MEDIA, % del giorno")
    print("  ora   " + "".join(f"{h:5d}" for h in range(24)))
    for anno in anni:
        curva = curva_giornaliera(anno, codice) * 100
        print(f"  {anno}  " + "".join(f"{v:5.2f}" for v in curva)
              + f"   picco ore {int(curva.idxmax()):02d}")

    print("\nGENNAIO CONTRO LUGLIO - la stagionalita' della forma, ultimo anno")
    for mese, nome in ((1, "gennaio"), (7, "luglio")):
        curva = curva_giornaliera(anni[-1], codice, mese) * 100
        print(f"  {nome:8}" + "".join(f"{v:5.2f}" for v in curva)
              + f"   picco ore {int(curva.idxmax()):02d}")

    print("\nDISTINZIONE FERIALE / DOMENICA (TVD)")
    for anno in anni:
        print(f"  {anno}: {distingue_giorno_settimana(anno, codice):.4f}")

    if len(anni) == 2:
        r = rumore_fonte_forma(codice, anni)
        print(f"\nRUMORE DELLA FONTE fra {anni[0]} e {anni[1]} "
              f"- e' la soglia di accettazione sulla forma")
        print(f"  TVD medio sui dodici mesi  {r['tvd_medio']:.4f}")
        print(f"  TVD massimo                {r['tvd_max']:.4f} "
              f"(mese {max(r['tvd_per_mese'], key=r['tvd_per_mese'].get):02d})")

    print("\nIl profilo degli altri usi e' unico per tutta la categoria: non")
    print("distingue un ufficio da una scuola da un municipio. I coefficienti")
    print("sono normalizzati dentro il mese: il peso relativo dei mesi va preso")
    print("da ARERA (riferimento_arera_nd.forma_mensile).")


if __name__ == "__main__":
    main()
