# =============================================================================
#  windows_bridge.ps1
#  Monitor de Hardware -- Puente PC -> Arduino (LCD Keypad Shield 16x2)
#  Desarrollado por : JULIO PACHECO
# =============================================================================
#
#  PROTOCOLO SERIAL:
#    Trama enviada cada segundo con formato:
#    <Hora|Fecha|CPU%|CPUTemp|GPU%|VRAM_MB|Bat%|BatEst|NetDL|NetUL|RAM%>
#
#  REQUISITOS:
#    - NVIDIA GPU con drivers (nvidia-smi en el PATH o ruta absoluta)
#    - Arduino corriendo monitor_display.ino
#    - PowerShell 5.1+ (viene con Windows 10/11)
#    - Permisos de ejecucion:
#        Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
#
# =============================================================================
# -- CONFIGURACION -- EDITA AQUI ----------------------------------------------
$puertoCOM   = "COM5"      # <-- pon tu puerto, ej. "COM3", "COM4"
$baudRate    = 115200
$intervaloMs = 1000        # ms entre envios (1 segundo recomendado)

# Reintentos de conexion al puerto COM (para auto-arranque al encender)
$maxReintentos   = 30     # 30 intentos x 5 s = hasta 2.5 minutos esperando Arduino
$esperaReintento = 5      # segundos entre reintentos

# Ruta a nvidia-smi (deja $null para buscarlo en el PATH automaticamente)
$nvidiaSmiPath = $null    # ej. "C:\Windows\System32\nvidia-smi.exe"

# Archivo de log (junto al script, util cuando corre en modo oculto)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$logFile   = Join-Path $scriptDir "monitor_hw.log"
# =============================================================================

# -- Funcion de log (escribe en consola y en archivo) -------------------------
function Write-Log {
    param([string]$Mensaje, [string]$Color = "White")
    $stamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    $linea = "[$stamp] $Mensaje"
    try { Add-Content -Path $logFile -Value $linea -ErrorAction SilentlyContinue } catch {}
    Write-Host $linea -ForegroundColor $Color
}

# -- Inicializar log ----------------------------------------------------------
try {
    $header = "=" * 60
    Add-Content -Path $logFile -Value "`n$header`n[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Monitor Hardware Arduino - Iniciando`n$header"
} catch {}

# -- Validar puerto -----------------------------------------------------------
if ($puertoCOM -eq "COMX") {
    Write-Log "[ADVERTENCIA] Puerto no configurado. Edita puertoCOM." "Yellow"
    Write-Log "              Puertos disponibles:" "Cyan"
    [System.IO.Ports.SerialPort]::GetPortNames() | ForEach-Object { Write-Log "  - $_" }
    exit 1
}

# -- Resolver nvidia-smi ------------------------------------------------------
if ($null -eq $nvidiaSmiPath) {
    $found = Get-Command "nvidia-smi" -ErrorAction SilentlyContinue
    if ($found) {
        $nvidiaSmiPath = $found.Source
    } else {
        $candidatos = @(
            "C:\Windows\System32\nvidia-smi.exe",
            "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe",
            "$env:SystemRoot\System32\nvidia-smi.exe"
        )
        foreach ($c in $candidatos) {
            if (Test-Path $c) { $nvidiaSmiPath = $c; break }
        }
    }
}

if ($null -ne $nvidiaSmiPath) {
    Write-Log "[OK] nvidia-smi: $nvidiaSmiPath" "Green"
} else {
    Write-Log "[WARN] nvidia-smi no encontrado. GPU mostrara N/A." "Yellow"
}

