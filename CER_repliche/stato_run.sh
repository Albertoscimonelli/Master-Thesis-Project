#!/usr/bin/env bash
# Stato del run da20a25: repliche fatte, replica in corso, errori veri, MATLAB vivo, RAM, stima.
cd /c/Users/scimo/desktop/Project || exit 1
D=outputs/repliche/da20a25
A=$D/avanzamento.txt
echo "ORA $(date '+%F %T')"
echo "--- avanzamento"
cat "$A"
# esito di ogni replica = la sua ultima riga di fine (dal 31/10 le fallite col limite 1000 si
# riprendono dal checkpoint, quindi una FALLITA vecchia puo' diventare fatta)
ESITI=$(grep -oE "r[0-9]{2} (fatta|FALLITA|gia' fatta)" "$A" | awk '{e[$1]=$2} END{for(r in e) print r, e[r]}' | sort)
FATTE=$(echo "$ESITI" | grep -cE " (fatta|gia')")
FALLITE=$(echo "$ESITI" | grep -c " FALLITA")
echo "--- fatte $FATTE/21, ultimo esito FALLITA (recuperate se in corso o piu' avanti): $FALLITE $(echo "$ESITI" | grep FALLITA | cut -c1-3 | tr '\n' ' ')"
echo "--- dalla ripresa del 31/10 (limite 5000):"
sed -n '/2026-10-31 16:12:38/,$p' "$A" | grep -E "fatta|FALLITA|errore" | tail -8
# minuti medi delle sole repliche fatte per intero (le riprese dal checkpoint sono piu' corte)
awk '/ avvio dal checkpoint/ {tipo[$3] = "ripresa"; next}
     / avvio$/              {tipo[$3] = "intera"; next}
     / fatta in [0-9]+ min/ {if (tipo[$3] == "intera") {s += $6; n++}}
     END {if (n) printf("media %.0f min a replica intera (%d repliche)\n", s / n, n)}' "$A"
# replica in corso: quella dell'ultima riga di avvio, se dopo quella riga non c'e' un esito
ULT=$(grep -E " r[0-9]{2} avvio" "$A" | tail -1 | awk '{print $3}')
RIGA=$(grep -nE " $ULT avvio" "$A" | tail -1 | cut -d: -f1)
if [ -n "$ULT" ] && ! tail -n +"$RIGA" "$A" | grep -qE "$ULT (fatta|FALLITA)"; then
    L=$(ls -t "$D/$ULT"/main2*.log 2>/dev/null | head -1)
    echo "--- in corso $ULT ($L)"
    grep -oE "CER [0-9]+/127" "$L" | tail -1
    echo "righe con errore/assert vere: $(grep -iE "error|assert" "$L" | grep -vc "TIR \"NaN\" e payback 0")"
    grep -iE "error|assert" "$L" | grep -v "TIR \"NaN\" e payback 0" | tail -3
fi
echo "--- processi"
# Il server di lingua dell'estensione MATLAB di VS Code e' un altro MATLAB.exe: si guarda solo
# quello del run (MAIN2 nella riga di comando). veglia[.]ps1 non trova questo stesso comando.
powershell.exe -NoProfile -Command "\$p=Get-CimInstance Win32_Process; \$m=\$p | Where-Object { \$_.Name -eq 'MATLAB.exe' -and \$_.CommandLine -match 'win64' -and \$_.CommandLine -match 'MAIN2' }; if(\$m){'MATLAB del run attivo, PID ' + \$m.ProcessId + ', ' + [math]::Round(\$m.WorkingSetSize/1MB) + ' MB'}else{'NESSUN MATLAB del run'}; if(\$p | Where-Object { \$_.Name -eq 'powershell.exe' -and \$_.CommandLine -match 'veglia[.]ps1' -and \$_.ProcessId -ne \$PID }){'veglia attiva'}else{'VEGLIA ASSENTE'}; \$o=Get-CimInstance Win32_OperatingSystem; 'RAM libera MB: ' + [math]::Round(\$o.FreePhysicalMemory/1KB); \$b=Get-CimInstance Win32_Battery; if(\$b){'Batteria stato ' + \$b.BatteryStatus + ' (2 = CA), ' + \$b.EstimatedChargeRemaining + '%'}"
