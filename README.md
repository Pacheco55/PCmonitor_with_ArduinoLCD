<p align="center">
  <img width="608" height="436" alt="Image" src="https://github.com/user-attachments/assets/abda6b76-132a-49b0-b68e-197fde05b8ee">
</p>

![Windows](https://img.shields.io/badge/OS-Windows%2010%20|%2011-blue?style=for-the-badge&logo=windows)
![PowerShell](https://img.shields.io/badge/Script-PowerShell%205.1+-5391FE?style=for-the-badge&logo=powershell&logoColor=white)
![Arduino](https://img.shields.io/badge/Hardware-Arduino%20Uno-00979D?style=for-the-badge&logo=arduino&logoColor=white)
![LCD](https://img.shields.io/badge/Display-16x2%20LCD-green?style=for-the-badge)

**Sistema de monitoreo de hardware en tiempo real con visualización en LCD 16x2**

*Monitor profesional de métricas del sistema desarrollado por PIXELBITS Studios. Muestra CPU, GPU, RAM, red, batería y hora en tu Arduino Uno.*

---

## **Requisitos**

| Componente | Especificación |
|:-----------|:---------------|
| **Hardware** | Arduino Uno R3 + LCD Keypad Shield 16x2 |
| **Sistema** | Windows 10/11 con PowerShell 5.1+ |
| **GPU** | NVIDIA (opcional, solo para métricas GPU) |

<div style="display: flex; gap: 10px; justify-content: center;">
  <img src="https://github.com/user-attachments/assets/9a5c6260-c550-4c3a-a1b2-ff9dc2f4426d" alt="Descripción imagen 1" width="30%" height="auto">
  <img src="https://github.com/user-attachments/assets/74e688ca-3607-4dfe-b2d7-7f8f533e1fb2" alt="Descripción imagen 2" width="40%" height="auto">
</div>

## **Instalación Rápida**

### **Paso 1: Arduino**

Abre `monitor_display.ino` en Arduino IDE, selecciona placa "Arduino Uno" y puerto COM correcto, presiona "Subir" y cierra Arduino IDE.

### **Paso 2: Configurar Puerto**

Edita `windows_bridge.ps1` línea 20:
```powershell
$puertoCOM = "COM5"   # Tu puerto real
```

**Encontrar puerto**: Administrador de Dispositivos → Puertos (COM y LPT)

### **Paso 3: Auto-Arranque**

Abre PowerShell como Administrador:
```powershell
.\install_autostart.ps1
```

Responde `s` cuando pregunte si deseas iniciar ahora.

---

## **Controles**

| Botón | Métrica |
|:------|:--------|
| **(Sin pulsar)** | Hora y Fecha |
| **UP** | CPU % + Temperatura °C |
| **DOWN** | GPU % + VRAM MB |
| **RIGHT** | Batería % + Estado |
| **LEFT** | Red Descarga/Subida Mbps |
| **SELECT** | RAM % |

---

## **Comandos Útiles**

**Iniciar monitor**
```powershell
Start-ScheduledTask -TaskName "MonitorHardwareArduino"
```

**Detener monitor**
```powershell
Stop-ScheduledTask -TaskName "MonitorHardwareArduino"
```

**Ver log en tiempo real**
```powershell
Get-Content .\monitor_hw.log -Wait -Tail 20
```

**Desinstalar**
```powershell
.\uninstall_autostart.ps1
```

---

## **Problemas Comunes**

**LCD muestra "Esperando PC..."**

Verifica puerto COM en `windows_bridge.ps1`, cierra Arduino IDE completamente y revisa el log con `Get-Content .\monitor_hw.log -Tail 20`.

**GPU muestra "N/A"**

Solo funciona con GPU NVIDIA. Verifica con `nvidia-smi` en PowerShell.

**Error de política de ejecución**
```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

**Tarea no arranca en laptop**

El instalador ya corrige esto. Si persiste, ejecuta nuevamente `.\install_autostart.ps1`.

---

## **Créditos**

### **Desarrollo Principal**

**PIXELBITS Studios**
*Innovación en tecnología embebida*
*Especialistas en IoT y sistemas de monitoreo*

### **Lead Developer**

**Julio Pacheco**
*Arquitecto de software y especialista en microcontroladores*

---

## **Licencia**

Licencia MIT - uso personal y educativo libre.

---

<div align="center">

### **Desarrollado por PIXELBITS Studios**

*Transformando datos del sistema en visualización tangible*

**[Instagram](https://www.instagram.com/pixelbits_studios/) | [Twitch](https://www.twitch.tv/pixelbits_studio/about) | [GitHub](https://github.com/Pacheco55/PIXELBITS-Studio-blog/tree/HTMLpbsb)**

---

*Monitor Hardware Arduino - Monitoreo de hardware en tiempo real*

</div>
