"""Profili standard GSE: il giudice della FORMA ORARIA dei profili non domestici.

COS'E' QUESTA FONTE. Sono le curve convenzionali che il GSE applica ai punti di
prelievo non trattati su base oraria, per ripartire fra le ore un'energia nota
solo su base mensile o per fascia. Vengono dal documento "Modalita' di
profilazione dei dati di misura", allegato alle regole tecniche CACER.

I codici seguono la logica XZZY dichiarata nel documento:
    X   P = punto di prelievo PURO (nessun impianto dietro il contatore)
        M = punto MISTO (impianto di produzione dietro il contatore)
        I = punto di sola immissione
    ZZ  tipologia di utenza: DM domestico, AU altri usi,
        IR / IC / IE / IW illuminazione pubblica, AC punti con accumulo
    Y   tipo di misuratore: M monorario, F a fasce

Da cui le tre conseguenze che governano tutto questo modulo:

1. IL RIFERIMENTO E' 'PAU', MAI 'MAU'. RAMP produce consumo LORDO, e il
   fotovoltaico e' modellato a parte. I profili con prefisso M sono prelievo
   NETTO di punti con generazione dietro il contatore: hanno la depressione di
   mezzogiorno del fotovoltaico e confrontarci un profilo di consumo lordo
   sarebbe un errore di grandezza, non di taratura.

2. I PROFILI 'F' NON SONO FORME DI CARICO. Sono TRE CHIAVI DI RIPARTIZIONE, una
   per fascia, ciascuna normalizzata a 1 nel mese: 'PAUF' somma esattamente
   3,000 ogni mese, contro 1,000 di 'PAUM'. I loro massimi cadono sui confini
   di fascia (ore 7 e 19-22) per pura aritmetica, non perche' li' ci sia un
   picco di consumo. Vanno decomposti per fascia e confrontati fascia per
   fascia: e' cio' che fa curve_per_fascia().

3. ESISTE UNA SOLA FORMA NON DOMESTICA. 'AU' - altri usi - e' un aggregato:
   non c'e' una curva per ufficio, negozio o officina. Si puo' quindi validare
   in forma l'AGGREGATO non domestico, non il singolo settore. E' un limite
   strutturale della fonte, da dichiarare, non da aggirare.

SULLA SOGLIA DI ACCETTAZIONE. Sul lato domestico la soglia era il rumore di
ARERA fra due anni. Qui non funziona: rumore_fonte() misura che i profili
monorari sono IDENTICI fra 2024 e 2025 (TVD 0,0000 in tutti e dodici i mesi).
Non e' rumore di misura, e' quanto il GSE ha revisionato una tabella
regolatoria. La funzione lo dice esplicitamente invece di restituire uno zero
muto che verrebbe scambiato per una soglia severissima.

Uso:
    python riferimento_gse.py --rumore
    python riferimento_gse.py --curva PAUM --anno 2025 --mese 7
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

import pandas as pd

QUI = Path(__file__).resolve().parent

# Radice dei dati esterni non domestici. Stessa convenzione di
# riferimento_arera.py sul lato domestico: sovrascrivibile con una variabile
# d'ambiente, cosi' il progetto resta eseguibile da un'altra macchina senza
# toccare il codice.
_DEFAULT_RADICE = Path.home() / "Downloads" / "File Non Domestici"

# I file, per anno. I nomi delle cartelle vengono dallo zip scaricato dal GSE e
# non sono uniformi fra le due edizioni: si cercano per schema invece che per
# percorso esatto.
SCHEMA_PRELIEVO = "**/profili GSE*prelievo*{anno}.xlsx"

# Colonne di calendario, comuni a tutte le edizioni.
COLONNE_TEMPO = ("Data ora", "Anno", "Mese", "Giorno", "Ora")

# Confini delle fasce ARERA, usati per decomporre i profili 'F'.
# F1: lun-ven 08-19. F2: lun-ven 07-08 e 19-23, sabato 07-23.
# F3: tutto il resto, cioe' notte, domenica e festivi.
# I festivi nazionali contano come F3: si applicano con festivi() del lato
# domestico invece di riscriverli.

_cache: dict[int, pd.DataFrame] = {}


def radice() -> Path:
    """Cartella dei dati non domestici, da variabile d'ambiente o default."""
    percorso = Path(os.environ.get("CER_DATI_NON_DOMESTICI", _DEFAULT_RADICE))
    if not percorso.exists():
        sys.exit(
            f"Cartella dei dati non domestici non trovata: {percorso}\n"
            "Impostare CER_DATI_NON_DOMESTICI sul percorso che contiene "
            "'profili GSE...' e 'Dati Provinica non dometici'."
        )
    return percorso


