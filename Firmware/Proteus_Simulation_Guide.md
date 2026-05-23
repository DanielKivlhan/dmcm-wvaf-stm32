# Panduan Simulasi DMCM-WVAF di Proteus
## Menggunakan Rangkaian STM32F401CD (Sesuai Skema Existing)

---

## 📐 Analisis Rangkaian (Dari Skema)

| Komponen | Nilai | Fungsi dalam DMCM-WVAF |
|---|---|---|
| **U2 STM32F401CD** | — | MCU utama |
| **RV1** | 1kΩ | Sensor 1 (simulasi ADC — input PA0) |
| **RV2** | 1kΩ | Sensor 2 (simulasi ADC — input PA1) |
| **D1 LED-RED** | — | Indikator WARNING / DANGER |
| **D2 LED-GREEN** | — | Indikator NORMAL |
| **R1** | 330Ω | Current limiting D1 |
| **R2** | 300Ω | Current limiting D2 |
| **R3** | 1kΩ | Base resistor Q1 (driver relay) |
| **Q1 BC547** | NPN | Transistor driver relay |
| **RL1** | 3.3V | Relay — aktuator darurat (buzzer/alarm) |
| **D3 1N4007** | — | Flyback diode proteksi relay |
| **BAT1** | 12V | Sumber daya buzzer/speaker via relay |
| **Virtual Terminal** | — | Monitor output UART |

---

## 🗺️ Pin Mapping STM32F401CD

```
STM32F401CD Pin    │ Komponen              │ Fungsi DMCM-WVAF
───────────────────┼───────────────────────┼─────────────────────────
PA0 (ADC1_IN0)     │ RV1 wiper             │ Sensor utama WVAF
PA1 (ADC1_IN1)     │ RV2 wiper             │ Sensor sekunder / threshold
PB0 (GPIO_OUT)     │ R1 (330Ω) → D1 RED   │ LED indikator WARNING/DANGER
PB1 (GPIO_OUT)     │ R2 (300Ω) → D2 GREEN │ LED indikator NORMAL
PB8 (GPIO_OUT)     │ R3 (1kΩ) → Q1 base  │ Driver relay (aktuator darurat)
PA9 (USART1_TX)    │ Virtual Terminal RXD  │ Output data UART
PA10 (USART1_RX)   │ Virtual Terminal TXD  │ Input UART
```

---

## ⚡ Langkah 1 — Konfigurasi STM32CubeIDE

### 1.1 Buat Project

1. **File → New → STM32 Project**
2. Search: `STM32F401CD`
3. Pilih **STM32F401CDUx** atau **STM32F401CDTx**
4. Nama project: `DMCM_WVAF_F401`
5. Language: **C** → Finish

### 1.2 Konfigurasi .ioc (CubeMX)

```
CLOCK:
  - RCC → HSI Clock (8 MHz internal)
  - HCLK: 84 MHz (PLL aktif)

ADC1:
  - Channel 0 (PA0) → aktifkan, Mode: Single-ended
  - Channel 1 (PA1) → aktifkan
  - Scan Mode: ENABLE
  - Continuous Conversion: ENABLE
  - Resolution: 12-bit

GPIO:
  - PB0 → GPIO_Output (LED RED)
  - PB1 → GPIO_Output (LED GREEN)
  - PB8 → GPIO_Output (RELAY via Q1)
  - Default level semua: LOW

USART1:
  - Mode: Asynchronous
  - Baud Rate: 9600 bps
  - PA9 = TX, PA10 = RX
  - NVIC: disable (polling saja)

TIM2 (Zona Kritis SBTP — 5ms):
  - Clock Source: Internal Clock
  - Prescaler: 83  → 84MHz / 84 = 1MHz
  - Counter Period: 4999 → 1MHz / 5000 = 200Hz = 5ms
  - NVIC: TIM2 Global Interrupt → ENABLE

→ Generate Code
```

---

## ⚡ Langkah 2 — Firmware `main.c`

Ganti seluruh isi `main.c` dengan kode berikut:

