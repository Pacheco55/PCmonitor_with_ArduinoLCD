# =============================================================================
#  uninstall_autostart.ps1
#  Elimina la tarea "MonitorHardwareArduino" del Programador de Tareas y
#  detiene el proceso si está corriendo en segundo plano.
#
#  USO: .\uninstall_autostart.ps1
# =============================================================================

$nombreTarea = "MonitorHardwareArduino"

Write-Host "=" * 60 -ForegroundColor DarkGray
Write-Host "  Desinstalador de Auto-arranque — Monitor Hardware Arduino" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor DarkGray
Write-Host ""

# ── Detener el proceso si está corriendo ──────────────────────────────────────
Write-Host "[INFO] Buscando proceso activo..." -ForegroundColor Yellow

$procesos = Get-Process -Name "powershell" -ErrorAction SilentlyContinue |
    Where-Object {
        try {
            $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)").CommandLine
            $cmd -match "windows_bridge"
        } catch { $false }
    }

if ($procesos) {
    foreach ($p in $procesos) {
        Write-Host "[INFO] Deteniendo proceso PID $($p.Id)..." -ForegroundColor Yellow
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
    Write-Host "[OK] Proceso detenido." -ForegroundColor Green
} else {
    Write-Host "[INFO] No hay proceso activo corriendo en segundo plano." -ForegroundColor DarkGray
}

# ── Eliminar tarea del Programador de Tareas ──────────────────────────────────
$tarea = Get-ScheduledTask -TaskName $nombreTarea -ErrorAction SilentlyContinue
if ($null -ne $tarea) {
    try {
        Unregister-ScheduledTask -TaskName $nombreTarea -Confirm:$false
        Write-Host "[OK] Tarea '$nombreTarea' eliminada del Programador de Tareas." -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] No se pudo eliminar la tarea: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[INFO] La tarea '$nombreTarea' no existe (ya estaba desinstalada)." -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "[LISTO] El monitor ya NO arrancará automáticamente." -ForegroundColor Cyan
Write-Host "        Para reinstalar: .\install_autostart.ps1" -ForegroundColor DarkGray
Write-Host ""
