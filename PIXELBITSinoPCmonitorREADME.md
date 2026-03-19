# Monitor Hardware Arduino - PIXELBITS Edition

![Windows](https://img.shields.io/badge/OS-Windows%2010%20|%2011-blue?style=for-the-badge&logo=windows)
![PowerShell](https://img.shields.io/badge/Script-PowerShell%205.1+-5391FE?style=for-the-badge&logo=powershell&logoColor=white)
![Arduino](https://img.shields.io/badge/Hardware-Arduino%20Uno-00979D?style=for-the-badge&logo=arduino&logoColor=white)
![LCD](https://img.shields.io/badge/Display-16x2%20LCD-green?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen?style=for-the-badge)

**Sistema de monitoreo de hardware en tiempo real para PC con visualización en LCD 16x2**

*Solución completa desarrollada por PIXELBITS Studios que transforma tu Arduino Uno en un monitor profesional de métricas del sistema, mostrando CPU, GPU, RAM, red, batería y hora en tiempo real mediante comunicación serial optimizada.*

---

## **Características Principales**

**Monitoreo Completo del Sistema**
Uso de CPU con temperatura en grados Celsius, uso de GPU con VRAM utilizada en MB, porcentaje de RAM en uso, velocidad de red (descarga/subida en Mbps), estado de batería con indicador de carga y hora/fecha en tiempo real.

**Interfaz Interactiva**
Navegación mediante 6 botones del LCD Keypad Shield, cambio instantáneo entre métricas sin latencia, actualización en tiempo real cada segundo y diseño optimizado para pantalla 16x2.

**Auto-Arranque Inteligente**
Configuración automática en el inicio de Windows, ejecución silenciosa en segundo plano, reconexión automática tras desconexión USB y logging completo de actividad del sistema.

**Comunicación Serial Robusta**
Protocolo personalizado con delimitadores, baudrate optimizado a 115200 bps, manejo de errores y reconexión automática y buffer de datos para estabilidad.

---

## **Requisitos del Sistema**

### **Hardware Necesario**

| Componente | Especificación |
|:-----------|:---------------|
| **Microcontrolador** | Arduino Uno R3 con cable USB |
| **Display** | LCD Keypad Shield 16x2 (basado en HD44780) |
| **Conexión** | Puerto USB disponible en PC |

### **Software y Drivers**

| Componente | Versión Requerida |
|:-----------|:------------------|
| **Sistema Operativo** | Windows 10 / 11 |
| **PowerShell** | 5.1 o superior |
| **Arduino IDE** | 1.8.5+ (solo para carga inicial) |
| **Drivers GPU** | NVIDIA (opcional, solo para métricas GPU/VRAM) |

**Nota**: Las métricas de GPU solo funcionan con tarjetas NVIDIA que tengan `nvidia-smi` disponible. El resto del sistema funciona sin GPU NVIDIA.

---

## **Estructura del Proyecto**

```
Monitor_Hardware_Arduino/
├── monitor_display/
│   └── monitor_display.ino      # Firmware Arduino (Control LCD)
├── windows_bridge.ps1           # Script principal de extracción de datos
├── install_autostart.ps1        # Instalador de auto-arranque
├── uninstall_autostart.ps1      # Desinstalador de auto-arranque
└── monitor_hw.log              # Log de actividad (generado automáticamente)
```

---

## **Instalación**

### **Paso 1: Cargar Firmware en Arduino**

**Abrir el sketch**
```
Archivo → Abrir → monitor_display.ino
```

**Configurar conexión**
```
Herramientas → Placa → Arduino Uno
Herramientas → Puerto → COMx (el que corresponda)
```

**Subir el firmware**
Presiona el botón "Subir" (→). El LCD mostrará:
```
HW Monitor v2.0
Esperando PC...
```

**Importante**: Cierra el Arduino IDE después de cargar. El Monitor Serial bloquea el puerto COM.

### **Paso 2: Configurar Puerto Serial**

Abre `windows_bridge.ps1` y edita la línea 20:

```powershell
$puertoCOM = "COM5"   # Actualiza con tu puerto real
```

**¿Cómo saber mi puerto COM?**
```
Panel de Control → Administrador de Dispositivos → Puertos (COM y LPT)
```
Busca "Arduino Uno" y anota el número COM.

### **Paso 3: Activar Auto-Arranque**

Abre PowerShell como **Administrador** en la carpeta del proyecto:

```powershell
.\install_autostart.ps1
```

El instalador preguntará:
```
¿Deseas iniciar el monitor ahora? (s/n):
```

Responde `s` para arranque inmediato.

**Verificación de instalación**
```powershell
Get-ScheduledTask -TaskName "MonitorHardwareArduino"
```

Debe aparecer con estado "Ready".

---

## **Uso del Sistema**

### **Navegación por Métricas**

| Botón | Métrica Mostrada |
|:------|:-----------------|
| **(Sin pulsar)** | Hora y Fecha actual |
| **UP** | Uso CPU % + Temperatura °C |
| **DOWN** | Uso GPU % + VRAM usada (MB) |
| **RIGHT** | Batería % + Estado (Cargando/En uso) |
| **LEFT** | Red: Descarga / Subida (Mbps) |
| **SELECT** | RAM en uso % |

### **Ejemplo de Visualización**

```
Línea 1: CPU:  23% 41°C
Línea 2: GPU:  55% 4096M

Línea 1: Bat:  98% [+]
Línea 2: Net: 5.2/1.1Mb

Línea 1: RAM:  61%
Línea 2: 19/03 10:41:05
```

---

## **Comandos PowerShell**

### **Gestión del Servicio**

**Iniciar monitor manualmente**
```powershell
Start-ScheduledTask -TaskName "MonitorHardwareArduino"
```

**Detener monitor**
```powershell
Stop-ScheduledTask -TaskName "MonitorHardwareArduino"
```

**Ver estado actual**
```powershell
Get-ScheduledTaskInfo -TaskName "MonitorHardwareArduino"
```

**Probar script directamente**
```powershell
powershell.exe -ExecutionPolicy Bypass -File .\windows_bridge.ps1
```

### **Diagnóstico y Logs**

**Ver log en tiempo real**
```powershell
Get-Content .\monitor_hw.log -Wait -Tail 20
```

**Ver últimas 50 líneas del log**
```powershell
Get-Content .\monitor_hw.log -Tail 50
```

**Limpiar log**
```powershell
Clear-Content .\monitor_hw.log
```

### **Desinstalación**

**Remover auto-arranque**
```powershell
.\uninstall_autostart.ps1
```

**Desinstalación manual**
```powershell
Unregister-ScheduledTask -TaskName "MonitorHardwareArduino" -Confirm:$false
```

---

## **Resolución de Problemas**

### **El LCD muestra "Esperando PC..." indefinidamente**

**Causa**: Puerto COM incorrecto o Serial Monitor abierto.

**Solución**:
1. Verifica el puerto en `windows_bridge.ps1`:
```powershell
$puertoCOM = "COM5"   # Debe coincidir con el Administrador de Dispositivos
```

2. Cierra el Arduino IDE completamente (especialmente el Serial Monitor).

3. Verifica el log:
```powershell
Get-Content .\monitor_hw.log -Tail 20
```

### **La tarea aparece como "Queued" y nunca arranca**

**Causa**: Restricciones de energía en laptops.

**Solución**: El script `install_autostart.ps1` ya incluye la corrección. Si persiste:
```powershell
$task = Get-ScheduledTask -TaskName "MonitorHardwareArduino"
$task.Settings.DisallowStartIfOnBatteries = $false
$task.Settings.StopIfGoingOnBatteries = $false
$task | Set-ScheduledTask
```

### **GPU muestra "N/A" o "--"**

**Causa**: No hay GPU NVIDIA o `nvidia-smi` no está disponible.

**Solución**:
1. Verifica que tienes GPU NVIDIA instalada:
```powershell
nvidia-smi
```

2. Si no funciona, reinstala los drivers NVIDIA más recientes desde [nvidia.com](https://www.nvidia.com/Download/index.aspx)

3. Si no tienes GPU NVIDIA, las métricas CPU/RAM/RED/BAT funcionan normalmente.

### **Error de política de ejecución**

**Causa**: PowerShell bloquea scripts no firmados.

**Solución**:
```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

### **Desconexión frecuente del Arduino**

**Causa**: Cable USB defectuoso o puerto USB inestable.

**Solución**:
1. Usa un cable USB de calidad con capacidad de datos (no solo carga).
2. Conecta directamente a puertos USB de la placa madre (evita hubs).
3. Verifica el log para patrones de desconexión.

---

## **Protocolo Serial Avanzado**

### **Formato de Trama**

El PC envía una trama por segundo con el siguiente formato:

```
<HH:MM:SS|DD/MM/YYYY|CPU%|CPUTemp|GPU%|VRAM_MB|Bat%|BatEst|NetDL|NetUL|RAM%>
```

**Ejemplo de trama real**:
```
<10:41:05|19/03/2026|23|41|55|4096|98|1|5.20|1.10|61>
```

### **Especificación de Campos**

| Campo | Descripción | Tipo | Ejemplo |
|:------|:------------|:-----|:--------|
| `HH:MM:SS` | Hora actual | String | 10:41:05 |
| `DD/MM/YYYY` | Fecha actual | String | 19/03/2026 |
| `CPU%` | Uso del procesador | Int | 23 |
| `CPUTemp` | Temperatura CPU en °C | Int | 41 |
| `GPU%` | Uso de GPU | Int | 55 |
| `VRAM_MB` | VRAM usada en MB | Int | 4096 |
| `Bat%` | Carga de batería | Int | 98 |
| `BatEst` | Estado batería (1=Cargando, 0=En uso) | Int | 1 |
| `NetDL` | Descarga en Mbps | Float | 5.20 |
| `NetUL` | Subida en Mbps | Float | 1.10 |
| `RAM%` | RAM en uso % | Int | 61 |

### **Variables Configurables**

En `windows_bridge.ps1`:

```powershell
$puertoCOM       = "COM5"    # Puerto serial del Arduino
$baudRate        = 115200    # Velocidad (debe coincidir con el .ino)
$intervaloMs     = 1000      # Intervalo de envío en milisegundos
$maxReintentos   = 30        # Intentos de reconexión al arrancar
$esperaReintento = 5         # Segundos entre reintentos
```

### **Delimitadores y Parsing**

**Delimitador de inicio**: `<`
**Separador de campos**: `|`
**Delimitador de fin**: `>`

El Arduino parsea la trama usando `strtok()` para extraer cada campo y actualiza las variables correspondientes.

---

## **Características Técnicas Avanzadas**

### **Optimizaciones de Comunicación**

**Buffer Serial**
Tamaño de buffer: 128 bytes, limpieza automática antes de cada lectura, validación de delimitadores `<>` y manejo de tramas incompletas.

**Gestión de Errores**
Timeout de lectura: 100ms, reintentos automáticos de conexión, logging detallado de errores y reconexión sin pérdida de datos.

### **Extracción de Métricas**

**CPU**
```powershell
Get-Counter '\Procesador(_Total)\% de tiempo de procesador'
Get-WmiObject MSAcpi_ThermalZoneTemperature
```

**GPU (NVIDIA)**
```powershell
nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader,nounits
```

**RAM**
```powershell
Get-Counter '\Memoria\% de bytes confirmados en uso'
```

**Red**
```powershell
Get-Counter '\Interfaz de red(*)\Bytes recibidos/seg'
Get-Counter '\Interfaz de red(*)\Bytes enviados/seg'
```

**Batería**
```powershell
(Get-WmiObject -Class Win32_Battery).EstimatedChargeRemaining
(Get-WmiObject -Class Win32_Battery).BatteryStatus
```

---

## **Expansiones Futuras**

### **Funcionalidades Planificadas**

Soporte para múltiples GPUs (AMD/Intel), configuración de alertas por umbrales, exportación de logs a CSV/JSON, interfaz web complementaria y soporte para LCD 20x4 con más métricas.

### **Compatibilidad Extendida**

Soporte para Arduino Mega 2560, compatibilidad con Linux/macOS, integración con Raspberry Pi y comunicación inalámbrica (WiFi/Bluetooth).

---

## **Aplicaciones**

**Monitoreo de Sistemas**
Supervisión de servidores domésticos, monitoreo de estaciones de trabajo, control de temperaturas en overclocking y seguimiento de rendimiento en gaming.

**Proyectos Educativos**
Aprendizaje de comunicación serial, integración PC-microcontrolador, extracción de métricas del sistema y manejo de protocolos personalizados.

**Automatización**
Control de ventiladores según temperatura, alertas de sobrecarga del sistema, apagado automático por temperatura y estadísticas de uso del hardware.

---

## **Créditos**

### **Desarrollo Principal**

**PIXELBITS Studios**
*Innovación en tecnología embebida*
*Especialistas en IoT y sistemas de monitoreo*

### **Lead Developer**

**Julio Pacheco**
*Arquitecto de software y especialista en microcontroladores*
*Experto en integración de sistemas PC-Arduino*

---

## **Licencia**

Este proyecto está licenciado bajo la Licencia MIT - uso personal y educativo libre.

---

<div align="center">

### **Desarrollado por PIXELBITS Studios**

*Transformando datos del sistema en visualización tangible*

**[Instagram](https://www.instagram.com/pixelbits_studios/) | [Twitch](https://www.twitch.tv/pixelbits_studio/about) | [GitHub](https://github.com/Pacheco55/PIXELBITS-Studio-blog/tree/HTMLpbsb)**

---

*Monitor Hardware Arduino - Donde el hardware encuentra la visualización en tiempo real*

</div>