# Panduan Simulasi DMCM-WVAF di Proteus
## Menggunakan Rangkaian STM32F401CD (Sesuai Skema Existing)

---

## 📐 Analisis Rangkaian (Dari Skema)

| Komponen | Nilai | Fungsi dalam DMCM-WVAF |
|---|---|---|
| **U2 STM32F401CD** | — | MCU utama |
| **SW1 BUTTON** | — | ⬅️ Ganti RV1 — Pilih STATE_NORMAL (PA0 ≈ 0.5V) |
| **SW2 BUTTON** | — | ⬅️ Ganti RV1 — Pilih STATE_WARNING (PA0 ≈ 1.65V) |
| **SW3 BUTTON** | — | ⬅️ Ganti RV1 — Pilih STATE_DANGER (PA0 ≈ 3.0V) |
| **R4** | 5.6kΩ | Resistor seri SW1 (voltage divider NORMAL) |
| **R5** | 1kΩ | Resistor seri SW2 (voltage divider WARNING) |
| **R6** | 100Ω | Resistor seri SW3 (voltage divider DANGER) |
| **R7** | 1kΩ | Pull-down ke GND — node PA0 |
| **SW4 BUTTON** | — | ⬅️ Ganti RV2 — Threshold sekunder PA1 (opsional) |
| **R8** | 1kΩ | Voltage divider PA1 (atas) |
| **R9** | 1kΩ | Voltage divider PA1 (bawah / pull-down) |
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
STM32F401CD Pin    │ Komponen                    │ Fungsi DMCM-WVAF
───────────────────┼─────────────────────────────┼──────────────────────────────
PA1 (ADC1_IN1)     │ LM35 VOUT                   │ Sensor suhu utama WVAF
PB0 (GPIO_OUT)     │ R1 (330Ω) → D1 RED         │ LED indikator WARNING/DANGER
PB1 (GPIO_OUT)     │ R2 (300Ω) → D2 GREEN       │ LED indikator NORMAL
PB8 (GPIO_OUT)     │ R3 (1kΩ) → Q1 base        │ Driver relay (aktuator darurat)
PA9 (USART1_TX)    │ Virtual Terminal RXD        │ Output data UART
PA10 (USART1_RX)   │ Virtual Terminal TXD        │ Input UART
```

---

## 🔘 Skema Push Button Pengganti RV1 & RV2

> Potensio RV1 dan RV2 **diganti total** dengan jaringan push button + resistor.
> Setiap tombol menghasilkan tegangan analog berbeda ke pin ADC — tanpa pot sama sekali.

### Prinsip Kerja

Masing-masing push button dihubungkan seri dengan resistor berbeda, semua terhubung ke node PA0. Satu resistor pull-down (R7) menjaga tegangan ke GND saat tidak ada tombol yang ditekan.

```
3.3V
 │
 ├──[SW1]──[R4: 5.6kΩ]──┐
 │                        │
 ├──[SW2]──[R5: 1kΩ  ]──┤──── PA0 ──► STM32 ADC1_IN0
 │                        │
 └──[SW3]──[R6: 100Ω ]──┘
                          │
                       [R7: 1kΩ]  ← pull-down
                          │
                         GND
```

### Hasil Tegangan per Tombol

| Tombol | Seri R | Rumus V = 3.3×R7/(R7+Rs) | V ke PA0 | ADC (12-bit) | State |
|---|---|---|---|---|---|
| **Tidak ada** | — | 0V (pull-down ke GND) | **0.00V** | **0** | NORMAL |
| **SW1** | R4 = 5.6kΩ | 3.3×1k/(1k+5.6k) | **0.50V** | **≈ 620** | NORMAL |
| **SW2** | R5 = 1kΩ | 3.3×1k/(1k+1k) | **1.65V** | **≈ 2048** | WARNING |
| **SW3** | R6 = 100Ω | 3.3×1k/(1k+0.1k) | **3.00V** | **≈ 3723** | DANGER |

> ⚠️ **Aturan:** Tekan **satu tombol saja** dalam satu waktu. Kalau dua tombol ditekan bersamaan, tegangan akan berbeda dari yang diharapkan.

---

### Skema RV2 → SW4 (PA1 — Sensor Sekunder)

> **Catatan:** Firmware saat ini hanya membaca **PA0 (Channel 0)**. PA1 diinisialisasi tapi tidak digunakan di interrupt handler. RV2/PA1 bisa disederhanakan menjadi voltage divider tetap.

**Opsi A — Fixed Voltage Divider (Tanpa Tombol, Simple):**
```
3.3V ──[R8: 1kΩ]──┬── PA1
                  │
               [R9: 1kΩ]
                  │
                 GND

