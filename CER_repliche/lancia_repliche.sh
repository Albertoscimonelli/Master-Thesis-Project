#!/usr/bin/env bash
# Lancia MAIN2 su una serie di repliche dei partecipanti (CER_repliche/rNN), una dopo
# l'altra, e mette da parte cio' che serve all'analisi: tabelle, checkpoint, workspace
# (RESULTS, AGR, LIV, ...) ed export CSV lunghi.
#
#   bash CER_repliche/lancia_repliche.sh <blocco> <min_membri> <max_membri> <repliche...>
#   per esempio: bash CER_repliche/lancia_repliche.sh fino15 1 15 1 3 5 7
#                bash CER_repliche/lancia_repliche.sh da18a25 18 25 1 2
#
# Le schede delle repliche si generano prima con genera_repliche.py. Con min_membri = 1
# l'elenco e' quello di MAIN2 fino al tetto (MAIN2_MAX_UTENTI); con min_membri > 1 si
# passa a MAIN2 la selezione esplicita (MAIN2_SCHEDE) delle schede della replica con
# min_membri <= N <= max_membri, in tutti i livelli. Per ogni replica:
#   outputs/repliche/<blocco>/rNN/tables/        le tabelle di MAIN2 (tables_main2_*)
#   outputs/repliche/<blocco>/rNN/checkpoint.mat RESULTS, come il checkpoint di MAIN2
#   outputs/repliche/<blocco>/rNN/workspace.mat  RESULTS, AGR, LIV, GRID, REV, SINT, ...
#   outputs/repliche/<blocco>/rNN/export/        esporta_run_livelli
#   outputs/repliche/<blocco>/rNN/main2.log
# Se MAIN2 si ferma, si riprova una volta dal checkpoint (MAIN2_RIPRENDI=1). Se lo
# script stesso viene fermato a meta' di una replica, rilanciato con gli stessi
# argomenti salta le repliche finite e riprende quella interrotta dal checkpoint.
# Una riga per replica in outputs/repliche/<blocco>/avanzamento.txt.
set -u
cd "$(dirname "$0")/.." || exit 1

BLOCCO="$1"; MINN="$2"; MAXN="$3"; shift 3
OUT="outputs/repliche/$BLOCCO"
mkdir -p "$OUT"

selezione() {   # nomi per MAIN2_SCHEDE: CER_x_y_z, PAk/CER_..., NDk[_PAp]/CER_...
    # Solo espansioni di bash, nessun processo per file: in Git Bash basename, awk e
    # dirname per ognuna delle ~300 schede costavano 4-5 min a replica. Stesso ordine
    # e stesso risultato della versione di prima (30/10/2026).
    local rad="$1" f n nome resto a b c cartella
    local -a scelte=()
    for f in "$rad"/CER_configuration/CER_*.txt "$rad"/CER_configuration_PA/PA[1-9]*/CER_*.txt \
             "$rad"/CER_configuration_IND/ND[1-9]*/CER_*.txt; do
        [ -f "$f" ] || continue
        nome=${f##*/}; nome=${nome%.txt}                       # CER_x_y_z
        resto=${nome#CER_}
        a=${resto%%_*}; resto=${resto#*_}
        b=${resto%%_*}; resto=${resto#*_}
        c=${resto%%_*}
        n=$(( 10#$a + 10#$b + 10#$c ))
        [ "$n" -ge "$MINN" ] && [ "$n" -le "$MAXN" ] || continue
        case "$f" in
            */CER_configuration/*) scelte+=("$nome") ;;
            *) cartella=${f%/*}; scelte+=("${cartella##*/}/$nome") ;;
        esac
    done
    local IFS=';'
    echo "${scelte[*]}"
}

for R in "$@"; do
    NN=$(printf "%02d" "$R")
    SUF="rep${NN}_${BLOCCO}"
    DEST="$OUT/r$NN"
    RAD="CER_repliche/r$NN"
    if [ -f "$DEST/workspace.mat" ] && [ -d "$DEST/export" ]; then
        echo "$(date '+%F %T') r$NN gia' fatta, salto" >> "$OUT/avanzamento.txt"
        continue
    fi
    SEL=""
    if [ "$MINN" -gt 1 ]; then
        SEL=$(selezione "$RAD")
        if [ -z "$SEL" ]; then
            echo "$(date '+%F %T') r$NN nessuna scheda fra $MINN e $MAXN membri in $RAD" >> "$OUT/avanzamento.txt"
            continue
        fi
    fi
    mkdir -p "$DEST"
    CMD="MAIN2; vv = intersect({'RESULTS','AGR','LIV','GRID','REV','SINT','F1','PERD','CLUS','SENS'}, who); save('$DEST/workspace.mat', vv{:}); addpath('outputs/workspace/strumenti'); esporta_run_livelli('$DEST/workspace.mat', '$DEST/export')"
    INIZIO=$(date +%s)
    # Replica interrotta a meta' (lo script o MATLAB fermati da fuori): il checkpoint
    # di MAIN2 e' rimasto in outputs/, perche' lo si sposta solo a fine replica. Si
    # riparte da li' invece che da capo: a 25 membri una replica dura circa 3 h.
    RIPRESA=""
    LOG="$DEST/main2.log"
    if [ -f "outputs/checkpoint_main2_$SUF.mat" ]; then
        RIPRESA=1
        LOG="$DEST/main2_ripresa_avvio.log"
        echo "$(date '+%F %T') r$NN avvio dal checkpoint di un run interrotto" >> "$OUT/avanzamento.txt"
    else
        echo "$(date '+%F %T') r$NN avvio" >> "$OUT/avanzamento.txt"
    fi
    MAIN2_RIPRENDI="$RIPRESA" MAIN2_RADICE="$RAD" MAIN2_MAX_UTENTI="$MAXN" MAIN2_SCHEDE="$SEL" \
        MAIN2_IND=1 MAIN2_CARTELLA="$SUF" matlab -batch "$CMD" > "$LOG" 2>&1
    ESITO=$?
    if [ $ESITO -ne 0 ]; then
        echo "$(date '+%F %T') r$NN errore ($ESITO), riprovo dal checkpoint" >> "$OUT/avanzamento.txt"
        MAIN2_RIPRENDI=1 MAIN2_RADICE="$RAD" MAIN2_MAX_UTENTI="$MAXN" MAIN2_SCHEDE="$SEL" MAIN2_IND=1 \
            MAIN2_CARTELLA="$SUF" matlab -batch "$CMD" > "$DEST/main2_ripresa.log" 2>&1
        ESITO=$?
    fi
    [ -d "outputs/tables_main2_$SUF" ] && rm -rf "$DEST/tables" && mv "outputs/tables_main2_$SUF" "$DEST/tables"
    [ -f "outputs/checkpoint_main2_$SUF.mat" ] && mv "outputs/checkpoint_main2_$SUF.mat" "$DEST/checkpoint.mat"
    [ -d "outputs/figures_main2_$SUF" ] && rm -rf "outputs/figures_main2_$SUF"
    DURATA=$(( $(date +%s) - INIZIO ))
    if [ $ESITO -eq 0 ]; then
        echo "$(date '+%F %T') r$NN fatta in $((DURATA / 60)) min" >> "$OUT/avanzamento.txt"
    else
        echo "$(date '+%F %T') r$NN FALLITA ($ESITO) dopo $((DURATA / 60)) min, vedi $DEST/main2*.log" >> "$OUT/avanzamento.txt"
    fi
done