def _trova(anno: int) -> Path:
    """Percorso del file GSE di prelievo per un anno."""
    schema = SCHEMA_PRELIEVO.format(anno=anno)
    trovati = sorted(radice().glob(schema))
    if not trovati:
        sys.exit(f"File GSE di prelievo non trovato per l'anno {anno} "
                 f"(schema '{schema}' sotto {radice()}).")
    return trovati[0]


def carica(anno: int) -> pd.DataFrame:
    """Profili GSE di prelievo di un anno, con indice orario ricostruito.

    L'indice si costruisce da Anno/Mese/Giorno/Ora e MAI dalla colonna
    'Data ora', che nel file e' corrotta: contiene valori come
    '2025-10-26 01:59:59.999'. Prendendone l'ora si perde un'ora su molte righe
    e si ottengono curve sfalsate di un'ora, con una falsa stagionalita' del
    picco mattutino che sembra plausibile ed e' un artefatto.

    Il file e' in ora locale italiana come il settlement: manca l'ora 2 del
    giorno del passaggio all'ora legale e l'ora 2 del ritorno compare due
    volte. Entrambe le ore di ottobre sono ore reali e vengono TENUTE: nelle
    medie per ora del giorno quell'ora contribuisce con due campioni su 365
    giorni, effetto trascurabile e comunque preferibile a scartare
    silenziosamente meta' di un'ora davvero esistita.
    """
    if anno in _cache:
        return _cache[anno]

    d = pd.read_excel(_trova(anno))
    mancanti = [c for c in COLONNE_TEMPO[1:] if c not in d.columns]
    if mancanti:
        sys.exit(f"Il file GSE {anno} non ha le colonne {mancanti}: "
                 "tracciato diverso da quello atteso.")

    d = d.assign(ts=pd.to_datetime(dict(
        year=d["Anno"], month=d["Mese"], day=d["Giorno"], hour=d["Ora"])))
    _cache[anno] = d
    return d


def codici(anno: int = 2025) -> list[str]:
    """Codici di profilo disponibili nel file."""
    d = carica(anno)
    return [c for c in d.columns if c not in COLONNE_TEMPO and c != "ts"]


def _filtra(d: pd.DataFrame, mese: int | None, giorno: str | None) -> pd.DataFrame:
    """Filtra per mese e tipo di giorno.

    I FESTIVI NAZIONALI SONO ESCLUSI dai gruppi 'lun-ven' e 'sabato'. Un lunedi'
    di Ferragosto non e' un giorno feriale: ai fini delle fasce e' interamente
    F3, e tenerlo nel gruppo dei feriali farebbe cadere la stessa ora in due
    fasce diverse a seconda della data. E' la stessa scelta di _senza_festivi()
    sul lato domestico. I festivi restano invece nel gruppo 'domenica', che e'
    gia' tutto F3 e quindi non ha ambiguita'.
    """
    from valida_domestici import festivi  # vedi _abilita_lpg_db()

    if mese is not None:
        d = d[d["Mese"] == mese]
    if giorno is not None:
        settimana = d["ts"].dt.weekday
        if giorno == "lun-ven":
            d = d[settimana < 5]
        elif giorno == "sabato":
            d = d[settimana == 5]
        elif giorno == "domenica":
            d = d[settimana == 6]
        else:
            sys.exit(f"Tipo di giorno ignoto: '{giorno}'. "
                     "Attesi 'lun-ven', 'sabato', 'domenica'.")
        if giorno in ("lun-ven", "sabato") and not d.empty:
            rossi = festivi(int(d["Anno"].iloc[0]))
            d = d[~d["ts"].dt.date.isin(rossi)]
    if d.empty:
        sys.exit("Nessuna riga GSE dopo il filtro: combinazione mese/giorno "
                 "senza dati.")
    return d


def curva_media(codice: str, anno: int = 2025, mese: int | None = None,
                giorno: str | None = None) -> pd.Series:
    """Giornata media di 24 ore, normalizzata a somma unitaria.

    Args:
        codice: es. 'PAUM'. Per i codici 'F' vedi curve_per_fascia(): mediarli
            su tutte le ore mescola tre chiavi di fascia diverse.
        mese: None per la media dell'anno, 1-12 per un mese.
        giorno: None per tutti i giorni, oppure 'lun-ven', 'sabato', 'domenica'.
    """
    d = carica(anno)
    if codice not in d.columns:
        sys.exit(f"Codice '{codice}' assente dal file {anno}. "
                 f"Disponibili: {', '.join(codici(anno))}")
    d = _filtra(d, mese, giorno)
    curva = d.groupby(d["ts"].dt.hour)[codice].mean()
    return curva / curva.sum()


