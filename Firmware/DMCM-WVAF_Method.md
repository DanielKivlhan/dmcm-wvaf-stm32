# Deterministic Mixed-Criticality Matrix with Variable-Window Adaptive Filtering
## (DMCM-WVAF)
### *Metode Matriks Keadaan Kritis Terpisah dengan Penyaringan Adaptif Jendela Variabel*

---

## 📌 Abstrak

**DMCM-WVAF** adalah metode baru dalam pemrograman sistem instrumentasi berbasis mikrokontroler yang menggabungkan dua pendekatan utama:

1. **Penyaringan Sensor Adaptif** — mereduksi noise sensor tanpa mengorbankan latensi respons.
2. **Penjadwalan Aktuator Deterministik** — memisahkan tugas kritis keselamatan dan tugas biasa dalam waktu eksekusi konstan $O(1)$.

Metode ini diimplementasikan sepenuhnya menggunakan **Embedded C terstruktur** pada platform **STM32**, memanfaatkan **Hardware Timer Interrupt** bawaan untuk partisi waktu eksekusi yang adil dan deterministik.

---

## 💡 Latar Belakang & Motivasi

Sistem instrumentasi industri modern menghadapi dua tantangan utama yang sering kali saling bertentangan:

| Tantangan | Deskripsi |
|---|---|
| **Noise Sensor** | Data ADC tercemar noise termal dan kuantisasi yang menurunkan akurasi |
| **Latensi Respons** | Filter noise konvensional memperlambat respons saat kondisi darurat |
| **Determinisme Waktu** | Percabangan `if-else` / `switch-case` bertingkat menyebabkan waktu eksekusi yang bervariasi |
| **Mixed-Criticality** | Sulit memisahkan fungsi keselamatan kritis dari tugas biasa tanpa OS berat |

> **DMCM-WVAF** menjawab semua tantangan di atas secara simultan dengan arsitektur tiga-lapis yang ringan dan dapat berjalan pada MCU berspesifikasi rendah sekalipun.

---

## 🛠️ Arsitektur Metode: 3 Komponen Utama

```
┌─────────────────────────────────────────────────────────────┐
│                    SISTEM DMCM-WVAF                         │
│                                                             │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────────┐   │
│  │  SENSOR     │   │    CORE     │   │   AKTUATOR      │   │
│  │  SIDE       │──▶│    SIDE     │──▶│   SIDE          │   │
│  │  (WVAF)     │   │   (SBTP)    │   │  (O(1) Matrix)  │   │
│  └─────────────┘   └─────────────┘   └─────────────────┘   │
│  Variable-Window   Temporal           State-Matrix          │
│  Adaptive Filter   Partitioning       Mapping               │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔧 Komponen 1 — Sensor Side: Variable-Window Adaptive Filtering (WVAF)

### Masalah pada Moving Average Filter Konvensional

Filter Moving Average standar menggunakan **ukuran jendela tetap** (fixed window size), misalnya rata-rata 10 data terakhir.

**Kelemahan:**
- Saat terjadi perubahan kondisi mendadak → sistem **lambat merespons** (latensi tinggi)
- Noise termal dan kuantisasi ADC tidak tersaring dengan optimal di semua kondisi

### Solusi: WVAF — Jendela Filter yang Menyesuaikan Diri

WVAF bekerja dengan menghitung **laju perubahan data sensor** ($\Delta V / \Delta t$) secara real-time:

```
                  ΔV/Δt KECIL          ΔV/Δt BESAR
                (Kondisi Stabil)    (Lonjakan Mendadak)
                      │                     │
                      ▼                     ▼
              Window DIPERBESAR       Window MENYUSUT
              (misal: 16 data)       (misal: 2 data)
                      │                     │
                      ▼                     ▼
              Noise termal &         Respons CEPAT
              kuantisasi              terhadap kondisi
              tereliminasi            darurat
```

### Algoritma WVAF (Pseudocode)

```c
/* === Variable-Window Adaptive Filtering (WVAF) === */
#define WIN_MAX     16      // Jendela maksimum: kondisi stabil
#define WIN_MIN      2      // Jendela minimum: kondisi darurat
#define DELTA_THRESH 50     // Ambang batas perubahan (unit ADC)

uint16_t adc_buffer[WIN_MAX];
uint8_t  window_size = WIN_MAX;

