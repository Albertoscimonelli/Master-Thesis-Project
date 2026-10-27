"""Numeri sulle CER reali usati per costruire l'asse "imprese" (CER_configuration_IND/).

Legge il database pubblico delle CER italiane di Koltunov et al. (2026) e stampa le
statistiche citate in CER_configuration_IND/README.md e nel README principale (§7.10).
Il database NON e' nel progetto (il repository non ha licenza): va clonato a parte.

    git clone https://github.com/maksym-koltunov/energy-communities-Italy.git
    python -I data/external/koltunov2026/analisi_database_cer.py \
        "energy-communities-Italy/CER database 2025 PUBLIC.xlsm"

Versione usata: commit 7560715 (27/08/2026), dati aggiornati a gennaio 2025.
Il file si apre in sola lettura e senza macro (keep_vba=False, data_only=True).
"""
import collections
import statistics as st
import sys

import openpyxl

# colonne del foglio "Main CERs" (indice da 0)
ZONA, KW_PV, AUTOCONS, MEMBRI, DESCR_MEMBRI = 2, 5, 7, 9, 10
QUOTE = range(11, 16)     # % potenza FV: pubblico, residenziale, PMI, NPO, standalone
TETTI_PA, TETTI_RES, TETTI_PMI, TETTI_NPO, TETTI_SA = 16, 17, 18, 19, 20
STADIO = 26
CAT = ["pubblico", "residenziale", "PMI", "NPO", "standalone"]


def num(x):
    try:
        return float(str(x).replace(",", "."))
    except (TypeError, ValueError):
        return None


def q(v, n=4):
    return [round(x, 2) for x in st.quantiles(v, n=n)]


def conteggio(valori):
    """distribuzione 1, 2, ..., 5, 6+ dei valori > 0"""
    return dict(sorted(collections.Counter(min(int(x), 6) for x in valori if x > 0).items()))


def main(path):
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True, keep_vba=False)
    righe = [r for r in list(wb["Main CERs"].iter_rows(values_only=True))[1:] if r[0]]
    nord = [r for r in righe if r[ZONA] == "North"]

    print("1) CER nel database:", len(righe), "| Nord:", len(nord))
    print("   stadio:", dict(collections.Counter(str(r[STADIO]).strip() for r in righe)))

    m = [num(r[MEMBRI]) for r in nord if num(r[MEMBRI])]
    print("2) membri per CER (Nord): n=%d, mediana %g, quartili %s" % (len(m), st.median(m), q(m)))
    print("   <15: %d | 15-18: %d | 19-25: %d | >25: %d" % (
        sum(x < 15 for x in m), sum(15 <= x <= 18 for x in m),
        sum(19 <= x <= 25 for x in m), sum(x > 25 for x in m)))

    tetti = (TETTI_PA, TETTI_RES, TETTI_PMI, TETTI_NPO)
    pn = [sum(num(r[i]) or 0 for i in tetti) / num(r[MEMBRI]) for r in nord
          if num(r[MEMBRI]) and any(num(r[i]) for i in tetti)]
    print("3) tetti prosumer / membri (Nord): n=%d, quartili %s, decili %s" % (len(pn), q(pn), q(pn, 10)))
    print("   quota di CER con rapporto <= 0,50: %.0f%%" % (100 * sum(x <= 0.5 for x in pn) / len(pn)))

    imp = [(num(r[TETTI_PMI]) or 0) + (num(r[TETTI_NPO]) or 0) for r in nord]
    print("4) imprese prosumer (PMI+NPO) per CER, Nord, dove presenti:", conteggio(imp))
    print("5) PA prosumer per CER, Nord, dove presenti:", conteggio([num(r[TETTI_PA]) or 0 for r in nord]))
    mix = [r for r in nord if (num(r[TETTI_PA]) or 0) > 0
           and (num(r[TETTI_PMI]) or 0) + (num(r[TETTI_NPO]) or 0) > 0]
    print("6) CER Nord con PA e imprese prosumer insieme:", len(mix), "-> (PA, imprese):",
          sorted((int(num(r[TETTI_PA])), int((num(r[TETTI_PMI]) or 0) + (num(r[TETTI_NPO]) or 0)))
                 for r in mix))

    quote = [[num(r[i]) for i in QUOTE] for r in nord]
    quote = [s for s in quote if all(x is not None for x in s)]
    print("7) quota di potenza FV per categoria, Nord (n=%d CER):" % len(quote))
    for j, c in enumerate(CAT):
        pres = [s[j] for s in quote if s[j] > 0]
        print("   %-12s media su tutte %5.1f%% | media dove presente %5.1f%% (n=%d)"
              % (c, st.mean(s[j] for s in quote), st.mean(pres), len(pres)))
    ncat = collections.Counter(sum(x > 0 for x in s) for s in quote)
    print("   numero di categorie presenti per CER:", dict(sorted(ncat.items())))

    kpm = [num(r[KW_PV]) / num(r[MEMBRI]) for r in nord
           if num(r[KW_PV]) and num(r[MEMBRI]) and 15 <= num(r[MEMBRI]) <= 25]
    print("8) kWp FV per membro, CER Nord da 15-25 membri: n=%d, quartili %s" % (len(kpm), q(kpm)))

    print("10) tetti medi per CER (Italia, solo dove la categoria c'e'):")
    for c, i in zip(CAT, (TETTI_PA, TETTI_RES, TETTI_PMI, TETTI_NPO, TETTI_SA)):
        v = [num(r[i]) for r in righe if num(r[i])]
        print("   %-12s %4.1f (n=%d CER)" % (c, st.mean(v), len(v)))

    sc = [num(r[AUTOCONS]) for r in righe if num(r[AUTOCONS]) is not None]
    print("11) autoconsumo dichiarato: n=%d, media %.1f%%, quartili %s" % (len(sc), st.mean(sc), q(sc)))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
