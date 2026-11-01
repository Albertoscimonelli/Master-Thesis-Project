#!/usr/bin/env bash
# Analisi finale delle repliche: UN comando, a run 20-25 finito (piano in docs/analisi_finale/).
#
#   bash CER_repliche/analisi_finale.sh                 tutto (MATLAB + Python), dal PC del run
#   bash CER_repliche/analisi_finale.sh --solo-python   salta la lettura unita in MATLAB (passo 1)
#   bash CER_repliche/analisi_finale.sh --solo-python --radice /tmp/banco --attese 7   (prove)
#
# Passi:
#   0. pre-controllo: le 21 repliche di ogni blocco hanno il checkpoint (solo con MATLAB)
#   1. unisci_repliche.sh        lettura unita 5-25 di ogni replica -> outputs/repliche/unito/rNN
#   2. controlla_unito.py        295 comunita', 10 metodi, stabilita' a tutte le taglie, r00
#   3. aggrega_repliche.py       aggregato/ (CSV e sintesi.md), robustezza delle conclusioni
#   4. grafici_repliche.py       figure G01-G13 -> outputs/tesi_finale/figure
#   5. unisci_per_figure.py + grafici_metodi.py   figure descrittive F01-F13 su tutte le repliche
#   6. rapporto_repliche.py      rapporto.html, numeri_tesi.tex, tabelle/*.tex
# Si ferma al primo passo che fallisce e dice quale. Si puo' rilanciare: le repliche gia' unite
# si saltano, il resto si rifa' (pochi minuti). Registro in outputs/tesi_finale/analisi_finale.log.
set -u
cd "$(dirname "$0")/.." || exit 1

SOLO_PYTHON=0
RADICE="outputs/repliche"
ATTESE=21
OUT="outputs/tesi_finale"
while [ $# -gt 0 ]; do
    case "$1" in
        --solo-python) SOLO_PYTHON=1 ;;
        --radice) RADICE="$2"; shift ;;
        --attese) ATTESE="$2"; shift ;;
        --out) OUT="$2"; shift ;;
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

ULTIMA=$((ATTESE - 1))
if [ $SOLO_PYTHON -eq 0 ]; then
    precontrollo() {
        local manca=0
        for B in fino15 da18 da20a25; do
            for R in $(seq 0 $ULTIMA); do
                NN=$(printf "%02d" "$R")
                if [ ! -f "$RADICE/$B/r$NN/checkpoint.mat" ] || [ ! -d "$RADICE/$B/r$NN/export" ]; then
                    echo "manca $RADICE/$B/r$NN (checkpoint o export)"; manca=1
                fi
            done
        done
        if grep -q "FALLITA" "$RADICE/da20a25/avanzamento.txt" 2>/dev/null; then
            echo "attenzione: righe FALLITA in da20a25/avanzamento.txt (controllare che siano state riprese):"
            grep "FALLITA" "$RADICE/da20a25/avanzamento.txt"
        fi
        return $manca
    }
    passo 0 "pre-controllo dei tre blocchi ($ATTESE repliche)" precontrollo
    passo 1 "lettura unita in MATLAB (circa 2-3 min a replica)" bash CER_repliche/unisci_repliche.sh $(seq 0 $ULTIMA)
fi
passo 2 "controlli della lettura unita" $PY -I CER_repliche/controlla_unito.py --radice "$RADICE"
passo 3 "aggregazione e robustezza" $PY -I CER_repliche/aggrega_repliche.py --blocco unito --radice "$RADICE" --attese "$ATTESE"
passo 4 "figure sulle repliche (G01-G13)" $PY -I CER_repliche/grafici_repliche.py --radice "$RADICE" --out "$OUT/figure"
passo 5a "tabelle di tutte le repliche insieme" $PY -I CER_repliche/unisci_per_figure.py --radice "$RADICE"
passo 5b "figure descrittive (F01-F13)" $PY -I outputs/workspace/strumenti/grafici_metodi.py \
    --tabelle "$RADICE/unito/insieme/tables" --export "$RADICE/unito/insieme/export" \
    --out "$OUT/figure_descrittive" --numeri "$OUT/numeri_descrittivi" --senza-pagina
passo 6 "rapporto, numeri per LaTeX e tabelle" $PY -I CER_repliche/rapporto_repliche.py --radice "$RADICE" \
    --attese "$ATTESE" --out "$OUT"

echo "" | tee -a "$LOG"
echo "Analisi finale completata in $(( ($(date +%s) - INIZIO) / 60 )) min." | tee -a "$LOG"
echo "  rapporto:          $OUT/rapporto.html" | tee -a "$LOG"
echo "  numeri per LaTeX:  $OUT/numeri_tesi.tex" | tee -a "$LOG"
echo "  tabelle LaTeX:     $OUT/tabelle/" | tee -a "$LOG"
echo "  figure:            $OUT/figure/ (G01-G13), $OUT/figure_descrittive/ (F01-F13)" | tee -a "$LOG"
echo "  sintesi in chiaro: $RADICE/unito/aggregato/sintesi.md" | tee -a "$LOG"