```c
/* ============================================================
 * DMCM-WVAF Firmware — STM32F401CD
 * Rangkaian: RV1/RV2 (sensor) + LED RED/GREEN + Relay BC547
 * ============================================================ */
#include "main.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ============================================================
 * PARAMETER WVAF
 * ============================================================ */
#define WIN_MAX        16
#define WIN_MIN         2
#define DELTA_THRESH   200   // Threshold perubahan ADC (0-4095)

/* ============================================================
 * STATE SENSOR
 * ============================================================ */
#define STATE_NORMAL   0
#define STATE_WARNING  1
#define STATE_DANGER   2

/* ============================================================
 * PERINTAH AKTUATOR
 * ============================================================ */
#define ACT_NORMAL     0   // LED GREEN ON, RED OFF, Relay OFF
#define ACT_WARNING    1   // LED RED ON,   GREEN OFF, Relay OFF
#define ACT_DANGER     2   // LED RED ON,   GREEN OFF, Relay ON (buzzer)
#define ACT_IDLE       3   // Semua OFF

/* ============================================================
 * O(1) STATE MATRIX
 * Baris : Sensor State (0=Normal, 1=Warning, 2=Danger)
 * Kolom : System Mode  (0=Auto,   1=Manual,  2=Safe)
 * ============================================================ */
const uint8_t state_matrix[3][3] = {
/*               Auto          Manual        Safe      */
/* Normal  */ { ACT_NORMAL,  ACT_NORMAL,  ACT_IDLE   },
/* Warning */ { ACT_WARNING, ACT_WARNING, ACT_IDLE   },
/* Danger  */ { ACT_DANGER,  ACT_WARNING, ACT_IDLE   },
};

/* ============================================================
 * VARIABEL GLOBAL
 * ============================================================ */
ADC_HandleTypeDef  hadc1;
TIM_HandleTypeDef  htim2;
UART_HandleTypeDef huart1;

uint16_t adc_buf[WIN_MAX];
uint8_t  win_size      = WIN_MAX;
uint16_t prev_sample   = 0;
uint8_t  sys_mode      = 0;           // 0 = AUTO
volatile uint8_t crit_flag = 0;
char     uart_out[100];

/* ============================================================
 * WVAF — Variable-Window Adaptive Filter
 * ============================================================ */
void shift_buf(uint16_t *b, uint16_t val, uint8_t n) {
    for (int i = n-1; i > 0; i--) b[i] = b[i-1];
    b[0] = val;
}

uint16_t avg_buf(uint16_t *b, uint8_t n) {
    uint32_t s = 0;
    for (int i = 0; i < n; i++) s += b[i];
    return (uint16_t)(s / n);
}

uint16_t WVAF_Filter(uint16_t sample) {
    uint16_t delta = (sample > prev_sample) ?
                     (sample - prev_sample) : (prev_sample - sample);
    prev_sample = sample;

    win_size = (delta > DELTA_THRESH) ? WIN_MIN : WIN_MAX;

    shift_buf(adc_buf, sample, win_size);
    return avg_buf(adc_buf, win_size);
}

/* ============================================================
 * EVALUASI STATE
 * ADC 12-bit: 0-4095 dibagi 3 zona
 * ============================================================ */
uint8_t get_state(uint16_t val) {
    if (val < 1365)      return STATE_NORMAL;
    else if (val < 2730) return STATE_WARNING;
    else                 return STATE_DANGER;
}

/* ============================================================
 * KONTROL AKTUATOR
 * PB0 = LED RED | PB1 = LED GREEN | PB8 = RELAY (via Q1)
 * ============================================================ */
void actuator_set(uint8_t cmd) {
    // Reset semua
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_0, GPIO_PIN_RESET); // LED RED
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_1, GPIO_PIN_RESET); // LED GREEN
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_8, GPIO_PIN_RESET); // RELAY

    switch (cmd) {
        case ACT_NORMAL:
            HAL_GPIO_WritePin(GPIOB, GPIO_PIN_1, GPIO_PIN_SET);  // GREEN ON
            break;
        case ACT_WARNING:
            HAL_GPIO_WritePin(GPIOB, GPIO_PIN_0, GPIO_PIN_SET);  // RED ON
            break;
        case ACT_DANGER:
            HAL_GPIO_WritePin(GPIOB, GPIO_PIN_0, GPIO_PIN_SET);  // RED ON
            HAL_GPIO_WritePin(GPIOB, GPIO_PIN_8, GPIO_PIN_SET);  // RELAY ON → buzzer
            break;
        case ACT_IDLE:
        default:
            break; // semua OFF
    }
}

/* ============================================================
 * TIM2 IRQ — ZONA KRITIS SBTP (setiap 5ms)
 * ============================================================ */
void HAL_TIM_PeriodElapsedCallback(TIM_HandleTypeDef *htim) {
    if (htim->Instance == TIM2) {
        crit_flag = 1;

        /* 1. Baca ADC Channel 0 (RV1 — sensor utama) */
        ADC_ChannelConfTypeDef ch = {0};
        ch.Channel = ADC_CHANNEL_0;
        ch.Rank    = 1;
        ch.SamplingTime = ADC_SAMPLETIME_56CYCLES;
        HAL_ADC_ConfigChannel(&hadc1, &ch);
        HAL_ADC_Start(&hadc1);
        HAL_ADC_PollForConversion(&hadc1, 10);
        uint16_t raw = HAL_ADC_GetValue(&hadc1);
        HAL_ADC_Stop(&hadc1);

        /* 2. WVAF Filter */
        uint16_t filtered = WVAF_Filter(raw);

        /* 3. Evaluasi State */
        uint8_t state = get_state(filtered);

        /* 4. O(1) Matrix Lookup */
        uint8_t cmd = state_matrix[state][sys_mode];

        /* 5. Eksekusi Aktuator */
        actuator_set(cmd);

        /* 6. Kirim data ke Virtual Terminal */
        const char* state_str[] = {"NORMAL ", "WARNING", "DANGER "};
        const char* cmd_str[]   = {"GREEN  ", "RED    ", "RED+RLY", "IDLE   "};
        snprintf(uart_out, sizeof(uart_out),
                 "[DMCM] RAW:%4d FLT:%4d WIN:%2d | %s | CMD:%s\r\n",
                 raw, filtered, win_size, state_str[state], cmd_str[cmd]);
        HAL_UART_Transmit(&huart1, (uint8_t*)uart_out, strlen(uart_out), 50);
    }
}

/* ============================================================
 * MAIN
 * ============================================================ */
int main(void) {
    HAL_Init();
    SystemClock_Config();
    MX_GPIO_Init();
    MX_ADC1_Init();
    MX_TIM2_Init();
    MX_USART1_UART_Init();

    memset(adc_buf, 0, sizeof(adc_buf));

    /* Start SBTP Timer (Zona Kritis 5ms) */
    HAL_TIM_Base_Start_IT(&htim2);

    const char *hello = "=== DMCM-WVAF Ready | STM32F401CD ===\r\n";
    HAL_UART_Transmit(&huart1, (uint8_t*)hello, strlen(hello), 100);

    /* MAIN LOOP — Zona Non-Kritis */
    while (1) {
        /* Tugas non-kritis: bisa ditambah logging, display, dll.
         * Jika hang di sini, Zona Kritis (TIM2 IRQ) tetap aman. */
        HAL_Delay(50);
        crit_flag = 0;
    }
}
```

