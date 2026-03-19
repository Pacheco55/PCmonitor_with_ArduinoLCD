/*
 * ============================================================
 *  monitor_display.ino
 *  Arduino Uno + LCD Keypad Shield (16x2)
 *  Desarrollado por : JULIO PACHECO
 * ============================================================
 *  Protocolo Serial  : 115200 baud
 *  Trama esperada    : <Hora|Fecha|CPU%|CPUTemp|GPU%|VRAM_MB|Bat%|BatEst|NetDL|NetUL|RAM%>
 *  Ejemplo           : <08:30:45|19/03/2026|23|41|55|4096|98|1|5.2|1.1|61>
 *
 *  Estados / Botones :
 *    IDLE    – reloj + fecha (sin pulsar)
 *    UP      – CPU uso + temperatura
 *    DOWN    – GPU uso + VRAM usada (MB)
 *    RIGHT   – Batería % + estado
 *    LEFT    – Red DL / UL en Mbps
 *    SELECT  – RAM uso %
 * ============================================================
 *  REGLAS DE ESTILO:
 *   · Nunca se usa la clase String de Arduino (fragmentación SRAM)
 *   · Sólo char[], strncpy, strtok, snprintf
 *   · El display sólo se refresca si los datos cambian o hay
 *     cambio de estado → elimina el parpadeo (flickering)
 * ============================================================
 */

#include <LiquidCrystal.h>

// ── Pines LCD Keypad Shield ──────────────────────────────────────────────────
LiquidCrystal lcd(8, 9, 4, 5, 6, 7);

// ── Definición de botones ADC (divisor de voltaje) ───────────────────────────
#define btnRIGHT   0
#define btnUP      1
#define btnDOWN    2
#define btnLEFT    3
#define btnSELECT  4
#define btnNONE    5

// ── Máquina de estados ───────────────────────────────────────────────────────
enum Estado {
    IDLE,
    VISTA_CPU,
    VISTA_GPU,
    VISTA_BAT,
    VISTA_RED,
    VISTA_RAM
};

static Estado estadoActual = IDLE;

// ── Debounce de botones ──────────────────────────────────────────────────────
static const unsigned long DEBOUNCE_MS  = 200UL;
static unsigned long ultimoBoton_ms     = 0UL;
static int  ultimoBotonLeido            = btnNONE;

// ── Buffer Serial ────────────────────────────────────────────────────────────
static const uint8_t BUF_SIZE = 96;
static char rxBuf[BUF_SIZE];
static uint8_t rxIdx = 0;

// ── Campos parseados de la trama ─────────────────────────────────────────────
static char fHora    [9];    // "HH:MM:SS"
static char fFecha   [11];   // "DD/MM/YYYY"
static char fCpuPct  [5];    // "0"-"100"
static char fCpuTemp [5];    // Temperatura CPU en Celsius
static char fGpuPct  [5];    // Uso GPU %
static char fGpuVRAM [8];    // VRAM usada en MB, ej. "4096"
static char fBatPct  [5];
static char fBatEst  [3];    // "1"=cargando, "0"=descarga
static char fNetDL   [8];    // Mbps con decimal, ej "5.23"
static char fNetUL   [8];
static char fRamPct  [5];

// ── Caché del último contenido que se escribió al LCD ────────────────────────
static char lcdCache[2][17];          // 2 filas × 16 chars + '\0'
static Estado ultimoEstado = (Estado)0xFF;   // fuerza primer refresco

// ── Prototipos ────────────────────────────────────────────────────────────────
static int   leerBotones();
static void  procesarSerial();
static bool  parseTrama(char* raw);
static void  actualizarDisplay();
static void  escribirFila(uint8_t fila, const char* texto);
static void  padLinea(char* dest, const char* src, uint8_t ancho);

