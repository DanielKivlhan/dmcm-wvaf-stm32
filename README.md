# 🔋 DMCM-WVAF — Deterministic Mixed-Criticality Matrix with Variable-Window Adaptive Filtering

> **Bare-Metal Safety Instrumentation Framework on STM32F401CD**
>
> Department of Instrumentation Engineering · Faculty of Vocational Studies  
> **Institut Teknologi Sepuluh Nopember (ITS), Surabaya, Indonesia**

---

## 🎯 Overview

**DMCM-WVAF** adalah framework instrumentasi keselamatan *bare-metal* yang diimplementasikan pada **ARM Cortex-M4 (STM32F401CD)**. Framework ini menggabungkan tiga teknik utama secara simultan untuk menjawab tantangan sistem embedded *safety-critical*:

| Tantangan | Solusi DMCM-WVAF |
|---|---|
| Noise termal & kuantisasi ADC | **WVAF** — filter jendela adaptif variabel |
| Latensi tinggi saat transien darurat | Window menyusut otomatis ke `W_min = 2` |
| Jitter eksekusi akibat `if-else` bertingkat | **O(1) State-Matrix Lookup** di FLASH |
| Gangguan zona non-kritis ke fungsi safety | **SBTP** — partisi temporal berbasis hardware IRQ |
| Kebutuhan RTOS berat | Tanpa OS — murni *bare-metal* HAL |

---

## 🚀 Key Features

- **Variable-Window Adaptive Filtering (WVAF)**  
  Window filter menyusut dari `W_max = 16` → `W_min = 2` saat transien terdeteksi (`|ΔV| > 200 ADC count`), memangkas phase lag sebesar **93.3%** (~2.5 ms response time). Pada kondisi stabil, window diperlebar untuk menekan noise **12 dB (75%)**.

- **Software-Based Temporal Partitioning (SBTP)**  
  `TIM2` hardware interrupt (periode **5 ms**) mengisolasi zona *safety-critical* dari zona non-kritis. Fungsi keselamatan berjalan eksklusif di ISR — tidak terpengaruh oleh hang, loop tak terbatas, atau komputasi berat di background.

- **O(1) State-Matrix Lookup**  
  Array `state_matrix[3][3]` yang tersimpan di FLASH menggantikan percabangan bersyarat. Seluruh keputusan aktuator diselesaikan dalam **3 instruksi ARM**, menghasilkan jitter = **0**.

- **Atomic Actuator Actuation**  
  Output GPIO (LED merah PB0, LED hijau PB1, Relay PB8) dikontrol via register `GPIOB->BSRR` (single-cycle) — tanpa overhead read-modify-write.

---

## 🧠 Arsitektur Sistem

```
                  ┌────────────────────────────────────────┐
                  │       STM32F401CD — ARM Cortex-M4      │
                  └───────────────────┬────────────────────┘
                                      │
                     [ TIM2 IRQ — 5 ms Hardware Tick ]
                                      ▼
     ┌─────────────────────────────────────────────────────────────┐
     │  ZONA KRITIS — TIM2 ISR Context (High Priority)             │
     ├─────────────────────────────────────────────────────────────┤
     │  1. ADC Sampling    → ADC1 Ch.1 (PA1) — LM35 VOUT          │
     │  2. WVAF Filter     → T_filtered = avg(adc_buf[win_size])   │
     │  3. State Eval      → state = get_state(T_filtered)         │
     │  4. O(1) Lookup     → cmd = state_matrix[state][sys_mode]   │
     │  5. Actuator Drive  → actuator_set(cmd) via GPIOB->BSRR     │
     │  6. UART Telemetry  → snprintf + HAL_UART_Transmit          │
     └────────────────────────────┬────────────────────────────────┘
                                  │ [ Hardware Interrupt Return ]
                                  ▼
     ┌─────────────────────────────────────────────────────────────┐
     │  ZONA NON-KRITIS — Main Background Loop (Best-Effort)       │
     ├─────────────────────────────────────────────────────────────┤
     │  • LCD/OLED Display Refresh                                 │
     │  • User Parameter Tuning & UI                               │
     │  • Non-critical Data Logging                                │
     └─────────────────────────────────────────────────────────────┘
```

