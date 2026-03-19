# =============================================================================
#  install_autostart.ps1
#  Registra la tarea "MonitorHardwareArduino" en el Programador de Tareas de
#  Windows para que windows_bridge.ps1 se ejecute automáticamente al iniciar
#  sesión, sin mostrar ninguna ventana de terminal.
#
#  USO: Ejecutar UNA SOLA VEZ (con PowerShell normal, no necesita admin)
#       .\install_autostart.ps1
#
#  Para quitar el auto-arranque: .\uninstall_autostart.ps1
# =============================================================================

$nombreTarea = "MonitorHardwareArduino"
$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Definition
$scriptPath  = Join-Path $scriptDir "windows_bridge.ps1"

# Verificar que el script principal existe
if (-not (Test-Path $scriptPath)) {
    Write-Host "[ERROR] No se encontró windows_bridge.ps1 en:" -ForegroundColor Red
    Write-Host "        $scriptPath" -ForegroundColor Red
    exit 1
}

Write-Host "=" * 60 -ForegroundColor DarkGray
Write-Host "  Instalador de Auto-arranque — Monitor Hardware Arduino" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor DarkGray
Write-Host ""

# ── Eliminar tarea anterior si existe ────────────────────────────────────────
$tareaExistente = Get-ScheduledTask -TaskName $nombreTarea -ErrorAction SilentlyContinue
if ($null -ne $tareaExistente) {
    Write-Host "[INFO] Eliminando tarea anterior..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $nombreTarea -Confirm:$false
}

# ── Definir la acción: powershell.exe oculto ejecutando el script ─────────────
$accion = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""

# ── Disparador: al iniciar sesión del usuario actual ─────────────────────────
$disparador = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

# ── Configuración de la tarea ─────────────────────────────────────────────────
$config = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Hours 0) `
    -RestartCount 5 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -DontStopOnIdleEnd

# ── Principal (ejecutar con el usuario actual, sin elevar privilegios) ────────
$principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Limited

# ── Registrar la tarea ────────────────────────────────────────────────────────
try {
    Register-ScheduledTask `
        -TaskName    $nombreTarea `
        -Action      $accion `
        -Trigger     $disparador `
        -Settings    $config `
        -Principal   $principal `
        -Description "Monitoriza hardware (CPU, GPU, RAM, Red, Batería) y envía datos al Arduino via Serial." `
        -Force | Out-Null

    Write-Host "[OK] Tarea '$nombreTarea' registrada exitosamente." -ForegroundColor Green
    Write-Host ""
    Write-Host "  La próxima vez que inicies sesión, el monitor arrancará" -ForegroundColor White
    Write-Host "  automáticamente en segundo plano (sin ventana visible)." -ForegroundColor White
    Write-Host ""
    Write-Host "  Para verificar: abre el Programador de Tareas → Biblioteca" -ForegroundColor DarkGray
    Write-Host "    y busca '$nombreTarea'" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Log de depuración:" -ForegroundColor DarkGray
    Write-Host "    $(Join-Path $scriptDir 'monitor_hw.log')" -ForegroundColor DarkGray
    Write-Host ""

    # Ofrecer iniciar ahora mismo sin reiniciar
    $resp = Read-Host "  ¿Iniciar el monitor AHORA? (s/N)"
    if ($resp -match "^[sS]$") {
        Write-Host "[INFO] Iniciando tarea..." -ForegroundColor Yellow
        Start-ScheduledTask -TaskName $nombreTarea
        Write-Host "[OK] Monitor iniciado en segundo plano." -ForegroundColor Green
        Write-Host "     Conecta el Arduino y espera unos segundos." -ForegroundColor White
    }
}
catch {
    Write-Host "[ERROR] No se pudo registrar la tarea: $_" -ForegroundColor Red
    exit 1
}