def curve_per_fascia(codice: str, anno: int = 2025, mese: int | None = None,
                     giorno: str = "lun-ven") -> dict[str, pd.Series]:
    """Decompone un profilo 'F' nelle sue tre chiavi di fascia.

    IL TIPO DI GIORNO VA FISSATO, e per questo 'giorno' non ha un default
    permissivo. Le fasce cambiano con il giorno della settimana: le 10:00 sono
    F1 di lunedi' e F2 di sabato, e la domenica e' tutta F3. Decomponendo su
    piu' tipi di giorno insieme, una stessa ora del giorno finirebbe in fasce
    diverse a seconda della data e la mascheratura non sarebbe piu' esatta: si
    otterrebbe una F2 di sedici ore invece delle cinque feriali. Fissato il
    tipo di giorno, ogni ora appartiene a UNA sola fascia e la decomposizione
    non stima nulla.

    Ciascuna chiave viene rinormalizzata ENTRO la propria fascia, cosi' il
    confronto con un profilo generato e' invariante rispetto alle quote di
    energia per fascia, che sono ignote e dipendono dall'utenza.

    Args:
        giorno: 'lun-ven', 'sabato' o 'domenica'. Per la domenica la
            decomposizione e' banale, perche' e' interamente F3.

    Returns:
        {'f1': Serie sulle ore di F1, ...}. Le tre serie hanno lunghezze
        diverse e non vanno concatenate. In un giorno feriale: F1 undici ore
        (8-18), F2 cinque (7, 19-22), F3 otto (0-6, 23).
    """
    if not codice.endswith("F"):
        sys.exit(f"curve_per_fascia() vale solo per i codici a fasce; "
                 f"'{codice}' non finisce per F. Per i monorari usare "
                 "curva_media().")
    d = _filtra(carica(anno), mese, giorno)
    d = d.assign(fascia=[_fascia_di(t) for t in d["ts"]])

    risultato = {}
    for nome in ("f1", "f2", "f3"):
        parte = d[d["fascia"] == nome]
        if parte.empty:
            continue
        curva = parte.groupby(parte["ts"].dt.hour)[codice].mean()
        # Controllo di coerenza: fissato il tipo di giorno, un'ora non puo'
        # comparire in due fasce. Se accade, il calendario dei festivi ha
        # spostato in F3 alcuni giorni del gruppo e il confronto sarebbe
        # sbilanciato senza che nulla lo segnali.
        risultato[nome] = curva / curva.sum()

    ore_viste = [h for s in risultato.values() for h in s.index]
    if len(ore_viste) != len(set(ore_viste)):
        sys.exit(f"Decomposizione incoerente per {codice}, giorno '{giorno}': "
                 "la stessa ora compare in piu' fasce. Probabile mescolanza "
                 "di giorni festivi e feriali nel gruppo.")
    return risultato


def _fascia_di(istante: pd.Timestamp) -> str:
    """Fascia ARERA di un istante, festivi nazionali inclusi in F3.

    Riusa festivi() del validatore domestico invece di riscrivere il calendario
    italiano: e' la stessa nozione, e due copie divergerebbero.
    """
    from valida_domestici import festivi  # import locale: vedi _abilita_lpg_db()

    giorno = istante.weekday()
    ora = istante.hour
    if istante.date() in festivi(istante.year) or giorno == 6:
        return "f3"
    if giorno == 5:
        return "f2" if 7 <= ora < 23 else "f3"
    if 8 <= ora < 19:
        return "f1"
    if 7 <= ora < 8 or 19 <= ora < 23:
        return "f2"
    return "f3"


def rumore_fonte(codice: str, anni: tuple[int, int] = (2024, 2025),
                 giorno: str = "lun-ven") -> dict:
    """Quanto il profilo GSE cambia fra due edizioni, mese per mese.

    ATTENZIONE ALL'INTERPRETAZIONE. Sul lato domestico l'indicatore analogo
    (ARERA fra due anni) era rumore di misura: due campagne indipendenti sulla
    stessa popolazione. Qui NO. I profili GSE sono una tabella regolatoria, e
    due edizioni differiscono solo se il GSE l'ha revisionata. Sui monorari non
    l'ha fatto affatto, e il risultato e' zero esatto: usarlo come soglia
    significherebbe pretendere dal modello una coincidenza perfetta.

    Returns:
        {'per_mese': {mese: tvd}, 'medio': float, 'identici': bool}.
    """
    from valida_domestici import tvd  # vedi _abilita_lpg_db()

    per_mese = {}
    for mese in range(1, 13):
        a = curva_media(codice, anni[0], mese, giorno)
        b = curva_media(codice, anni[1], mese, giorno)
        per_mese[mese] = tvd(a, b)

    medio = sum(per_mese.values()) / len(per_mese)
    return {
        "per_mese": per_mese,
        "medio": medio,
        "identici": all(v == 0.0 for v in per_mese.values()),
    }