Hasil: PA1 = 1.65V → ADC ≈ 2048 (fixed, tidak berubah)
```

**Opsi B — SW4 Push Button (Jika ingin PA1 aktif di firmware):**
```
3.3V ──[SW4]──[R8: 1kΩ]──┬── PA1
                          │
                       [R9: 1kΩ] ← pull-down
                          │
                         GND

SW4 tidak ditekan → PA1 = 0V  → NORMAL
SW4 ditekan       → PA1 = 1.65V → WARNING
```

---

### Cara Pasang di Proteus

**Komponen yang dicari di Pick Devices (P):**

| Komponen | Search di Proteus | Keterangan |
|---|---|---|
| Push Button | `BUTTON` | Normally Open (NO), tipe momentary |
| Resistor | `RES` atau `R` | Ubah nilai di properties |
| 3.3V Power | `POWER` / `VCC` | Set 3.3V |
| GND | `GND` | Ground biasa |

**Langkah pemasangan:**
1. Hapus **RV1** dan **RV2** dari schematic
2. Place 3 buah **BUTTON** (SW1, SW2, SW3) untuk PA0
3. Place resistor R4=5.6kΩ, R5=1kΩ, R6=100Ω masing-masing seri dengan SW1/SW2/SW3
4. Hubungkan semua ke satu node → node tersebut ke **PA0**
5. Dari node PA0, tarik wire ke **R7=1kΩ** → GND
6. Untuk PA1: pasang R8=1kΩ dari 3.3V ke node, R9=1kΩ ke GND, node ke **PA1**

```
[3.3V]──[SW1]──[R4=5.6k]──┐
[3.3V]──[SW2]──[R5=1k  ]──┼── wire ke PA0
[3.3V]──[SW3]──[R6=100Ω]──┘
                            │
                         [R7=1k]
                            │
                          [GND]