> **Jaminan keselamatan:** Jika zona non-kritis mengalami *hang* atau *infinite loop*, zona kritis tetap berjalan tepat waktu karena dipicu langsung oleh hardware IRQ.

---

## ⚖️ Perbandingan Metode

### Logika Aktuator: Konvensional vs O(1) State-Matrix

| Aspek | `if-else` / `switch` Konvensional | **DMCM-WVAF State-Matrix** |
|---|---|---|
| Kompleksitas waktu | O(n) — bervariasi per kondisi | **O(1)** — selalu konstan |
| Jitter eksekusi | Tinggi & tidak terprediksi | **Nol** — deterministik |
| Jumlah instruksi ARM | Bergantung cabang aktif | **Tepat 3 instruksi** |
| Verifikasi formal | Sulit | **Mudah** — array statis |
| Overhead memori | Tinggi (kode cabang besar) | **Rendah** (9 byte FLASH) |
| Skalabilitas state baru | Tambah blok `else if` | Tambah 1 baris array |

### Filter Sensor: Fixed vs WVAF Adaptif

| Kondisi Sistem | Fixed-Window MA | **WVAF Adaptif** |
|---|---|---|
| Steady-state (noise) | Reduksi sedang | **12 dB** (75% noise suppression) |
| Transien mendadak | Latensi 37.5 ms | **2.5 ms** (−93.3%) |
| Window size | Tetap (tidak adaptif) | `W_min=2` ↔ `W_max=16` otomatis |
| Phase lag darurat | Tinggi | **Minimal** |

### Safety Isolation: RTOS vs SBTP

| Aspek | RTOS Komersial | **SBTP Bare-Metal** |
|---|---|---|
| Overhead kernel | Tinggi (>10 KB RAM) | **Nol** |
| Determinisme IRQ | Bergantung scheduler | **Hardware-enforced** |
| Ketahanan terhadap hang | Task watchdog | **TIM2 IRQ tetap jalan** |
| Portabilitas | Lisensi + porting | **Hanya HAL STM32** |

---

## 🔄 Diagram Transisi State

```
                    ┌─────────────────────────────────────┐
                    │   SENSOR STATE TRANSITION DIAGRAM   │
                    └─────────────────────────────────────┘

                         T < 30°C (ADC < 372)
               ┌─────────────────────────────────┐
               │                                 │
               ▼                                 │
        ┌──────────────┐   T ≥ 30°C (ADC ≥ 372)  │
        │              │ ──────────────────────►  │
        │   NORMAL     │                   ┌──────────────┐
        │  (State 0)   │ ◄─────────────── │              │
        │              │   T < 30°C        │   WARNING    │
        │  LED GREEN   │                   │  (State 1)   │
        │  Relay: OFF  │                   │              │
        └──────────────┘                   │  LED RED     │
                                           │  Relay: OFF  │
                                           └──────┬───────┘
                                                  │         T ≥ 40°C (ADC ≥ 496)
                                                  │ ──────────────────────────►
                                                  │                    ┌──────────────┐
                                                  │ ◄───────────────── │              │
                                                  │   T < 40°C         │   DANGER     │
                                                  │                    │  (State 2)   │
                                                  └────────────────    │              │
                                                                       │  LED RED     │
                                                                       │  Relay: ON   │
                                                                       └──────────────┘

  Konversi: T (°C) = ADC × 330 / 4096
  NORMAL  : ADC 0–371   (T < 30°C)
  WARNING : ADC 372–495 (30°C ≤ T < 40°C)
  DANGER  : ADC 496–4095 (T ≥ 40°C)
```

---

## 📋 Parameter Sistem

```c
/* ═══ WVAF — Variable-Window Adaptive Filter ═══════════════ */
#define WIN_MAX        16     // Window stabil  → noise suppression 12 dB
#define WIN_MIN         2     // Window darurat → response time 2.5 ms
#define DELTA_THRESH  200     // Ambang |ΔV| ADC untuk switch window (0–4095)

/* ═══ SBTP — Software-Based Temporal Partitioning ══════════ */
#define SBTP_TIMER    TIM2    // Hardware timer zona kritis
#define SBTP_PERIOD    5      // ms — periode ISR safety-critical

/* ═══ Threshold State Sensor (LM35, VCC=3.3V, 12-bit ADC) ══ */
#define THRESH_NORMAL   372   // ADC < 372  → T < 30°C  → NORMAL
#define THRESH_WARNING  496   // ADC < 496  → T < 40°C  → WARNING
                              // ADC ≥ 496  → T ≥ 40°C  → DANGER

/* ═══ Output Aktuator GPIO ═══════════════════════════════════ */
// PB0 = LED Merah  | PB1 = LED Hijau | PB8 = Relay (via transistor Q1)
#define ACT_NORMAL   0  // GREEN ON  | RED OFF | Relay OFF
#define ACT_WARNING  1  // RED ON    | GREEN OFF| Relay OFF
#define ACT_DANGER   2  // RED ON    | GREEN OFF| Relay ON
#define ACT_IDLE     3  // Semua OFF (Safe Mode)
```

