#!/usr/bin/env bash
# Lettura unita 5-25 membri delle repliche dei partecipanti (fase 2, passo 4). Per ogni
# replica, una dopo l'altra:
#   1. unisci_blocchi unisce i checkpoint dei tre blocchi di taglia (fino15, da18, da20a25:
#      295 comunita') e applica la regola del solo "Shapley", esatto fino a 18 membri e
#      Adaptive Sampling da 20 in su;
#   2. MAIN2 con MAIN2_RIPRENDI=1 trova tutte le comunita' gia' fatte e rifa' la sola analisi
#      fra comunita'; poi workspace ed export, come lancia_repliche.sh.
#
#   bash CER_repliche/unisci_repliche.sh <repliche...>     per esempio 0 1 2 ... 20
#
# Uscite con la stessa struttura dei blocchi, cosi' aggrega_repliche.py --blocco unito le legge:
#   outputs/repliche/unito/rNN/tables/        le tabelle di MAIN2
#   outputs/repliche/unito/rNN/checkpoint.mat RESULTS uniti
#   outputs/repliche/unito/rNN/workspace.mat  RESULTS, AGR, LIV, GRID, REV, SINT, ...
#   outputs/repliche/unito/rNN/export/        esporta_run_livelli
#   outputs/repliche/unito/rNN/unisci.log, main2.log
# Le repliche gia' fatte si saltano. Una riga per replica in outputs/repliche/unito/avanzamento.txt.
set -u
cd "$(dirname "$0")/.." || exit 1

OUT="outputs/repliche/unito"
mkdir -p "$OUT"

for R in "$@"; do
    NN=$(printf "%02d" "$R")
    SUF="rep${NN}_unito"
    DEST="$OUT/r$NN"
    RAD="CER_repliche/r$NN"
    if [ -f "$DEST/workspace.mat" ] && [ -d "$DEST/export" ]; then
        echo "$(date '+%F %T') r$NN gia' fatta, salto" >> "$OUT/avanzamento.txt"
        continue
    fi
    MANCA=""
    for B in fino15 da18 da20a25; do
        [ -f "outputs/repliche/$B/r$NN/checkpoint.mat" ] || MANCA="$MANCA $B"
    done
    if [ -n "$MANCA" ]; then
        echo "$(date '+%F %T') r$NN manca il checkpoint di:$MANCA, salto" >> "$OUT/avanzamento.txt"
        continue
    fi
    mkdir -p "$DEST"
    INIZIO=$(date +%s)
    echo "$(date '+%F %T') r$NN avvio" >> "$OUT/avanzamento.txt"
    # cellstr e apici singoli: matlab -batch lanciato da bash perde le virgolette doppie
    BLOCCHI="{'outputs/repliche/fino15/r$NN/checkpoint.mat','outputs/repliche/da18/r$NN/checkpoint.mat','outputs/repliche/da20a25/r$NN/checkpoint.mat'}"
    matlab -batch "addpath('CER_repliche'); addpath('outputs/workspace/strumenti'); unisci_blocchi('$RAD', $BLOCCHI, '$SUF', 25)" \
        > "$DEST/unisci.log" 2>&1
    ESITO=$?
    if [ $ESITO -eq 0 ]; then
        CMD="MAIN2; vv = intersect({'RESULTS','AGR','LIV','GRID','REV','SINT','F1','PERD','CLUS','SENS'}, who); save('$DEST/workspace.mat', vv{:}); addpath('outputs/workspace/strumenti'); esporta_run_livelli('$DEST/workspace.mat', '$DEST/export')"
        MAIN2_RIPRENDI=1 MAIN2_RADICE="$RAD" MAIN2_MAX_UTENTI=25 MAIN2_IND=1 MAIN2_CARTELLA="$SUF" \
            matlab -batch "$CMD" > "$DEST/main2.log" 2>&1
        ESITO=$?
    fi
    [ -d "outputs/tables_main2_$SUF" ] && rm -rf "$DEST/tables" && mv "outputs/tables_main2_$SUF" "$DEST/tables"
    [ -f "outputs/checkpoint_main2_$SUF.mat" ] && mv "outputs/checkpoint_main2_$SUF.mat" "$DEST/checkpoint.mat"
    [ -d "outputs/figures_main2_$SUF" ] && rm -rf "outputs/figures_main2_$SUF"
    DURATA=$(( $(date +%s) - INIZIO ))
    if [ $ESITO -eq 0 ]; then
        echo "$(date '+%F %T') r$NN fatta in $DURATA s" >> "$OUT/avanzamento.txt"
    else
        echo "$(date '+%F %T') r$NN FALLITA ($ESITO) dopo $DURATA s, vedi $DEST/*.log" >> "$OUT/avanzamento.txt"
    fi
done