---

## ⚡ Langkah 3 — Build & Generate HEX

1. Klik **Project → Build Project** (Ctrl+B)
2. Pastikan **0 errors** di Console
3. File HEX ada di:
   ```
   Debug/DMCM_WVAF_F401.hex
   ```

---

## ⚡ Langkah 4 — Load HEX ke Proteus

1. **Double-click** komponen `STM32F401CD` (U2) di Proteus
2. Field **Program File** → klik 📁 → pilih `DMCM_WVAF_F401.hex`
3. **Crystal Frequency:** `8MHz` (atau kosongkan jika pakai HSI)
4. Klik **OK**

### Konfigurasi Virtual Terminal

Double-click Virtual Terminal → set:
```
Baud Rate  : 9600
Data Bits  : 8
Parity     : None
Stop Bits  : 1
```

---

## ⚡ Langkah 5 — Jalankan & Uji Simulasi

### Tabel Pengujian Potentiometer

| Posisi RV1 | Nilai ADC | State | LED | Relay (Q1/RL1) |
|---|---|---|---|---|
| 0% – 33% | 0 – 1364 | **NORMAL** | GREEN ON | OFF |
| 33% – 66% | 1365 – 2729 | **WARNING** | RED ON | OFF |
| 66% – 100% | 2730 – 4095 | **DANGER** | RED ON | **ON → Buzzer** |