---

## ⚙️ Implementasi Inti (`main.c`)

### 1. WVAF Filter

```c
#define WIN_MAX      16    // Window stabil — eliminasi noise
#define WIN_MIN       2    // Window darurat — respons cepat
#define DELTA_THRESH 200   // Ambang |ΔV| ADC (range 0–4095)

uint16_t WVAF_Filter(uint16_t sample) {
    uint16_t delta = abs((int)sample - (int)prev_sample);
    prev_sample = sample;
    win_size = (delta > DELTA_THRESH) ? WIN_MIN : WIN_MAX;
    shift_buf(adc_buf, sample, win_size);
    return avg_buf(adc_buf, win_size);
}
```

### 2. O(1) State-Matrix

```c
// state_matrix[sensor_state][sys_mode] → actuator_command
const uint8_t state_matrix[3][3] = {
/*               Auto          Manual        Safe    */
/* Normal  */ { ACT_NORMAL,  ACT_NORMAL,  ACT_IDLE },
/* Warning */ { ACT_WARNING, ACT_WARNING, ACT_IDLE },
/* Danger  */ { ACT_DANGER,  ACT_WARNING, ACT_IDLE },
};
```

### 3. State Evaluation (LM35 — T(°C) = ADC × 330 / 4096)

```c
uint8_t get_state(uint16_t val) {
    if (val < 372)       return STATE_NORMAL;   // T < 30°C
    else if (val < 496)  return STATE_WARNING;  // 30 ≤ T < 40°C
    else                 return STATE_DANGER;   // T ≥ 40°C
}
```

### 4. Actuator Output (PB0=LED Red | PB1=LED Green | PB8=Relay)

```c
void actuator_set(uint8_t cmd) {
    // Reset semua output
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_0|GPIO_PIN_1|GPIO_PIN_8, GPIO_PIN_RESET);
    switch (cmd) {
        case ACT_NORMAL:  HAL_GPIO_WritePin(GPIOB, GPIO_PIN_1, GPIO_PIN_SET); break; // GREEN
        case ACT_WARNING: HAL_GPIO_WritePin(GPIOB, GPIO_PIN_0, GPIO_PIN_SET); break; // RED
        case ACT_DANGER:  HAL_GPIO_WritePin(GPIOB, GPIO_PIN_0|GPIO_PIN_8, GPIO_PIN_SET); break; // RED+RELAY
        default: break; // ACT_IDLE — semua off
    }
}
```

---

## 📊 Hasil Evaluasi

| Metrik | Nilai |
|---|---|
| Reduksi noise steady-state | **12 dB** (75% amplitude reduction) |
| Latensi respons transien — filter tetap | 37.5 ms |
| Latensi respons transien — WVAF | **2.5 ms** (**−93.3%**) |
| Utilisasi CPU (zona kritis) | **3.6%** |
| Sisa CPU untuk non-kritis | **96.4%** |
| Konsumsi daya steady-state | ~1.2 µW |
| Jitter waktu eksekusi state-matrix | **0** (deterministik O(1)) |

---

## 🛠️ Getting Started

### Prasyarat

| Komponen | Versi / Keterangan |
|---|---|
| Keil µVision IDE | v5.38+ dengan ARM Compiler 6 (AC6) |
| STM32CubeMX | v6.x (opsional, proyek sudah dikonfigurasi) |
| Proteus Design Suite | v8.17+ |
| ST-Link Utility / STM32CubeProg | Untuk flash firmware ke board fisik |

---

### 1. Build & Flash Firmware (Keil µVision)