# -- FUNCION: Uso y temperatura CPU -------------------------------------------
function Get-CpuData {
    $proc   = Get-CimInstance -ClassName Win32_Processor
    $usoPct = [int]($proc | Measure-Object -Property LoadPercentage -Average).Average

    $tempC = $null

    # Intento 1: MSAcpi_ThermalZoneTemperature
    try {
        $tzInfo = Get-CimInstance -Namespace "root/WMI" `
            -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop
        if ($tzInfo) {
            $zona = $tzInfo | Where-Object {
                $_.CurrentTemperature -gt 2732 -and $_.CurrentTemperature -lt 4000
            } | Select-Object -First 1
            if ($zona) {
                $tempC = [int][math]::Round(($zona.CurrentTemperature / 10.0) - 273.15, 0)
            }
        }
    } catch {}

    # Intento 2: Win32_PerfFormattedData_Counters_ThermalZoneInformation
    if ($null -eq $tempC) {
        try {
            $tzPerf = Get-CimInstance `
                -ClassName Win32_PerfFormattedData_Counters_ThermalZoneInformation `
                -ErrorAction Stop
            if ($tzPerf) {
                $zona = $tzPerf | Where-Object {
                    $_.HighPrecisionTemperature -gt 2732 -and $_.HighPrecisionTemperature -lt 4000
                } | Select-Object -First 1
                if ($zona) {
                    $tempC = [int][math]::Round(($zona.HighPrecisionTemperature / 10.0) - 273.15, 0)
                }
            }
        } catch {}
    }

    # Intento 3: OpenHardwareMonitor WMI
    if ($null -eq $tempC) {
        try {
            $sensors = Get-CimInstance -Namespace "root/OpenHardwareMonitor" `
                -ClassName Sensor -ErrorAction Stop |
                Where-Object { $_.SensorType -eq "Temperature" -and $_.Name -match "CPU" }
            if ($sensors) {
                $val = ($sensors | Select-Object -First 1).Value
                if ($val -gt 0 -and $val -lt 150) { $tempC = [int][math]::Round($val, 0) }
            }
        } catch {}
    }

    # Intento 4: LibreHardwareMonitor WMI
    if ($null -eq $tempC) {
        try {
            $sensors = Get-CimInstance -Namespace "root/LibreHardwareMonitor" `
                -ClassName Sensor -ErrorAction Stop |
                Where-Object { $_.SensorType -eq "Temperature" -and $_.Name -match "CPU" }
            if ($sensors) {
                $val = ($sensors | Select-Object -First 1).Value
                if ($val -gt 0 -and $val -lt 150) { $tempC = [int][math]::Round($val, 0) }
            }
        } catch {}
    }

    if ($null -eq $tempC) { $tempC = "--" }
    return @{ Uso = $usoPct; Temp = "$tempC" }
}

# -- FUNCION: Uso GPU y consumo VRAM (NVIDIA via nvidia-smi) ------------------
function Get-GpuData {
    if ($null -eq $nvidiaSmiPath) {
        return @{ Uso = "N/A"; VRAM = "N/A" }
    }
    try {
        $raw = & $nvidiaSmiPath `
            "--query-gpu=utilization.gpu,memory.used" `
            "--format=csv,noheader,nounits" 2>$null

        if ($LASTEXITCODE -ne 0 -or $null -eq $raw) {
            return @{ Uso = "N/A"; VRAM = "N/A" }
        }
        $line = ($raw -split "`n")[0].Trim()
        if ($line -eq "") { return @{ Uso = "N/A"; VRAM = "N/A" } }

        $partes = $line -split ","
        if ($partes.Count -lt 2) { return @{ Uso = "N/A"; VRAM = "N/A" } }

        return @{
            Uso  = $partes[0].Trim()
            VRAM = $partes[1].Trim()
        }
    }
    catch {
        return @{ Uso = "N/A"; VRAM = "N/A" }
    }
}

# -- FUNCION: Bateria ----------------------------------------------------------
function Get-BatteryData {
    try {
        $bat = Get-CimInstance -ClassName Win32_Battery -ErrorAction Stop |
            Select-Object -First 1
        if ($null -eq $bat) { return @{ Pct = "N/A"; Est = "0" } }
        $pct      = [int]$bat.EstimatedChargeRemaining
        $cargando = if ($bat.BatteryStatus -in @(2, 6, 7, 8)) { 1 } else { 0 }
        return @{ Pct = $pct; Est = $cargando }
    }
    catch {
        return @{ Pct = "N/A"; Est = "0" }
    }
}

# -- FUNCION: Red (Download / Upload en Mbps) ---------------------------------
$script:netBaseline = $null
$script:netBaseTime = $null

function Get-NetworkData {
    $adapters = Get-NetAdapterStatistics |
        Where-Object { $_.ReceivedBytes -gt 0 -or $_.SentBytes -gt 0 }

    $totalRx = ($adapters | Measure-Object -Property ReceivedBytes -Sum).Sum
    $totalTx = ($adapters | Measure-Object -Property SentBytes     -Sum).Sum
    $ahora   = [datetime]::UtcNow

    if ($null -eq $script:netBaseline) {
        $script:netBaseline = @{ Rx = $totalRx; Tx = $totalTx }
        $script:netBaseTime = $ahora
        return @{ DL = "0.00"; UL = "0.00" }
    }

    $deltaSeg = ($ahora - $script:netBaseTime).TotalSeconds
    if ($deltaSeg -le 0) { $deltaSeg = 1 }

    $dlMbps = [math]::Round(($totalRx - $script:netBaseline.Rx) * 8 / $deltaSeg / 1e6, 2)
    $ulMbps = [math]::Round(($totalTx - $script:netBaseline.Tx) * 8 / $deltaSeg / 1e6, 2)

    if ($dlMbps -lt 0) { $dlMbps = 0.00 }
    if ($ulMbps -lt 0) { $ulMbps = 0.00 }

    $script:netBaseline = @{ Rx = $totalRx; Tx = $totalTx }
    $script:netBaseTime = $ahora

    return @{
        DL = "{0:F2}" -f $dlMbps
        UL = "{0:F2}" -f $ulMbps
    }
}

# -- FUNCION: RAM -------------------------------------------------------------
function Get-RamData {
    $os    = Get-CimInstance -ClassName Win32_OperatingSystem
    $total = $os.TotalVisibleMemorySize
    $libre = $os.FreePhysicalMemory
    $pct   = [int][math]::Round((($total - $libre) / $total) * 100, 0)
    return $pct
}