```

### Cara Pakai saat Simulasi Berjalan

| Aksi | State Masuk | LED | Relay |
|---|---|---|---|
| Tidak tekan tombol apapun | **NORMAL** | GREEN ON | OFF |
| Tekan **SW1** | **NORMAL** | GREEN ON | OFF |
| Tekan **SW2** | **WARNING** | RED ON | OFF |
| Tekan **SW3** | **DANGER** | RED ON | **ON (Buzzer)** |

> ✅ Di Proteus, klik tombol dengan mouse saat simulasi berjalan → state langsung berubah!

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
  - RCC → HSI Clock (16 MHz internal) — TANPA PLL (Proteus-safe)
  - HCLK: 16 MHz

ADC1:
  - Channel 1 (PA1) → aktifkan, Mode: Single-ended (LM35 VOUT)
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
  - Prescaler: 15  → 16MHz / (15+1) = 1MHz
  - Counter Period: 4999 → 1MHz / (4999+1) = 200Hz = 5ms
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
    /* LM35: T(°C) = ADC × 330 / 4096  (Vref=3.3V, 12-bit)
     * NORMAL  : T < 30°C → ADC < 372
     * WARNING : T < 40°C → ADC < 496
     * DANGER  : T ≥ 40°C → ADC ≥ 496 */
    if (val < 372)      return STATE_NORMAL;
    else if (val < 496) return STATE_WARNING;
    else                return STATE_DANGER;
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

        /* 1. Baca ADC Channel 1 (PA1 — LM35 VOUT) */
        ADC_ChannelConfTypeDef ch = {0};
        ch.Channel = ADC_CHANNEL_1;  // PA1 → LM35
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

### Tabel Pengujian Suhu LM35

| Suhu LM35 | ADC (12-bit, Vref=3.3V) | State | LED | Relay (Q1/RL1) |
|---|---|---|---|---|
| T < 30°C | ADC < 372 | **NORMAL** | GREEN ON | OFF |
| 30°C ≤ T < 40°C | 372 – 495 | **WARNING** | RED ON | OFF |
| T ≥ 40°C | ADC ≥ 496 | **DANGER** | RED ON | **ON → Buzzer** |

> **Konversi:** T(°C) = ADC × 330 / 4096

### Output Virtual Terminal yang Diharapkan

```
=== DMCM-WVAF Ready | STM32F401CD ===
[DMCM] T:25 C  FLT:25  W:16  ADC: 310 | NORMAL  | Green
[DMCM] T:26 C  FLT:25  W:16  ADC: 323 | NORMAL  | Green
[DMCM] T:35 C  FLT:32  W: 2  ADC: 434 | WARNING | Red
[DMCM] T:42 C  FLT:41  W: 2  ADC: 521 | DANGER  | Red+RLY
[DMCM] T:29 C  FLT:30  W: 2  ADC: 360 | NORMAL  | Green
[DMCM] T:27 C  FLT:27  W:16  ADC: 335 | NORMAL  | Green
```

> **Perhatikan:** Saat suhu LM35 berubah cepat (lonjakan ADC > 200), WIN menyusut ke **2** (respons darurat). Saat stabil, WIN kembali ke **16** (noise terfilter).

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

## 🔄 Alternatif Pengganti Potensio (RV1/RV2)

Potensio digunakan sebagai **sumber tegangan variabel (0 – 3.3V)** untuk mensimulasikan sinyal sensor analog. Berikut alternatif yang dapat digunakan di Proteus maupun rangkaian nyata:

### Opsi 1 — Voltage Source DC (Paling Sederhana di Proteus)

| Komponen Proteus | Cara Pakai |
|---|---|
| **VSOURCE / DC Voltage Source** | Double-click → set tegangan 0V – 3.3V secara manual |
| **INTERACTIVE SOURCE** | Bisa diubah saat simulasi berjalan (klik +/− di schematic) |

```
VDC (0V–3.3V) ──► PA0 (ADC1_IN0)

Nilai tegangan → Nilai ADC:
  0.0 V → ADC ≈    0
  1.1 V → ADC ≈ 1365  (batas NORMAL/WARNING)
  2.2 V → ADC ≈ 2730  (batas WARNING/DANGER)
  3.3 V → ADC ≈ 4095
```

> ✅ **Rekomendasi untuk simulasi:** Gunakan **INTERACTIVE VOLTAGE SOURCE** (`Part: ISOURCE`) agar dapat mengubah nilai input secara langsung saat simulasi berjalan tanpa harus stop.

---

### Opsi 2 — Signal Generator / Function Generator

Gunakan komponen **VSIN / VPULSE / Function Generator** dari library Proteus untuk mensimulasikan sinyal sensor yang berubah-ubah.

| Tipe | Kegunaan |
|---|---|
| **VSIN** (Sinusoidal) | Simulasi sensor yang naik-turun periodik (misal: getaran, suara) |
| **VPULSE** (Pulsa) | Simulasi lonjakan mendadak → uji respons WVAF WIN shrink ke 2 |
| **VRAMP** (Ramp) | Simulasi nilai yang naik perlahan → uji threshold crossing |
| **VSAW** (Sawtooth) | Simulasi variasi periodik tak simetris |

**Contoh Konfigurasi VSIN untuk uji WVAF:**
```
Amplitude  : 1.65 V  (setengah swing agar tidak clip)
Offset     : 1.65 V  (offset DC agar tidak ke negatif)
Frequency  : 1 Hz    (naik-turun lambat, WIN = 16)
           : 50 Hz   (cepat → delta besar → WIN = 2)
```

---

### Opsi 3 — Voltage Divider (Resistor Tetap)

Dua resistor seri dari 3.3V ke GND. Titik tengah ke PA0.

```
3.3V ──┬── R_atas ──┬── PA0
       │            │
      GND        R_bawah
                   │
                  GND