1. Buka `Firmware/DMCM_WVAF/MDK-ARM/DMCM_WVAF.uvprojx`
2. Pilih target **DMCM_WVAF**
3. **Build** → `F7` (tidak ada error/warning)
4. **Flash** → `F8` ke STM32F401CD via ST-Link
5. Buka Serial Monitor @ **115200 baud, 8N1** pada PA9 (USART1 TX)

---

### 2. Simulasi Proteus

1. Buka `Simulation/Pemkon.pdsprj` di **Proteus 8.17**
2. Pastikan file HEX `Firmware/DMCM_WVAF/MDK-ARM/DMCM_WVAF/DMCM_WVAF.hex` sudah ter-build
3. Klik **Run** ▶
4. Putar potensiometer **RV1/RV2** untuk mensimulasikan perubahan suhu
5. Amati transisi state pada Virtual Terminal dan LED indikator

| Kondisi | State | LED | Relay |
|---|---|---|---|
| T < 30°C | `NORMAL` | 🟢 GREEN ON | OFF |
| 30 ≤ T < 40°C | `WARNING` | 🔴 RED ON | OFF |
| T ≥ 40°C | `DANGER` | 🔴 RED ON | **ON** |

---

### 3. Analisis Data Telemetri

1. Hubungkan STM32 ke PC via USB-to-UART (PA9 TX → RX converter)
2. Buka Serial Monitor @ **115200 baud, 8N1** untuk melihat log real-time
3. Data log tersimpan di `Data_Analysis/data.csv` dengan format:

```
index, time_s, T_raw, T_filtered, N_win, |ΔT|, State, Relay, LED_Red, LED_Green
```

4. Buka `Data_Analysis/dmcm_lm35_data.xlsx` di **Microsoft Excel / LibreOffice** untuk analisis spreadsheet
5. Plot figur IEEE 4-panel tersedia di `Data_Analysis/dmcm_lm35_ieee.png`

---

## 🔌 Konfigurasi Hardware

| Pin STM32 | Fungsi | Keterangan |
|---|---|---|
| **PA1** | ADC1 Channel 1 | Input sensor LM35 (VOUT) |
| **PA9** | USART1 TX | Telemetri serial ke PC / Virtual Terminal |
| **PB0** | GPIO Output | LED Merah (WARNING/DANGER) |
| **PB1** | GPIO Output | LED Hijau (NORMAL) |
| **PB8** | GPIO Output | Driver Relay/Transistor (DANGER) |

**Konversi suhu LM35:**
```
T (°C) = ADC_raw × 330 / 4096
```
> LM35 output: 10 mV/°C. VCC = 3.3 V. ADC 12-bit (0–4095).

---

## 📈 Visualisasi Hasil

Plot 4-panel IEEE (dihasilkan oleh `plot_lm35_ieee.gp`):

| Panel | Konten |
|---|---|
| **(a)** | Sinyal suhu: `T_raw` (merah) vs. `T_filtered` WVAF (biru) + garis threshold |
| **(b)** | Ukuran window adaptif `N_win` (orange) & rate-of-change `\|ΔT\|` (abu impulse) |
| **(c)** | Klasifikasi State Machine: Normal → Warning → Danger |
| **(d)** | Output aktuator: LED Green, LED Red, dan Relay |

---

## 👥 Authors

| Nama | NRP |
|---|---|
| **Daniel Kivlhan Katoroy** | 2042241004 |
| **Faris Ahmad Holili** | 2042241028 |

**Pembimbing:** Ahmad Radhy, S.Si., M.Si.

**Program Studi:** Teknik Instrumentasi  
**Fakultas:** Vokasi — Institut Teknologi Sepuluh Nopember (ITS)  
**Kota:** Surabaya, Indonesia  
**Tahun:** 2026

---

## 🏷️ Keywords

`Embedded C` · `STM32F401` · `ARM Cortex-M4` · `Bare-Metal` · `Mixed-Criticality`  
`Variable-Window Adaptive Filter` · `WVAF` · `Moving Average` · `ADC Noise Reduction`  
`Hardware Timer Interrupt` · `Temporal Partitioning` · `SBTP` · `O(1) Lookup Table`  
`State Machine` · `Safety-Critical System` · `Deterministic Scheduling` · `LM35`

---

*Versi: 1.0 · 2026 · Institut Teknologi Sepuluh Nopember*