def variabilita_stagionale(codice: str, anno: int = 2025,
                           giorno: str = "lun-ven") -> dict:
    """Quanto la forma cambia FRA I MESI dentro la stessa edizione.

    Serve come termine di paragone onesto accanto a rumore_fonte(): dice qual
    e' l'ordine di grandezza di una differenza di forma REALE dentro questa
    fonte, quando il rumore fra edizioni vale zero e non offre alcun metro.
    """
    from valida_domestici import tvd

    curve = {m: curva_media(codice, anno, m, giorno) for m in range(1, 13)}
    coppie = {}
    for a in range(1, 13):
        for b in range(a + 1, 13):
            coppie[(a, b)] = tvd(curve[a], curve[b])
    estremi = max(coppie.items(), key=lambda kv: kv[1])
    return {
        "massimo": estremi[1],
        "mesi_estremi": estremi[0],
        "medio": sum(coppie.values()) / len(coppie),
    }


def _abilita_lpg_db() -> None:
    """Rende importabile lpg_db/, dove stanno gli helper gia' validati.

    Si importano tvd() e festivi() da valida_domestici invece di riscriverli:
    sono la stessa nozione di distanza e lo stesso calendario italiano, e due
    copie divergerebbero al primo ritocco. L'alternativa - estrarli in un
    modulo condiviso - avrebbe richiesto di riorganizzare codice gia' validato,
    che questo progetto evita per scelta.
    """
    percorso = str((QUI.parent / "lpg_db").resolve())
    if percorso not in sys.path:
        sys.path.insert(0, percorso)


_abilita_lpg_db()


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--rumore", action="store_true",
                        help="misura la differenza fra le edizioni 2024 e 2025")
    parser.add_argument("--curva", default=None, help="codice, es. PAUM")
    parser.add_argument("--anno", type=int, default=2025)
    parser.add_argument("--mese", type=int, default=None)
    parser.add_argument("--giorno", default="lun-ven")
    args = parser.parse_args()

    if args.rumore:
        print("\nRUMORE DELLA FONTE GSE - edizione 2024 contro 2025, "
              f"giorno {args.giorno}\n")
        print(f"{'codice':8} {'medio':>8}  {'per mese'}")
        for cod in ("PAUM", "PAUF", "PDMM", "PDMF"):
            r = rumore_fonte(cod, giorno=args.giorno)
            valori = " ".join(f"{r['per_mese'][m]:.4f}" for m in range(1, 13))
            print(f"{cod:8} {r['medio']:8.4f}  {valori}")

        print("\nATTENZIONE: dove vale 0,0000 il GSE non ha revisionato la")
        print("tabella fra le due edizioni. Non e' rumore di misura e non e'")
        print("una soglia utilizzabile: e' assenza di revisione.")

        print("\nTermine di paragone - variabilita' fra i mesi, stessa edizione:")
        for cod in ("PAUM", "PDMM"):
            v = variabilita_stagionale(cod, args.anno, args.giorno)
            print(f"  {cod}: massimo {v['massimo']:.4f} fra i mesi "
                  f"{v['mesi_estremi'][0]} e {v['mesi_estremi'][1]}, "
                  f"medio {v['medio']:.4f}")
        return

    if args.curva:
        c = curva_media(args.curva, args.anno, args.mese, args.giorno)
        titolo = f"{args.curva}, {args.anno}"
        titolo += f", mese {args.mese}" if args.mese else ", anno intero"
        print(f"\n{titolo}, {args.giorno} - % della giornata\n")
        print("  ora  " + " ".join(f"{h:5d}" for h in range(24)))
        print("  %    " + " ".join(f"{c.get(h, 0) * 100:5.2f}" for h in range(24)))
        return

    print(f"Codici disponibili nel {args.anno}: {', '.join(codici(args.anno))}")
    print("\nUsare --rumore oppure --curva CODICE.")


if __name__ == "__main__":
    main()