Rumus: V_out = 3.3V × R_bawah / (R_atas + R_bawah)

Contoh nilai target:
  NORMAL  : V_out = 0.5V → R_atas=5.6kΩ, R_bawah=1kΩ
  WARNING : V_out = 1.7V → R_atas=1kΩ,   R_bawah=1kΩ
  DANGER  : V_out = 3.0V → R_atas=100Ω,  R_bawah=1kΩ
```

---

### Opsi 4 — Sensor Nyata (Untuk Rangkaian Fisik)

| Sensor | Sinyal Output | Menggantikan |
|---|---|---|
| **LDR (Light Dependent Resistor)** | Tegangan analog via voltage divider | RV1 — sensor cahaya |
| **NTC Thermistor** | Tegangan analog via voltage divider | RV1 — sensor suhu |
| **MQ-2 / MQ-135** | 0–5V (perlu level shifter ke 3.3V) | RV1 — sensor gas |
| **ACS712 (Current Sensor)** | 0–5V analog (perlu pembagi) | RV1 — sensor arus |
| **Sound Sensor (KY-037)** | Analog envelope 0–5V | RV1 — sensor suara/getaran |
| **Potensiometer fisik 10kΩ** | 0–3.3V (wiper langsung ke PA0) | Sama seperti RV1/RV2 |

> ⚠️ **Catatan:** Semua sensor bertegangan > 3.3V **wajib** menggunakan voltage divider atau level shifter sebelum masuk ke pin ADC STM32.

---

### Ringkasan Rekomendasi Pengganti RV1/RV2

| Skenario | Komponen Pengganti | Alasan |
|---|---|---|
| **Simulasi Proteus — cepat & mudah** | `INTERACTIVE VOLTAGE SOURCE` | Bisa diubah real-time |
| **Simulasi Proteus — uji WVAF** | `VSIN / VPULSE` | Bangkitkan lonjakan delta |
| **Rangkaian fisik — sensor suhu** | NTC + R divider | Analog 0–3.3V |
| **Rangkaian fisik — sensor cahaya** | LDR + R divider | Analog 0–3.3V |
| **Rangkaian fisik — sensor gas** | MQ-2 + level shifter | Perlu konversi tegangan |

---

## 📡 Penggunaan Osiloskop di Proteus

Osiloskop virtual di Proteus digunakan untuk **memverifikasi sinyal analog ADC, sinyal GPIO digital, dan sinyal UART** secara visual.

### Menambahkan Osiloskop ke Schematic

1. Di Proteus, buka menu **Debug → Oscilloscope** (atau tekan `Ctrl+O` saat simulasi berjalan)
   - Alternatif: klik ikon **OSCILLOSCOPE** di toolbar Virtual Instruments
2. Atau tambahkan via **Component Mode** → search `OSCILLOSCOPE` → place di schematic
3. Osiloskop Proteus memiliki **4 channel (A, B, C, D)** dengan warna berbeda

---

### Koneksi Probe Osiloskop

| Channel | Probe ke | Yang Diamati |
|---|---|---|
| **CH A (kuning)** | PA1 (VOUT LM35) | Sinyal analog input ADC — tegangan VOUT sensor suhu |
| **CH B (biru)** | PB0 (LED RED) | Sinyal digital GPIO — HIGH saat WARNING/DANGER |
| **CH C (merah)** | PB1 (LED GREEN) | Sinyal digital GPIO — HIGH saat NORMAL |
| **CH D (hijau)** | PB8 (Relay/Q1 base) | Sinyal relay — HIGH saat DANGER |

> 🔌 **Cara probe:** Tarik wire dari titik yang diukur → sambungkan ke terminal **A/B/C/D** di komponen OSCILLOSCOPE. Satu terminal GND osiloskop disambung ke GND rangkaian.

---

### Konfigurasi Osiloskop

Double-click komponen OSCILLOSCOPE → atur:

```
Time/Div  : 5ms/div    → untuk melihat siklus TIM2 (periode 5ms)
            10ms/div   → untuk melihat respons LED
            50ms/div   → untuk melihat perubahan state keseluruhan