uint16_t WVAF_Filter(uint16_t new_sample) {
    static uint16_t prev_sample = 0;
    uint16_t delta = abs((int)new_sample - (int)prev_sample);
    prev_sample = new_sample;

    // Adaptasi ukuran jendela berdasarkan laju perubahan
    if (delta > DELTA_THRESH) {
        window_size = WIN_MIN;     // Kondisi darurat: respons cepat
    } else {
        window_size = WIN_MAX;     // Kondisi stabil: eliminasi noise
    }

    // Geser buffer dan hitung rata-rata adaptif
    shift_buffer(adc_buffer, new_sample, window_size);
    return compute_average(adc_buffer, window_size);
}
```

### Manfaat WVAF

| Kondisi Sistem | Window Size | Efek |
|---|---|---|
| Stabil (noise rendah) | **16 data** | Noise termal & kuantisasi tereliminasi |
| Transisi / berubah | Interpolasi | Respons proporsional |
| Darurat / lonjakan | **2 data** | Latensi minimum, respons instan |

> **Relevansi Jurnal:** Menjawab *future work* dari **Jurnal 13 & 14** terkait pengurangan noise dan batasan kuantisasi ADC.

---

## ⚙️ Komponen 2 — Core Side: Software-Based Temporal Partitioning (SBTP)

### Konsep Dasar

SBTP meniru cara kerja **hypervisor** dan **hard real-time kernel** tanpa memerlukan OS pihak ketiga. Eksekusi program dibagi menjadi **dua zona waktu** menggunakan satu **Hardware Timer Interrupt** (SysTick / TIM2 pada STM32).

```
Timeline Eksekusi (per 10 ms)
─────────────────────────────────────────────────────────────
│◄───── 5 ms ──────►│◄────────── sisa waktu ──────────────►│
│                   │                                       │
│  ZONA KRITIS      │       ZONA NON-KRITIS                 │
│  (Safety Zone)    │       (Normal Zone)                   │
│                   │                                       │
│ • Baca sensor     │ • Kirim data (UART/SPI)               │
│   keselamatan     │ • Update LCD/OLED                     │
│ • Kontrol         │ • Kalkulasi logging                   │
│   aktuator        │ • Komputasi biasa                     │
│   darurat         │                                       │
│ • Safety          │                                       │
│   interlock       │                                       │
─────────────────────────────────────────────────────────────
      ▲                         ▲
      │                         │
  Dipicu oleh              Berjalan di
  Hardware IRQ             background loop
  (Deterministik)          (best-effort)
```

### Jaminan Keselamatan

```
┌─────────────────────────────────────────────┐
│  JIKA Zona Non-Kritis mengalami:            │
│  • Hang / Stuck                             │
│  • Loop tak terbatas                        │
│  • Komputasi berat                          │
│                                             │
│  MAKA Zona Kritis TETAP:                   │
│  ✅ Berjalan tepat waktu                    │
│  ✅ Tidak terganggu                         │
│  ✅ Dipicu langsung oleh hardware interrupt  │
└─────────────────────────────────────────────┘
```

### Implementasi SBTP (Pseudocode)

```c
/* === Software-Based Temporal Partitioning (SBTP) === */
/* Hardware Timer: TIM2, periode 5 ms                  */

volatile uint8_t critical_flag = 0;

/* --- Interrupt Handler: Zona Kritis --- */
void TIM2_IRQHandler(void) {
    TIM2->SR &= ~TIM_SR_UIF;   // Clear interrupt flag
    critical_flag = 1;

    /* ======= ZONA KRITIS ======= */
    uint16_t raw = ADC_ReadSafetySensor();
    uint16_t filtered = WVAF_Filter(raw);
    uint8_t  state    = evaluate_state(filtered);

    // O(1) Matrix lookup → kontrol aktuator
    Actuator_SetState(state_matrix[state][system_mode]);
}

