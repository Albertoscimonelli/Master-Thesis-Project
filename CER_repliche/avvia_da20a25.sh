#!/usr/bin/env bash
# Fase 2, passo 3: run del blocco da20a25 (21 repliche, r00 per prima), in una finestra Git
# Bash fuori da VS Code, cosi' VS Code si puo' chiudere senza fermare il run. Finche' la
# finestra e' aperta il PC non va in sospensione per inattivita' (veglia.ps1, accanto a questo
# file); chiudere il coperchio o premere il tasto lo sospende lo stesso.
# Rilanciato dopo un'interruzione salta le repliche finite (workspace.mat + export/) e riprende
# quelle il cui checkpoint sta in outputs/checkpoint_main2_repNN_da20a25.mat.
# Avvio da PowerShell, fuori da VS Code:
#   Start-Process 'C:\Program Files\Git\git-bash.exe' -ArgumentList '--cd=C:\Users\scimo\desktop\Project -c "bash CER_repliche/avvia_da20a25.sh"'
# Stato del run: bash CER_repliche/stato_run.sh
QUI="$(cd "$(dirname "$0")" && pwd)"
cd /c/Users/scimo/desktop/Project || exit 1
WINPID=$(cat /proc/$$/winpid)
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden \
    -File "$(cygpath -w "$QUI/veglia.ps1")" -padre "$WINPID" &
VEGLIA=$!
echo "Run da20a25 (ri)avviato $(date '+%F %T'); PC tenuto sveglio finche' questa finestra e' aperta."
echo "Non chiudere il coperchio: la sospensione da coperchio ferma il calcolo."
echo "Avanzamento: outputs/repliche/da20a25/avanzamento.txt"
bash CER_repliche/lancia_repliche.sh da20a25 20 25 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20
ESITO=$?
kill "$VEGLIA" 2>/dev/null
echo
echo "FINITO $(date '+%F %T') (esito $ESITO). Ultime righe dell'avanzamento:"
tail -25 outputs/repliche/da20a25/avanzamento.txt
read -r -p "Premi Invio per chiudere la finestra. "