// =============================================================================
//  SETUP
// =============================================================================
void setup() {
    Serial.begin(115200);
    lcd.begin(16, 2);

    // ── Créditos del creador ──────────────────────────────────────────────────
    for (int i = 0; i < 5; i++) {
        lcd.setCursor(0, 0);
        lcd.print(F("Developed By :  "));
        lcd.setCursor(0, 1);
        lcd.print(F(" JULIO PACHECO  "));
        delay(555);
        lcd.clear();
        delay(200);
    }

    // ── Pantalla de espera ────────────────────────────────────────────────────
    lcd.setCursor(0, 0);
    lcd.print(F("HW Monitor v2.0 "));
    lcd.setCursor(0, 1);
    lcd.print(F("Esperando PC... "));

    // Inicializar caché como espacios en blanco
    memset(lcdCache, ' ', sizeof(lcdCache));
    for (uint8_t r = 0; r < 2; r++) lcdCache[r][16] = '\0';

    // Inicializar campos con guiones
    strncpy(fHora,    "--:--:--",   sizeof(fHora)    - 1);
    strncpy(fFecha,   "--/--/----", sizeof(fFecha)   - 1);
    strncpy(fCpuPct,  "--",        sizeof(fCpuPct)  - 1);
    strncpy(fCpuTemp, "--",        sizeof(fCpuTemp) - 1);
    strncpy(fGpuPct,  "--",        sizeof(fGpuPct)  - 1);
    strncpy(fGpuVRAM, "----",      sizeof(fGpuVRAM) - 1);
    strncpy(fBatPct,  "--",        sizeof(fBatPct)  - 1);
    strncpy(fBatEst,  "-",         sizeof(fBatEst)  - 1);
    strncpy(fNetDL,   "--.--",     sizeof(fNetDL)   - 1);
    strncpy(fNetUL,   "--.--",     sizeof(fNetUL)   - 1);
    strncpy(fRamPct,  "--",        sizeof(fRamPct)  - 1);
}

// =============================================================================
//  LOOP PRINCIPAL — completamente no bloqueante
// =============================================================================
void loop() {
    procesarSerial();    // 1) Leer trama entrante sin bloquear

    // 2) Leer botón con debounce
    unsigned long ahora = millis();
    int boton = leerBotones();

    if (boton != btnNONE && (ahora - ultimoBoton_ms) > DEBOUNCE_MS) {
        ultimoBoton_ms   = ahora;
        ultimoBotonLeido = boton;

        switch (boton) {
            case btnUP:     estadoActual = VISTA_CPU; break;
            case btnDOWN:   estadoActual = VISTA_GPU; break;
            case btnRIGHT:  estadoActual = VISTA_BAT; break;
            case btnLEFT:   estadoActual = VISTA_RED; break;
            case btnSELECT: estadoActual = VISTA_RAM; break;
            default:        estadoActual = IDLE;       break;
        }
    }

    // 3) Actualizar display (sólo si algo cambió)
    actualizarDisplay();
}

// =============================================================================
//  LECTURA DE BOTONES ANALÓGICOS
// =============================================================================
static int leerBotones() {
    int adc = analogRead(0);
    if (adc > 1000) return btnNONE;
    if (adc <  50)  return btnRIGHT;
    if (adc < 250)  return btnUP;
    if (adc < 450)  return btnDOWN;
    if (adc < 650)  return btnLEFT;
    if (adc < 850)  return btnSELECT;
    return btnNONE;
}

// =============================================================================
//  LECTURA SERIAL NO BLOQUEANTE
//  Espera trama con delimitadores '<' y '>'
// =============================================================================
static void procesarSerial() {
    static bool enTrama = false;

    while (Serial.available() > 0) {
        char c = (char)Serial.read();

        if (c == '<') {
            rxIdx   = 0;
            enTrama = true;
            continue;
        }

        if (c == '>') {
            if (enTrama && rxIdx > 0) {
                rxBuf[rxIdx] = '\0';
                parseTrama(rxBuf);
            }
            rxIdx   = 0;
            enTrama = false;
            continue;
        }

        if (enTrama && rxIdx < BUF_SIZE - 1) {
            rxBuf[rxIdx++] = c;
        }
    }
}

// =============================================================================
//  PARSER DE TRAMA
//  Formato: Hora|Fecha|CPU%|CPUTemp|GPU%|VRAM_MB|Bat%|BatEst|NetDL|NetUL|RAM%
// =============================================================================
static bool parseTrama(char* raw) {
    static const uint8_t N_CAMPOS = 11;
    char* campos[N_CAMPOS];
    uint8_t i = 0;

    char* tok = strtok(raw, "|");
    while (tok != nullptr && i < N_CAMPOS) {
        campos[i++] = tok;
        tok = strtok(nullptr, "|");
    }

    if (i < N_CAMPOS) return false;    // trama incompleta

    strncpy(fHora,    campos[0],  sizeof(fHora)    - 1);
    strncpy(fFecha,   campos[1],  sizeof(fFecha)   - 1);
    strncpy(fCpuPct,  campos[2],  sizeof(fCpuPct)  - 1);
    strncpy(fCpuTemp, campos[3],  sizeof(fCpuTemp) - 1);
    strncpy(fGpuPct,  campos[4],  sizeof(fGpuPct)  - 1);
    strncpy(fGpuVRAM, campos[5],  sizeof(fGpuVRAM) - 1);
    strncpy(fBatPct,  campos[6],  sizeof(fBatPct)  - 1);
    strncpy(fBatEst,  campos[7],  sizeof(fBatEst)  - 1);
    strncpy(fNetDL,   campos[8],  sizeof(fNetDL)   - 1);
    strncpy(fNetUL,   campos[9],  sizeof(fNetUL)   - 1);
    strncpy(fRamPct,  campos[10], sizeof(fRamPct)  - 1);

    // Nulificadores de seguridad
    fHora[8]='\0'; fFecha[10]='\0'; fCpuPct[4]='\0'; fCpuTemp[4]='\0';
    fGpuPct[4]='\0'; fGpuVRAM[7]='\0'; fBatPct[4]='\0'; fBatEst[2]='\0';
    fNetDL[7]='\0'; fNetUL[7]='\0'; fRamPct[4]='\0';

    return true;
}

