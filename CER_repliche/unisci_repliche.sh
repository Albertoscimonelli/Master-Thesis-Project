#!/usr/bin/env bash
# Lettura unita 5-25 membri di ogni replica (passo 1 del piano, docs/analisi_finale/).
#
#   bash CER_repliche/unisci_repliche.sh [repliche...]        (default: 0 1 2 ... 20)
#
# Per ogni replica NN:
#   1. unisci_blocchi.m mette insieme i RESULTS dei tre blocchi (fino15, da18, da20a25) nell'ordine
#      di elenco_schede_cer, applica la regola di un solo Shapley (esatto fino a 18, AS oltre) e
#      scrive outputs/checkpoint_main2_repNN_unito.mat;
#   2. MAIN2 con MAIN2_RIPRENDI=1 trova tutte le 295 comunita' gia' fatte e rifa' la sola analisi
#      fra comunita' (circa 30 s). Nell'analisi restano i metodi comuni a tutte le taglie: il
#      Nucleolo (solo fino a 18) esce da se' (versione B del piano);
#   3. salva workspace.mat (RESULTS, AGR, LIV, ...) ed export/ (esporta_run_livelli), come
#      lancia_repliche.sh, e sposta tabelle e checkpoint in outputs/repliche/unito/rNN/.
# Le repliche gia' fatte (workspace.mat ed export/ presenti) si saltano. Se MATLAB si ferma, la
# replica e' segnata FALLITA in outputs/repliche/unito/avanzamento.txt e si passa alla successiva;
# lo script esce con codice 1 se almeno una replica e' fallita.
set -u
cd "$(dirname "$0")/.." || exit 1

OUT="outputs/repliche/unito"
mkdir -p "$OUT"
REPLICHE=("$@")
[ ${#REPLICHE[@]} -eq 0 ] && REPLICHE=($(seq 0 20))
FALLITE=0

for R in "${REPLICHE[@]}"; do
    NN=$(printf "%02d" "$R")
    SUF="rep${NN}_unito"
    DEST="$OUT/r$NN"
    if [ -f "$DEST/workspace.mat" ] && [ -f "$DEST/export/comunita.csv" ]; then
        echo "$(date '+%F %T') r$NN gia' fatta, salto" >> "$OUT/avanzamento.txt"
        continue
    fi
    MANCA=""
    for B in fino15 da18 da20a25; do
        [ -f "outputs/repliche/$B/r$NN/checkpoint.mat" ] || MANCA="$MANCA $B"
    done
    if [ -n "$MANCA" ]; then
        echo "$(date '+%F %T') r$NN FALLITA: manca il checkpoint di$MANCA" | tee -a "$OUT/avanzamento.txt"
        FALLITE=$((FALLITE + 1))
        continue
    fi
    mkdir -p "$DEST"
    INIZIO=$(date +%s)
    echo "$(date '+%F %T') r$NN avvio" >> "$OUT/avanzamento.txt"

    FILE="{'outputs/repliche/fino15/r$NN/checkpoint.mat', 'outputs/repliche/da18/r$NN/checkpoint.mat', 'outputs/repliche/da20a25/r$NN/checkpoint.mat'}"
    matlab -batch "addpath('CER_repliche'); addpath('outputs/workspace/strumenti'); unisci_blocchi('CER_repliche/r$NN', $FILE, '$SUF', 25)" \
        > "$DEST/unisci.log" 2>&1
    ESITO=$?
    if [ $ESITO -eq 0 ]; then
        CMD="MAIN2; vv = intersect({'RESULTS','AGR','LIV','GRID','REV','SINT','F1','PERD','CLUS','SENS'}, who); save('$DEST/workspace.mat', vv{:}); addpath('outputs/workspace/strumenti'); esporta_run_livelli('$DEST/workspace.mat', '$DEST/export')"
        MAIN2_RIPRENDI=1 MAIN2_RADICE="CER_repliche/r$NN" MAIN2_MAX_UTENTI=25 MAIN2_SCHEDE="" MAIN2_IND=1 \
            MAIN2_CARTELLA="$SUF" matlab -batch "$CMD" > "$DEST/main2.log" 2>&1
        ESITO=$?
    fi
    [ -d "outputs/tables_main2_$SUF" ] && rm -rf "$DEST/tables" && mv "outputs/tables_main2_$SUF" "$DEST/tables"
    [ -f "outputs/checkpoint_main2_$SUF.mat" ] && mv "outputs/checkpoint_main2_$SUF.mat" "$DEST/checkpoint.mat"
    [ -d "outputs/figures_main2_$SUF" ] && rm -rf "outputs/figures_main2_$SUF"
    DURATA=$(( $(date +%s) - INIZIO ))
    if [ $ESITO -eq 0 ] && [ -f "$DEST/export/comunita.csv" ]; then
        echo "$(date '+%F %T') r$NN fatta in ${DURATA} s" >> "$OUT/avanzamento.txt"
    else
        rm -f "$DEST/workspace.mat"          # la replica non risulti fatta al prossimo lancio
        echo "$(date '+%F %T') r$NN FALLITA ($ESITO) dopo ${DURATA} s, vedi $DEST/unisci.log e main2.log" \
            | tee -a "$OUT/avanzamento.txt"
        FALLITE=$((FALLITE + 1))
    fi
done
[ $FALLITE -eq 0 ] || { echo "unisci_repliche: $FALLITE repliche fallite"; exit 1; }