/* --- Main Loop: Zona Non-Kritis --- */
int main(void) {
    System_Init();
    TIM2_Start(PERIOD_5MS);

    while (1) {
        if (!critical_flag) {
            /* ======= ZONA NON-KRITIS ======= */
            UART_SendTelemetry();
            LCD_UpdateDisplay();
            Log_DataToFlash();
        }
        critical_flag = 0;
    }
}
```

> **Relevansi Jurnal:** Menjawab *future work* dari **Jurnal 10** (Mixed-Criticality / hypervisor) dan **Jurnal 11** (hard real-time determinisme).

---

## 📊 Komponen 3 — Actuator Side: Constant-Time $O(1)$ State-Matrix Mapping

### Masalah pada Percabangan Konvensional

Pendekatan `if-else` atau `switch-case` bertingkat memiliki kelemahan mendasar:

```c
// ❌ PENDEKATAN KONVENSIONAL — TIDAK EFISIEN
if (sensor_val < 100) {
    if (mode == MODE_A) { actuator = STOP; }
    else if (mode == MODE_B) { actuator = ALARM; }
    // ... dst (O(n) — waktu bervariasi)
} else if (sensor_val < 200) {
    // ... lebih banyak percabangan
}
```

| Masalah | Dampak |
|---|---|
| Waktu eksekusi **tidak konstan** | Jitter tinggi pada sistem real-time |
| Kompleksitas kode meningkat | Sulit diverifikasi & di-maintain |
| Performa bervariasi per kondisi | Tidak deterministik |

### Solusi: State-Matrix O(1)

Semua kondisi sensor dikonversi menjadi **indeks biner** dan dipetakan ke dalam **array 2D konstan** di memori FLASH:

```c
/* === O(1) State-Matrix Mapping === */

// Indeks Baris: Status Sensor  (0=Normal, 1=Warning, 2=Danger)
// Indeks Kolom: Mode Sistem    (0=Auto,   1=Manual,  2=Safe)

// Nilai: Perintah Aktuator
const uint8_t state_matrix[3][3] = {
/*              Auto       Manual     Safe     */
/* Normal  */ { ACT_RUN,  ACT_RUN,  ACT_IDLE },
/* Warning */ { ACT_SLOW, ACT_WARN, ACT_IDLE },
/* Danger  */ { ACT_STOP, ACT_STOP, ACT_STOP },
};

/* Pengambilan keputusan: SELALU O(1) */
uint8_t sensor_idx = get_sensor_state(filtered_val);  // 0, 1, atau 2
uint8_t mode_idx   = get_system_mode();                // 0, 1, atau 2
uint8_t command    = state_matrix[sensor_idx][mode_idx]; // O(1) lookup!

Actuator_Execute(command);
```

### Perbandingan Performa

```
Pendekatan        │ Kompleksitas │ Jitter │ Memori │ Verifikasi
──────────────────┼──────────────┼────────┼────────┼───────────
if-else bertingkat│    O(n)      │ Tinggi │ Tinggi │ Sulit
switch-case       │    O(n)      │ Sedang │ Sedang │ Sedang
State-Matrix O(1) │    O(1) ✅   │ Nol ✅ │ Rendah ✅│ Mudah ✅
```

> **Relevansi Jurnal:** Menjawab *future work* dari **Jurnal 4, 6, 11** (optimasi memori, efisiensi tekstual, low-jitter).

---

## 📑 Peta Kontribusi terhadap Future Work 16 Jurnal

| Kelompok | Jurnal | Kontribusi DMCM-WVAF |
|---|---|---|
| **Optimasi Memori & Kinerja** | 4, 6, 11 | Array $O(1)$ konstan — hemat FLASH/RAM, cepat vs. `if-else` C/C++ standar |
| **Mixed-Criticality & Determinisme** | 10, 11 | Temporal partitioning berbasis hardware interrupt — fungsi safety selalu tepat waktu |
| **Pengurangan Noise & Kuantisasi ADC** | 13, 14 | Algoritma WVAF — filter jendela variabel adaptif pada data ADC |
| **Efisiensi Algoritma Edge** | 1, 2, 3, 5, 16 | Matriks keputusan neuro-like lookup — mengganti AI/Deep Learning berat di MCU rendah |

---

## 🔄 Alur Kerja Sistem Lengkap

```
                      ┌──────────────┐
                      │  SENSOR ADC  │
                      │  (Raw Data)  │
                      └──────┬───────┘
                             │ raw_value
                             ▼
                      ┌──────────────┐
                      │    WVAF      │ ◄── Hitung ΔV/Δt
                      │   Filter     │     Adaptasi window size
                      └──────┬───────┘     (WIN_MIN ↔ WIN_MAX)
                             │ filtered_value
                             ▼
                      ┌──────────────┐
                      │  SBTP Core   │
                      │  Zona Kritis │ ◄── Hardware Timer IRQ (5ms)
                      │  (5ms tick)  │
                      └──────┬───────┘
                             │ sensor_state_index
                             ▼
                      ┌──────────────┐
                      │  State       │
                      │  Matrix O(1) │ ◄── state_matrix[state][mode]
                      │  Lookup      │
                      └──────┬───────┘
                             │ actuator_command
                             ▼
                      ┌──────────────┐
                      │  AKTUATOR    │
                      │  (Output)    │
                      └──────────────┘

                  ┌──────────────────────────┐
                  │      SBTP Zona           │ (Background Loop)
                  │      Non-Kritis          │
                  │  • UART Telemetry        │
                  │  • LCD / OLED Update     │
                  │  • Data Logging          │
                  └──────────────────────────┘