// =============================================================================
//  ACTUALIZACIÓN DEL DISPLAY
//  Solo escribe en LCD si el contenido o el estado cambiaron → sin parpadeo
// =============================================================================
static void actualizarDisplay() {
    char linea0[17];
    char linea1[17];
    char tmp0[17];
    char tmp1[17];

    switch (estadoActual) {

        // ── IDLE: Hora + Fecha ────────────────────────────────────────────────
        case IDLE:
            snprintf(tmp0, sizeof(tmp0), "Hora: %s", fHora);
            snprintf(tmp1, sizeof(tmp1), "Fecha:%s", fFecha);
            break;

        // ── CPU: Uso + Temperatura ────────────────────────────────────────────
        case VISTA_CPU:
            snprintf(tmp0, sizeof(tmp0), "CPU:  %s%%", fCpuPct);
            snprintf(tmp1, sizeof(tmp1), "Temp: %s C ", fCpuTemp);
            break;

        // ── GPU: Uso % + VRAM usada (MB) ─────────────────────────────────────
        case VISTA_GPU:
            snprintf(tmp0, sizeof(tmp0), "GPU:  %s%%", fGpuPct);
            snprintf(tmp1, sizeof(tmp1), "VRAM: %sMB", fGpuVRAM);
            break;

        // ── Batería: Porcentaje + Estado ──────────────────────────────────────
        case VISTA_BAT: {
            snprintf(tmp0, sizeof(tmp0), "Bateria: %s%%", fBatPct);
            const char* estStr = (fBatEst[0] == '1') ? "Cargando" : "En uso  ";
            snprintf(tmp1, sizeof(tmp1), "%s", estStr);
            break;
        }

        // ── Red: Download / Upload ────────────────────────────────────────────
        case VISTA_RED:
            snprintf(tmp0, sizeof(tmp0), "DL: %s Mbps", fNetDL);
            snprintf(tmp1, sizeof(tmp1), "UL: %s Mbps", fNetUL);
            break;

        // ── RAM: Uso % ────────────────────────────────────────────────────────
        case VISTA_RAM:
            snprintf(tmp0, sizeof(tmp0), "RAM en uso:");
            snprintf(tmp1, sizeof(tmp1), "  %s%%", fRamPct);
            break;

        default:
            strncpy(tmp0, "                ", sizeof(tmp0));
            strncpy(tmp1, "                ", sizeof(tmp1));
            break;
    }

    // Rellenar con espacios hasta 16 chars
    padLinea(linea0, tmp0, 16);
    padLinea(linea1, tmp1, 16);

    // Sólo refrescar si cambió el estado o el contenido
    bool cambioEstado = (estadoActual != ultimoEstado);

    if (cambioEstado || strncmp(linea0, lcdCache[0], 16) != 0) {
        escribirFila(0, linea0);
        strncpy(lcdCache[0], linea0, 16);
    }
    if (cambioEstado || strncmp(linea1, lcdCache[1], 16) != 0) {
        escribirFila(1, linea1);
        strncpy(lcdCache[1], linea1, 16);
    }

    ultimoEstado = estadoActual;
}

// ── Escribe exactamente 16 caracteres en una fila sin lcd.clear() ─────────────
static void escribirFila(uint8_t fila, const char* texto) {
    lcd.setCursor(0, fila);
    lcd.print(texto);
}

// ── Rellena un buffer destino hasta 'ancho' chars con espacios ───────────────
static void padLinea(char* dest, const char* src, uint8_t ancho) {
    uint8_t len = (uint8_t)strlen(src);
    if (len > ancho) len = ancho;
    memcpy(dest, src, len);
    while (len < ancho) dest[len++] = ' ';
    dest[ancho] = '\0';
}