# -- Abrir puerto Serial con reintentos ---------------------------------------
# Al arrancar con la PC, el driver USB-Serial puede tardar en aparecer.
# El script espera hasta $maxReintentos x $esperaReintento segundos.
$port    = $null
$intento = 0

while ($null -eq $port -and $intento -lt $maxReintentos) {
    $intento++
    try {
        # Verificar primero que el puerto existe en el sistema
        $portosDisponibles = [System.IO.Ports.SerialPort]::GetPortNames()
        if ($puertoCOM -notin $portosDisponibles) {
            Write-Log "[WAIT $intento/$maxReintentos] $puertoCOM no detectado. Puertos: $($portosDisponibles -join ', '). Reintentando en ${esperaReintento}s..." "Yellow"
            Start-Sleep -Seconds $esperaReintento
            continue
        }

        $port = New-Object System.IO.Ports.SerialPort(
            $puertoCOM, $baudRate,
            [System.IO.Ports.Parity]::None, 8,
            [System.IO.Ports.StopBits]::One
        )
        $port.Encoding     = [System.Text.Encoding]::ASCII
        $port.WriteTimeout = 1000
        $port.Open()
        Write-Log "[OK] Puerto $puertoCOM abierto @ $baudRate bps." "Green"
    }
    catch {
        $port = $null
        Write-Log "[WAIT $intento/$maxReintentos] No se pudo abrir $puertoCOM : $_. Reintentando en ${esperaReintento}s..." "Yellow"
        Start-Sleep -Seconds $esperaReintento
    }
}

if ($null -eq $port) {
    Write-Log "[ERROR] No se pudo conectar al Arduino en $puertoCOM tras $maxReintentos intentos. Saliendo." "Red"
    exit 1
}

# Esperar al Arduino (reset automatico al abrir el puerto serie)
Write-Log "[INFO] Esperando reset del Arduino..." "Yellow"
Start-Sleep -Milliseconds 2000

# Llamada inicial para establecer baseline de red
$null = Get-NetworkData

# -- BUCLE PRINCIPAL ----------------------------------------------------------
Write-Log "[INFO] Enviando telemetria. Ctrl+C para salir." "Cyan"

try {
    while ($true) {
        $tsInicio = [datetime]::Now

        $hora   = Get-Date -Format "HH:mm:ss"
        $fecha  = Get-Date -Format "dd/MM/yyyy"
        $cpu    = Get-CpuData
        $gpu    = Get-GpuData
        $bat    = Get-BatteryData
        $net    = Get-NetworkData
        $ramPct = Get-RamData

        # Trama: <Hora|Fecha|CPU%|CPUTemp|GPU%|VRAM_MB|Bat%|BatEst|NetDL|NetUL|RAM%>
        $trama = "<$hora|$fecha|$($cpu.Uso)|$($cpu.Temp)|$($gpu.Uso)|$($gpu.VRAM)|$($bat.Pct)|$($bat.Est)|$($net.DL)|$($net.UL)|$ramPct>"

        try {
            $port.Write($trama)
            Write-Host "[TX] $trama" -ForegroundColor DarkGray
        }
        catch {
            Write-Log "[WARN] Error al enviar: $_. Intentando reconexion..." "Yellow"
            # Si se desconecta el Arduino en caliente, intentar reconectar
            try { $port.Close(); $port.Dispose() } catch {}
            $port = $null

            for ($r = 1; $r -le $maxReintentos; $r++) {
                Start-Sleep -Seconds $esperaReintento
                try {
                    $port = New-Object System.IO.Ports.SerialPort(
                        $puertoCOM, $baudRate,
                        [System.IO.Ports.Parity]::None, 8,
                        [System.IO.Ports.StopBits]::One
                    )
                    $port.Encoding     = [System.Text.Encoding]::ASCII
                    $port.WriteTimeout = 1000
                    $port.Open()
                    Write-Log "[OK] Reconectado a $puertoCOM." "Green"
                    Start-Sleep -Milliseconds 2000
                    break
                }
                catch {
                    $port = $null
                    Write-Log "[WAIT $r/$maxReintentos] Reconexion fallida. Reintentando..." "Yellow"
                }
            }

            if ($null -eq $port) {
                Write-Log "[ERROR] No se pudo reconectar. Saliendo." "Red"
                exit 1
            }
        }

        # Esperar el resto del intervalo
        $transcurrido = ([datetime]::Now - $tsInicio).TotalMilliseconds
        $espera = $intervaloMs - [int]$transcurrido
        if ($espera -gt 0) { Start-Sleep -Milliseconds $espera }
    }
}
finally {
    if ($null -ne $port -and $port.IsOpen) {
        $port.Close()
        $port.Dispose()
        Write-Log "[INFO] Puerto $puertoCOM cerrado correctamente." "Green"
    }
}
