param([int]$padre)
# Tiene sveglio il PC (niente sospensione per inattivita') finche' vive il processo $padre,
# la finestra Git Bash del run. Non cambia le impostazioni di alimentazione: la richiesta
# (SetThreadExecutionState) decade quando questo script finisce. Lo schermo puo' spegnersi.
$sig = '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);'
$k = Add-Type -MemberDefinition $sig -Name Veglia -Namespace Run -PassThru
$ES_CONTINUOUS      = [uint32]2147483648    # 0x80000000
$ES_SYSTEM_REQUIRED = [uint32]1
while (Get-Process -Id $padre -ErrorAction SilentlyContinue) {
    $null = $k::SetThreadExecutionState($ES_CONTINUOUS -bor $ES_SYSTEM_REQUIRED)
    Start-Sleep -Seconds 60
}
$null = $k::SetThreadExecutionState($ES_CONTINUOUS)