```

---

## ✅ Keunggulan Komparatif DMCM-WVAF

| Aspek | Metode Konvensional | **DMCM-WVAF** |
|---|---|---|
| **Filter Sensor** | Fixed-window MA | Adaptive variable-window (WVAF) |
| **Latensi Darurat** | Tinggi (filter delay) | Minimal (window menyusut otomatis) |
| **Partisi Waktu** | Tidak ada / RTOS berat | SBTP via hardware interrupt |
| **Ketahanan Safety** | Rentan terhadap hang | Terjamin oleh hardware IRQ |
| **Logika Aktuator** | O(n) if-else / switch | O(1) State-Matrix Lookup |
| **Jitter Eksekusi** | Tinggi & bervariasi | Deterministik / nol |
| **Kebutuhan OS** | RTOS (berat) | **Tanpa OS** (bare-metal) |
| **Target Platform** | MCU high-end | **MCU low-end** (termasuk STM32F1) |
| **Kompleksitas Kode** | Tinggi | **Rendah & terstruktur** |

---

## 📋 Spesifikasi Implementasi

### Platform Target
- **MCU:** STM32F1xx / STM32F4xx (dapat diadaptasi ke keluarga lain)
- **Timer:** SysTick atau TIM2 (periode 5 ms untuk Zona Kritis)
- **ADC:** 12-bit internal ADC STM32
- **Bahasa:** Embedded C (C99 / C11)
- **Toolchain:** STM32CubeIDE / Keil MDK / GNU ARM GCC

### Parameter Konfigurasi

```c
/* Parameter WVAF */
#define WVAF_WIN_MAX       16      // Window stabil
#define WVAF_WIN_MIN        2      // Window darurat
#define WVAF_DELTA_THRESH  50      // Ambang perubahan (ADC count)

/* Parameter SBTP */
#define SBTP_CRITICAL_PERIOD_MS   5    // Periode Zona Kritis
#define SBTP_TIMER                TIM2 // Hardware timer yang digunakan

/* Parameter State-Matrix */
#define SENSOR_STATE_NORMAL   0
#define SENSOR_STATE_WARNING  1
#define SENSOR_STATE_DANGER   2

#define SYS_MODE_AUTO    0
#define SYS_MODE_MANUAL  1
#define SYS_MODE_SAFE    2
```

---

## 📚 Referensi & Konteks Jurnal

Metode DMCM-WVAF secara langsung menyerap dan menjawab *future work* dari 16 jurnal terkait dalam bidang:

- **Jurnal 1–3, 5, 16:** Efisiensi algoritma untuk edge computing & embedded AI
- **Jurnal 4, 6:** Optimasi memori FLASH/RAM dan kinerja tekstual pada MCU
- **Jurnal 10:** Sistem Mixed-Criticality dan konsep hypervisor pada embedded system
- **Jurnal 11:** Hard real-time determinisme, low-jitter scheduling, dan efisiensi memori
- **Jurnal 13–14:** Pengurangan noise sensor dan batasan kuantisasi ADC

---

## 🏷️ Kata Kunci

`Embedded C` · `STM32` · `Mixed-Criticality` · `Real-Time System` · `Adaptive Filter`  
`Variable-Window` · `Moving Average` · `Hardware Interrupt` · `Temporal Partitioning`  
`O(1) Lookup Table` · `State Machine` · `Bare-Metal` · `ADC Noise Reduction`  
`Safety-Critical System` · `Deterministic Scheduling` · `WVAF` · `SBTP` · `DMCM`

---

*Dokumen ini merupakan deskripsi teknis metode **DMCM-WVAF** untuk keperluan penelitian dan referensi implementasi.*  
*Dibuat: 2026 | Versi: 1.0*