### Output Virtual Terminal yang Diharapkan

```
=== DMCM-WVAF Ready | STM32F401CD ===
[DMCM] RAW: 800 FLT: 798 WIN:16 | NORMAL  | CMD:GREEN
[DMCM] RAW: 810 FLT: 803 WIN:16 | NORMAL  | CMD:GREEN
[DMCM] RAW:2900 FLT:1850 WIN: 2 | WARNING | CMD:RED
[DMCM] RAW:3500 FLT:3200 WIN: 2 | DANGER  | CMD:RED+RLY
[DMCM] RAW: 700 FLT: 750 WIN: 2 | NORMAL  | CMD:GREEN
[DMCM] RAW: 710 FLT: 705 WIN:16 | NORMAL  | CMD:GREEN
```

> **Perhatikan:** Saat RV1 diputar **cepat** (lonjakan), WIN menyusut ke **2** (respons darurat). Saat stabil, WIN kembali ke **16** (noise terfilter).

### Cara Uji Relay & Buzzer

1. Putar RV1 penuh ke kanan (DANGER state)
2. **LED RED** menyala
3. **Q1 BC547** saturasi → **RL1 relay** aktif
4. Kontak relay menghubungkan **BAT1 (12V)** ke buzzer/speaker
5. Buzzer berbunyi ✅

### Cara Buktikan SBTP

1. Tambahkan `HAL_Delay(2000)` di dalam `while(1)` zona non-kritis
2. Jalankan simulasi
3. LED **tetap merespons setiap 5ms** meski loop utama tertunda → **SBTP terbukti** ✅

---

## 🐛 Troubleshooting

| Masalah | Solusi |
|---|---|
| MCU tidak start | Re-load file HEX di properties U2 |
| ADC selalu 0 | Pastikan RV1 wiper → PA0, supply RV1 ke 3.3V & GND |
| LED tidak menyala | Cek PB0/PB1 sebagai GPIO_Output di CubeMX |
| Relay tidak aktif | Cek PB8 → R3 → base Q1; cek supply 3.3V ke kolektor RL1 |
| Virtual Terminal kosong | Cek 9600bps; PA9=TX→Terminal RXD; PA10=RX→Terminal TXD |
| Buzzer tidak bunyi | Cek koneksi BAT1 12V → kontak relay → buzzer → GND |

---

## 📊 Peta DMCM-WVAF ke Komponen Rangkaian

```
RV1 (PA0) ──► WVAF Filter ──► State Evaluator ──► O(1) Matrix
                                                        │
                           ┌────────────────────────────┤
                           │                            │
                     STATE_NORMAL                 STATE_WARNING/DANGER
                           │                            │
                    D2 GREEN (PB1)              D1 RED (PB0)
                                                        │
                                              STATE_DANGER only:
                                              PB8 → Q1 BC547 → RL1
                                              → BAT1 12V → Buzzer 🔔

SBTP (TIM2 5ms IRQ): Semua proses di atas berjalan DETERMINISTIK
```

---

*Panduan Simulasi DMCM-WVAF | STM32F401CD | Sesuai Skema Existing | v2.0*