Volt/Div  : 1V/div     → untuk sinyal digital 0–3.3V
(per CH)  : 0.5V/div   → untuk sinyal analog ADC yang halus

Trigger   : CH A       → trigger pada rising edge sinyal sensor
            Level: 1.1V  (batas NORMAL/WARNING)
```

---

### Apa yang Harus Diamati di Osiloskop

#### Skenario 1 — WVAF Window Size Berubah

Gunakan **VSIN** sebagai input PA0 (frekuensi tinggi → lonjakan):

```
CH A: ─────╭─╮──╭──────╮──╭─╮─────  ← Sinyal analog sensor
              │  │ delta│  │
              │  │ besar│  │
CH B: ──────────────────╭╮──────────  ← LED RED nyala saat WARNING
CH D: ──────────────────────────╭╮──  ← Relay ON saat DANGER

▲ Ketika delta ADC > 200 (DELTA_THRESH), WIN shrinks 16→2
```

#### Skenario 2 — SBTP Terbukti (TIM2 = 5ms)

Tambahkan `HAL_Delay(5000)` di `while(1)`, lalu amati:

```
CH B (LED RED):  ─╮╰─╮╰─╮╰─╮╰─╮╰──  ← Tetap toggle setiap 5ms!
                   ↑ 5ms per divisi

Bukti: TIM2 IRQ tidak terhalangi HAL_Delay di main loop.
```

#### Skenario 3 — Threshold Crossing (ADC State Change)

Gunakan **VRAMP** (0→3.3V naik perlahan):

```
CH A: ────────────────────────────╱  ← Ramp naik
CH C: ╌╌╌╌╌╌╌╌╌╌╌╮╰╌╌╌╌╌╌╌╌╌╌╌╌    ← GREEN OFF di 1.1V
CH B: ╌╌╌╌╌╌╌╌╌╌╌╭╮╌╌╌╌╌╌╌╌╌╌╌╮╰   ← RED ON di 1.1V, OFF di 2.2V? Tidak
                                      ← RED tetap ON di WARNING & DANGER
CH D: ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╭╮    ← Relay ON setelah 2.2V (DANGER)

Threshold:
  1.1V  ─── NORMAL/WARNING boundary (ADC ≈ 1365)
  2.2V  ─── WARNING/DANGER boundary (ADC ≈ 2730)
```

---

### Tips Osiloskop Proteus

| Tip | Cara |
|---|---|
| **Freeze display** | Klik tombol **PAUSE** di window osiloskop saat simulasi berjalan |
| **Zoom horizontal** | Geser slider **TIME/DIV** ke kiri (zoom in) |
| **Ukur periode TIM2** | Set Time/Div = 1ms/div → hitung 5 divisi = 5ms |
| **Export waveform** | Klik **File → Export Graph** di window osiloskop (format CSV/BMP) |
| **Multi-probe satu net** | Klik wire → kanan → Add Probe Label → sambung ke CH berbeda |
| **Cursor pengukuran** | Klik ikon **cursor** di osiloskop → drag untuk ukur ΔT dan ΔV |

---

### Contoh Koneksi Lengkap di Schematic Proteus

```
3.3V ──┬──────────────────────────────────────────
       │                                          │
      RV1                                        │
   (atau VSIN)                                   │
       │ (wiper)                                  │
       ├──────────────────── PA0 (ADC IN)         │
       │           ┌─────── CH A OSCILLOSCOPE     │
       │           │                              │
PB0 ───┼───────────┼─────── CH B OSCILLOSCOPE     │
       │           │  (GPIO LED RED signal)        │
PB1 ───┼───────────┼─────── CH C OSCILLOSCOPE     │
       │           │  (GPIO LED GREEN signal)      │
PB8 ───┼───────────┼─────── CH D OSCILLOSCOPE     │
       │           │  (Relay driver signal)        │
      GND ─────── GND OSCILLOSCOPE ──────────────GND
```

---

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

*Panduan Simulasi DMCM-WVAF | STM32F401CD | Sesuai Skema Existing | v3.0 — Ditambahkan: Alternatif Sensor & Panduan Osiloskop*
