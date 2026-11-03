#!/usr/bin/env bash
# Analisi completa delle repliche: UN comando (piano in docs/analisi_finale/).
#
#   bash CER_repliche/analisi_finale.sh                       dal PC del run (o da qualunque PC,
#                                                             se le tabelle sono gia' versionate)
#   bash CER_repliche/analisi_finale.sh --radice /tmp/banco --attese 7 --out /tmp/banco/tesi   (prove)
#
# Passi:
#   1. lettura unita in MATLAB (unisci_repliche.sh), SOLO per le repliche che non l'hanno ancora:
#      il 3 novembre e' stata fatta per tutte e 21, quindi di norma si salta
#   2. salva_tabelle_analisi.py  copia in unito/rNN/tabelle/ (versionata) le tabelle di MAIN2 che
#                                servono all'analisi; senza tables/ (altro PC) usa quelle gia' copiate
#   3. controlla_unito.py        295 comunita', 10 metodi, stabilita' a tutte le taglie
#   4. aggrega_repliche.py       aggregato/: CSV, sintesi.md, robustezza (k/20, Clopper-Pearson,
#                                meta', bootstrap), soglia, VAN, quote ai prosumer, sensibilita'
#   5. grafici_repliche.py       figure G01-G13 -> <out>/figure
#   6. unisci_per_figure.py + grafici_metodi.py   figure descrittive F01-F13 su tutte le repliche
#   7. tesi_finale.py            <out>/rapporto.html (figure), numeri_tesi.tex, tabelle/*.tex
#   8. rapporto_repliche.py      outputs/report/RISULTATI_repliche_<data>.html (rapporto commentato)
# Si ferma al primo passo che fallisce e dice quale. Registro in <out>/analisi_finale.log.
set -u
cd "$(dirname "$0")/.." || exit 1

RADICE="outputs/repliche"
ATTESE=21
OUT="outputs/tesi_finale"
while [ $# -gt 0 ]; do
    case "$1" in
        --radice) RADICE="$2"; shift ;;
        --attese) ATTESE="$2"; shift ;;
        --out) OUT="$2"; shift ;;
        --solo-python) ;;            # compatibilita': il passo MATLAB ora si salta da se'
        *) echo "argomento sconosciuto: $1"; exit 2 ;;
    esac
    shift
done

if [ -x venv/Scripts/python.exe ]; then PY=venv/Scripts/python.exe
elif command -v python3 >/dev/null; then PY=python3
else PY=python; fi

mkdir -p "$OUT"
LOG="$OUT/analisi_finale.log"
: > "$LOG"
INIZIO=$(date +%s)

passo() {   # passo <numero> <descrizione> <comando...>
    local n="$1" d="$2"; shift 2
    local t0=$(date +%s)
    echo "== passo $n: $d" | tee -a "$LOG"
    if "$@" >> "$LOG" 2>&1; then
        echo "   fatto in $(( $(date +%s) - t0 )) s" | tee -a "$LOG"
    else
        echo "   FALLITO (passo $n: $d). Le ultime righe del registro $LOG:" | tee -a "$LOG"
        tail -25 "$LOG"
        exit 1
    fi
}

# ---- 1. lettura unita, solo dove manca
DA_FARE=()
for R in $(seq 0 $((ATTESE - 1))); do
    D="$RADICE/unito/r$(printf "%02d" "$R")"
    if [ ! -f "$D/export/comunita.csv" ] || { [ ! -d "$D/tables/sintesi" ] && [ ! -d "$D/tabelle/sintesi" ]; }; then
        DA_FARE+=("$R")
    fi
done
if [ ${#DA_FARE[@]} -gt 0 ]; then
    if ! command -v matlab >/dev/null; then
        echo "Mancano la lettura unita o le tabelle di ${#DA_FARE[@]} repliche (${DA_FARE[*]}) e MATLAB non c'e'." | tee -a "$LOG"
        echo "Lanciare questo comando sul PC del run, dove ci sono tables/ e i checkpoint." | tee -a "$LOG"
        exit 1
    fi
    passo 1 "lettura unita in MATLAB delle repliche ${DA_FARE[*]}" bash CER_repliche/unisci_repliche.sh "${DA_FARE[@]}"
else
    echo "== passo 1: lettura unita gia' fatta per tutte le $ATTESE repliche, salto" | tee -a "$LOG"
fi

passo 2 "copia delle tabelle per l'analisi (rNN/tabelle/)" $PY -I CER_repliche/salva_tabelle_analisi.py --radice "$RADICE"
passo 3 "controlli della lettura unita" $PY -I CER_repliche/controlla_unito.py --radice "$RADICE"
passo 4 "aggregazione e robustezza" $PY -I CER_repliche/aggrega_repliche.py --blocco unito --radice "$RADICE" --attese "$ATTESE"
passo 5 "figure sulle repliche (G01-G13)" $PY -I CER_repliche/grafici_repliche.py --radice "$RADICE" --out "$OUT/figure"
passo 6a "tabelle di tutte le repliche insieme" $PY -I CER_repliche/unisci_per_figure.py --radice "$RADICE"
passo 6b "figure descrittive (F01-F13)" $PY -I outputs/workspace/strumenti/grafici_metodi.py \
    --tabelle "$RADICE/unito/insieme/tables" --export "$RADICE/unito/insieme/export" \
    --out "$OUT/figure_descrittive" --numeri "$OUT/numeri_descrittivi" --senza-pagina
passo 7 "numeri per LaTeX, tabelle e pagina delle figure" $PY -I CER_repliche/tesi_finale.py --radice "$RADICE" \
    --attese "$ATTESE" --out "$OUT"
RAPPORTO="outputs/report/RISULTATI_repliche_$(date +%F).html"
[ "$RADICE" = "outputs/repliche" ] || RAPPORTO="$OUT/RISULTATI_repliche.html"
passo 8 "rapporto commentato" $PY -I CER_repliche/rapporto_repliche.py --blocco "$RADICE/unito" --uscita "$RAPPORTO"

echo "" | tee -a "$LOG"
echo "Analisi completa in $(( ($(date +%s) - INIZIO) / 60 )) min." | tee -a "$LOG"
echo "  rapporto commentato: $RAPPORTO" | tee -a "$LOG"
echo "  pagina delle figure: $OUT/rapporto.html" | tee -a "$LOG"
echo "  numeri per LaTeX:    $OUT/numeri_tesi.tex" | tee -a "$LOG"
echo "  tabelle LaTeX:       $OUT/tabelle/" | tee -a "$LOG"
echo "  figure:              $OUT/figure/ (G01-G13), $OUT/figure_descrittive/ (F01-F13)" | tee -a "$LOG"
echo "  numeri in chiaro:    $RADICE/unito/aggregato/sintesi.md, robustezza.csv, van.csv, soglia.csv" | tee -a "$LOG"
