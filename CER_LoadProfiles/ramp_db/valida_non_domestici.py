"""Il verdetto: quanto i profili RAMP somigliano al dato non domestico reale.

DUE GIUDICI, PER DUE GRANDEZZE DIVERSE. Il livello annuo e la stagionalita' li
giudica ARERA, che e' energia misurata al contatore ma solo su base mensile.
La forma della giornata la giudica il GSE, che e' orario ma e' una convenzione
regolatoria e non una misura. Nessuna delle due fonti puo' sostituire l'altra,
e nessuna delle due viene usata per calibrare il modello: entrambe giudicano.

COSA SI PUO' E COSA NON SI PUO' VALIDARE. Il GSE pubblica UNA sola forma non
domestica, 'altri usi', aggregata su tutti i settori. Quindi la forma oraria si
puo' validare solo sull'AGGREGATO dei membri non domestici; quella del singolo
ufficio o della singola officina resta argomentata dal catalogo e non validata.
E' un limite della fonte, non una scorciatoia: va dichiarato in tesi.

LE SOGLIE NON SONO SCELTE A TAVOLINO ma nemmeno, qui, misurabili come sul lato
domestico. Sulla forma oraria il GSE non ha revisionato i profili monorari fra
il 2024 e il 2025, quindi il "rumore della fonte" vale zero esatto e non e' un
metro utilizzabile. Sulla forma mensile manca del tutto la coppia di anni. Al
loro posto si riportano due surrogati, che misurano l'arbitrarieta' delle
scelte fatte invece della variabilita' della fonte:

  - dispersione fra CLASSI SORELLE della stessa divisione ATECO: quanto pesa
    aver scelto una classe invece di un'altra come bersaglio;
  - variabilita' della forma GSE FRA I MESI: l'ordine di grandezza di una
    differenza di forma reale dentro quella fonte.

Se lo scarto del modello e' dello stesso ordine del surrogato, il modello non
e' distinguibile dall'arbitrarieta' del confronto e va detto, invece di
dichiarare una validazione che i dati non sostengono.

Uso:
    python valida_non_domestici.py ../outputs/csv/profili_aziende.csv \
        --config ../config/simulation_config.yaml
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pandas as pd
import yaml

import riferimento_arera_nd as ar
import riferimento_gse as gse
from riferimento_gse import _abilita_lpg_db

_abilita_lpg_db()

from confronta_profili import carica          # noqa: E402
from valida_domestici import fasce_profilo, festivi, tvd   # noqa: E402

# Codice GSE di riferimento per la forma oraria non domestica.
#   P  = punto di prelievo PURO, senza generazione dietro il contatore, che e'
#        quello che RAMP produce (consumo lordo; il fotovoltaico e' altrove).
#   AU = altri usi, l'unica categoria non domestica disponibile.
#   M  = misuratore monorario, cioe' la chiave distribuita su tutte le ore.
# Il gemello 'PAUF' e' una terna di chiavi di fascia e va usato solo tramite
# curve_per_fascia(); 'MAU*' e' prelievo NETTO di punti con fotovoltaico.
CODICE_GSE = "PAUM"

# Classi sorelle usate per il surrogato di soglia sulla forma mensile.
SORELLE: dict[str, tuple[str, ...]] = {
    "82.11": ("69.20", "70.22", "62.01"),
    "25.99": ("25.50", "25.11", "25.94"),
    "47.11": ("47.19", "47.21", "47.25"),
}


def colonne_attese(config: dict) -> list[dict]:
    """Colonne che la configurazione dice di aspettarsi, con i loro metadati.

    Rispetta l'interruttore 'attivo': un archetipo spento non produce colonne e
    non va cercato nel CSV.
    """
    voci = []
    for uc in config["ramp"]["use_cases"]:
        if not uc.get("attivo", True):
            continue
        mancanti = [k for k in ("ateco", "banda", "potenza_impegnata_kW")
                    if k not in uc]
        if mancanti:
            sys.exit(
                f"L'archetipo '{uc['name']}' non dichiara {mancanti}. "
                "Senza questi il bersaglio ARERA verrebbe scelto a caso: "
                "aggiungerli in configurazione (vedi i commenti della sezione "
                "ramp in simulation_config.yaml)."
            )
        for i in range(uc["num_users"]):
            voci.append({
                "colonna": f"{uc['name']}_{i + 1}",
                "archetipo": uc["name"],
                "ateco": str(uc["ateco"]),
                "banda": uc["banda"],
                "potenza": float(uc["potenza_impegnata_kW"]),
            })
    return voci


def _forma_mensile(serie: pd.Series) -> pd.Series:
    m = serie.groupby(serie.index.month).sum()
    return m / m.sum()


def _l1(a: pd.Series, b: pd.Series) -> float:
    comuni = a.index.intersection(b.index)
    return float((a[comuni] - b[comuni]).abs().sum())


def _curva_feriale(serie: pd.Series) -> pd.Series:
    """Giornata feriale media normalizzata, festivi nazionali esclusi.

    Stessa convenzione di riferimento_gse: un festivo infrasettimanale non e'
    un giorno feriale, e tenerlo dentro sporcherebbe il confronto con una
    giornata di chiusura.
    """
    rossi = festivi(int(serie.index[0].year))
    feriali = serie[(serie.index.weekday < 5)
                    & (~pd.Series(serie.index.date, index=serie.index).isin(rossi))]
    curva = feriali.groupby(feriali.index.hour).mean()
    return curva / curva.sum()


def misura(serie: pd.Series, voce: dict, provincia: str) -> dict:
    """Tutti gli indicatori di una colonna."""
    kwh = float(serie.sum())
    atteso = ar.livello_annuo(provincia, voce["banda"], voce["ateco"])

    mensile = _forma_mensile(serie)
    mensile_arera = ar.forma_mensile(provincia, voce["banda"], voce["ateco"])

    curva = _curva_feriale(serie)
    curva_gse = gse.curva_media(CODICE_GSE, giorno="lun-ven")

    # Quota della domenica: un'attivita' chiusa la domenica ha una quota molto
    # sotto 1/7; il modello attuale, che non ha calendario, la tiene a 1/7.
    domenica = float(serie[serie.index.weekday == 6].sum()) / kwh

    notte = serie[(serie.index.hour >= 1) & (serie.index.hour <= 5)]
    return {
        "kwh": kwh,
        "atteso": atteso,
        "rapporto": kwh / atteso,
        "l1_mensile": _l1(mensile, mensile_arera),
        "agosto": float(mensile.get(8, 0)),
        "agosto_arera": float(mensile_arera.get(8, 0)),
        "tvd_oraria": tvd(curva, curva_gse),
        "domenica": domenica,
        "notte": float(notte.sum()) / kwh,
        "notte_gse": float(curva_gse[[1, 2, 3, 4, 5]].sum()),
        "picco": float(serie.max()),
        "rapporto_picco": float(serie.max()) / voce["potenza"],
        "fasce": fasce_profilo(serie),
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("profili", type=Path)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--provincia", default="Milano")
    args = parser.parse_args()

    for p in (args.profili, args.config):
        if not p.exists():
            sys.exit(f"File non trovato: {p}")

    config = yaml.safe_load(args.config.read_text(encoding="utf-8"))
    df = carica(args.profili)
    voci = colonne_attese(config)

    print(f"\nVALIDAZIONE NON DOMESTICI - {args.profili.name}")
    print(f"livello e stagionalita': ARERA {args.provincia} 2025")
    print(f"forma oraria: GSE {CODICE_GSE} (prelievo puro, altri usi, "
          "monorario)\n")

    print(f"{'archetipo':16} {'ATECO':7} {'kWh/anno':>9} {'atteso':>9} "
          f"{'scarto':>7}  {'L1 mens':>7} {'TVD ora':>7}")
    print("-" * 78)

    risultati = []
    for voce in voci:
        nome = voce["colonna"]
        colonna = nome if nome in df.columns else f"{nome}_kWh"
        if colonna not in df.columns:
            print(f"{voce['archetipo']:16} colonna assente nel CSV, saltata")
            continue
        r = misura(df[colonna], voce, args.provincia)
        risultati.append((voce, r))
        print(f"{voce['archetipo']:16} {voce['ateco']:7} {r['kwh']:>9,.0f} "
              f"{r['atteso']:>9,.0f} {r['rapporto']:>6.2f}x  "
              f"{r['l1_mensile']:>7.4f} {r['tvd_oraria']:>7.4f}")

    print("\n" + "=" * 78)
    print("DOVE STANNO I DIFETTI")
    print("=" * 78)
    print(f"\n{'archetipo':16} {'agosto':>14} {'domenica':>10} "
          f"{'notte 01-05':>13} {'picco/P_imp':>12}")
    print(f"{'':16} {'modello/ARERA':>14} {'% annuo':>10} "
          f"{'mod./GSE':>13} {'':>12}")
    print("-" * 78)
    for voce, r in risultati:
        print(f"{voce['archetipo']:16} "
              f"{r['agosto'] * 100:6.1f}/{r['agosto_arera'] * 100:<7.1f} "
              f"{r['domenica'] * 100:>9.1f} "
              f"{r['notte'] * 100:6.1f}/{r['notte_gse'] * 100:<6.1f} "
              f"{r['rapporto_picco']:>11.2f}")

    print("\nRiferimenti: la domenica vale 1/7 = 14,3% dell'anno per "
          "un'attivita' aperta\nsette giorni su sette; le ore 01-05 valgono "
          f"{risultati[0][1]['notte_gse'] * 100:.1f}% della giornata nel "
          "profilo GSE.")

    print("\nFASCE ORARIE (% del consumo annuo)")
    for voce, r in risultati:
        q = r["fasce"]
        print(f"  {voce['archetipo']:16} F1 {q.get('f1', 0):5.2f}  "
              f"F2 {q.get('f2', 0):5.2f}  F3 {q.get('f3', 0):5.2f}")

    print("\n" + "=" * 78)
    print("SOGLIE SURROGATE - non c'e' rumore di fonte utilizzabile")
    print("=" * 78)

    r_gse = gse.rumore_fonte(CODICE_GSE)
    print(f"\nForma oraria. Il GSE non ha revisionato {CODICE_GSE} fra il 2024 "
          f"e il 2025:\nTVD {r_gse['medio']:.4f} in tutti i mesi. Non e' una "
          "soglia, e' assenza di revisione.")
    v = gse.variabilita_stagionale(CODICE_GSE)
    print(f"Come metro alternativo, la stessa curva cambia fra i mesi di "
          f"{v['medio']:.4f}\nin media e {v['massimo']:.4f} al massimo "
          f"(mesi {v['mesi_estremi'][0]} e {v['mesi_estremi'][1]}).")

    print("\nForma mensile. Manca il secondo anno; al suo posto, quanto "
          "distano fra loro\nclassi sorelle della stessa divisione ATECO:")
    for voce, r in risultati:
        sorelle = SORELLE.get(voce["ateco"])
        if not sorelle:
            continue
        try:
            d = ar.rumore_classe(args.provincia, voce["banda"],
                                 (voce["ateco"],) + sorelle)
        except SystemExit:
            continue
        stato = ("SOTTO la soglia" if r["l1_mensile"] < d["medio"]
                 else "sopra la soglia")
        print(f"  {voce['archetipo']:16} sorelle L1 medio {d['medio']:.4f}, "
              f"modello {r['l1_mensile']:.4f}  -> {stato}")

    print("\nLettura: se lo scarto del modello e' dell'ordine della "
          "dispersione fra classi\nsorelle, non e' distinguibile "
          "dall'arbitrarieta' della classe scelta come\nbersaglio, e non "
          "va riportato come validazione.")


if __name__ == "__main__":
    main()
