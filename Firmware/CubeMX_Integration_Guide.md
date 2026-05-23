# 🛠️ Panduan Integrasi STM32CubeMX
## Project DMCM-WVAF | Target: STM32F401CD

---

## 📋 Langkah 0 — Persiapan

Pastikan sudah terinstall:
- **STM32CubeIDE** versi 1.12 atau lebih baru  
  *(CubeMX sudah terintegrasi di dalamnya)*
- **STM32Cube FW_F4** package (akan didownload otomatis)

---

## 🆕 Langkah 1 — Buat Project Baru

```
STM32CubeIDE
  └── File
       └── New
            └── STM32 Project
```

### 1.1 Pilih Target MCU

Pada jendela **Target Selection**:

```
Tab: MCU/MPU Selector
─────────────────────────────────────────
Kolom Search:   ketik  STM32F401CD
─────────────────────────────────────────
Hasil:          STM32F401CDTx   ← pilih ini
                STM32F401CDUx
─────────────────────────────────────────
                          [Next >]
```

### 1.2 Setup Project

```
Project Name  : DMCM_WVAF
Project Type  : STM32CubeIDE
Language      : C
Binary Type   : Executable
Firmware      : (biarkan default, akan auto-download)
                          [Finish]
```

> Saat pertama kali, CubeIDE akan mendownload **STM32Cube FW_F4 package**. Tunggu hingga selesai.

---

## ⚙️ Langkah 2 — Buka File Konfigurasi (.ioc)

Setelah project terbuat, file `DMCM_WVAF.ioc` akan otomatis terbuka di editor **Pinout & Configuration**.

Tampilan tab-tab yang tersedia:
```
[Pinout & Configuration] [Clock Configuration] [Project Manager] [Tools]
```

---

## 🕐 Langkah 3 — Konfigurasi CLOCK (WAJIB pertama)

Klik tab: **Clock Configuration**

> ⚠️ **Khusus Proteus:** Jangan gunakan PLL — Proteus tidak mensimulasikan PLL dengan baik dan MCU bisa gagal start. Gunakan **HSI 16MHz langsung** sebagai SYSCLK.

### 3.1 Setting Clock Tree (HSI Direct — Tanpa PLL)

```
CLOCK TREE STM32F401CD (untuk Proteus):

[HSI 16MHz] ──────────────────────────► SYSCLK = 16 MHz
                                              │
                                    APB1 /1 → 16 MHz
                                    APB2 /1 → 16 MHz

Setting yang digunakan:
┌─────────────────────────────────────────────────┐
│ Input Clock Source  : HSI (16 MHz internal)     │
│ System Clock Mux    : HSI  ← pilih HSI langsung │
│ PLL                 : DISABLE / tidak dipakai   │
│ HCLK               : 16 MHz                    │
│ APB1 Prescaler      : /1  → 16 MHz              │
│ APB2 Prescaler      : /1  → 16 MHz              │
└─────────────────────────────────────────────────┘
```

**Cara input di CubeMX:**
1. Pastikan **System Clock Mux** (panah SYSCLK) diarahkan ke **HSI** (bukan PLLCLK)
2. Di kolom **HCLK (MHz)** ketik `16` lalu tekan Enter
3. Pastikan tidak ada tanda merah pada clock tree
4. APB1 dan APB2 biarkan prescaler `/1`

---

## 📌 Langkah 4 — Konfigurasi PIN (Pinout & Configuration)

Kembali ke tab **Pinout & Configuration**.

### 4.1 Aktifkan RCC (Clock Source)

```
Kategori (panel kiri): System Core → RCC

High Speed Clock (HSE) : Disable  (pakai HSI internal)
Low Speed Clock (LSE)  : Disable
```

### 4.2 Konfigurasi ADC1 — Sensor RV1 & RV2

```
Kategori (panel kiri): Analog → ADC1

Mode:
  ☑ IN0  (PA0) — aktifkan  → Sensor RV1
  ☑ IN1  (PA1) — aktifkan  → Sensor RV2

Configuration → Parameter Settings:
┌─────────────────────────────────────────────────────┐
│ Clock Prescaler         : PCLK2 divided by 4        │
│ Resolution              : 12 Bits (15 ADC Clock)    │
│ Data Alignment          : Right alignment            │
│ Scan Conversion Mode    : Enabled                   │
│ Continuous Conversion   : Enabled                   │
│ DMA Continuous Requests : Disabled                   │
│ End Of Conversion       : EOC flag at end of single  │
│ Number Of Conversion    : 2                          │
│                                                      │
│ Rank 1:                                              │
│   Channel       : Channel 0  (PA0)                  │
│   Sampling Time : 56 Cycles                          │
│                                                      │
│ Rank 2:                                              │
│   Channel       : Channel 1  (PA1)                  │
│   Sampling Time : 56 Cycles                          │
└─────────────────────────────────────────────────────┘
```

### 4.3 Konfigurasi GPIO — LED & Relay

```
Cara set pin GPIO di Pinout view:
  Klik pin di diagram MCU → pilih GPIO_Output

Pin yang dikonfigurasi:

┌──────┬───────────┬──────────────────┬─────────────────────────┐
│ Pin  │ GPIO Mode │ Default Level    │ Label (User Label)      │
├──────┼───────────┼──────────────────┼─────────────────────────┤
│ PB0  │ Output PP │ Low              │ LED_RED                 │
│ PB1  │ Output PP │ Low              │ LED_GREEN               │
│ PB8  │ Output PP │ Low              │ RELAY_CTRL              │
└──────┴───────────┴──────────────────┴─────────────────────────┘

Cara set User Label:
  Klik kanan pin di Pinout → Enter User Label → ketik nama
```

**Detail konfigurasi setiap GPIO** (Kategori: System Core → GPIO):

```
PB0 — LED_RED:
  GPIO output level      : Low
  GPIO mode              : Output Push Pull
  GPIO Pull-up/Pull-down : No pull-up, no pull-down
  Maximum output speed   : Low

PB1 — LED_GREEN:
  (sama dengan PB0)

PB8 — RELAY_CTRL:
  GPIO output level      : Low
  GPIO mode              : Output Push Pull
  GPIO Pull-up/Pull-down : No pull-up, no pull-down
  Maximum output speed   : Low
```

### 4.4 Konfigurasi USART1 — Virtual Terminal

```
Kategori (panel kiri): Connectivity → USART1

Mode: Asynchronous

  → PA9  otomatis = USART1_TX  ✅
  → PA10 otomatis = USART1_RX  ✅

Parameter Settings:
┌─────────────────────────────────────────────┐
│ Baud Rate          : 9600 Bits/s            │
│ Word Length        : 8 Bits (including parity)│
│ Parity             : None                   │
│ Stop Bits          : 1                      │
│ Data Direction     : Receive and Transmit   │
│ Over Sampling      : 16 Samples             │
└─────────────────────────────────────────────┘

NVIC Settings:
  USART1 global interrupt : Disabled (polling)
```

### 4.5 Konfigurasi TIM2 — Zona Kritis SBTP (5ms)

```
Kategori (panel kiri): Timers → TIM2

Mode:
  Clock Source : Internal Clock

Parameter Settings:
┌─────────────────────────────────────────────────────────┐
│ Prescaler (PSC)     : 15                                │
│   → Clock TIM2: 16MHz / (15+1) = 1 MHz                 │
│                                                          │
│ Counter Mode        : Up                                │
│                                                          │
│ Counter Period (ARR): 4999                              │
│   → Periode: 1MHz / (4999+1) = 200 Hz = 5 ms ✅        │
│                                                          │
│ auto-reload preload : Enable                            │
│ Internal Clock Div  : No Division                       │
└─────────────────────────────────────────────────────────┘

NVIC Settings:
  TIM2 global interrupt : ☑ ENABLED   ← WAJIB dicentang!
  Preemption Priority   : 0
  Sub Priority          : 0
```

> **Catatan PSC:** Karena SYSCLK = 16MHz (bukan 84MHz), Prescaler cukup 15 (bukan 83).

> **Penting:** Tanpa NVIC TIM2 diaktifkan, fungsi `HAL_TIM_PeriodElapsedCallback` tidak akan pernah dipanggil dan **Zona Kritis SBTP tidak bekerja**.

---

## 📂 Langkah 5 — Project Manager Settings

Klik tab: **Project Manager**

### 5.1 Project Tab

```
Project Name        : DMCM_WVAF
Project Location    : [pilih folder workspace Anda]
Application Type    : Executable
Toolchain/IDE       : STM32CubeIDE
Linker Settings     : (biarkan default)
```

### 5.2 Code Generator Tab

```
STM32Cube MCU packages and embedded software packs:
  ● Copy only the necessary library files   ← pilih ini (lebih ringan)

Generated files:
  ☑ Generate peripheral initialization as a pair of .c/.h files per peripheral
  ☑ Backup previously generated files when re-generating
  ☐ Keep User Code when re-generating    ← PENTING: centang ini!
  ☑ Delete previously generated files when not re-generated

HAL Settings:
  ☑ Set all free pins as analog (to optimize the power consumption)
```

---

## 🔄 Langkah 6 — Generate Code

```
Klik tombol: [GENERATE CODE]  (ikon gear / pojok kanan atas)
   atau
Menu: Project → Generate Code
```

Jika muncul dialog:
```
"Do you want to open the perspective?"
→ Klik: Yes
```

Struktur folder yang dihasilkan:

```
DMCM_WVAF/
├── Core/
│   ├── Inc/
│   │   ├── main.h          ← header, jangan diubah
│   │   ├── stm32f4xx_hal_conf.h
│   │   └── stm32f4xx_it.h
│   └── Src/
│       ├── main.c          ← ← ← EDIT FILE INI
│       ├── stm32f4xx_hal_msp.c
│       ├── stm32f4xx_it.c  ← jangan diubah
│       └── system_stm32f4xx.c
├── Drivers/
│   ├── CMSIS/
│   └── STM32F4xx_HAL_Driver/
└── DMCM_WVAF.ioc           ← file konfigurasi CubeMX
```

---

## ✏️ Langkah 7 — Tambahkan Kode DMCM-WVAF di main.c

Buka file `Core/Src/main.c`.

CubeMX membuat blok **User Code** yang aman dari overwrite:

```c
/* USER CODE BEGIN Includes */
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
/* USER CODE END Includes */
```

```c
/* USER CODE BEGIN PD */
// Letakkan semua #define di sini
#define WIN_MAX        16
#define WIN_MIN         2
#define DELTA_THRESH   200

#define STATE_NORMAL   0
#define STATE_WARNING  1
#define STATE_DANGER   2

#define ACT_NORMAL     0
#define ACT_WARNING    1
#define ACT_DANGER     2
#define ACT_IDLE       3
/* USER CODE END PD */
```

```c
/* USER CODE BEGIN PV */
// Letakkan variabel global di sini
uint16_t adc_buf[16];
uint8_t  win_size    = 16;
uint16_t prev_sample = 0;
uint8_t  sys_mode    = 0;
volatile uint8_t crit_flag = 0;
char uart_out[100];

const uint8_t state_matrix[3][3] = {
    { 0, 0, 3 },
    { 1, 1, 3 },
    { 2, 1, 3 },
};
/* USER CODE END PV */
```

```c
/* USER CODE BEGIN 0 */
// Letakkan fungsi helper di sini (WVAF, get_state, actuator_set)
// Salin fungsi dari Proteus_Simulation_Guide.md
/* USER CODE END 0 */
```

```c
/* USER CODE BEGIN 2 */
// Setelah semua MX_Init selesai, tambahkan:
memset(adc_buf, 0, sizeof(adc_buf));
HAL_TIM_Base_Start_IT(&htim2);
const char *hello = "=== DMCM-WVAF Ready ===\r\n";
HAL_UART_Transmit(&huart1, (uint8_t*)hello, strlen(hello), 100);
/* USER CODE END 2 */
```

```c
/* USER CODE BEGIN WHILE */
while (1) {
    HAL_Delay(50);  // Zona Non-Kritis
    crit_flag = 0;
/* USER CODE END WHILE */
}
```

```c
/* USER CODE BEGIN 4 */
// Callback Timer — Zona Kritis SBTP
void HAL_TIM_PeriodElapsedCallback(TIM_HandleTypeDef *htim) {
    if (htim->Instance == TIM2) {
        // Salin isi fungsi dari Proteus_Simulation_Guide.md
    }
}
/* USER CODE END 4 */
```

> **Aturan penting:** Selalu letakkan kode di dalam blok `/* USER CODE BEGIN xxx */` dan `/* USER CODE END xxx */`. Kode di luar blok ini akan **terhapus** saat Generate Code dijalankan ulang.

---

## 🔨 Langkah 8 — Build Project

```
Menu: Project → Build Project
   atau tekan: Ctrl + B
```

Hasil di Console yang diharapkan:
```
arm-none-eabi-size "DMCM_WVAF.elf"
   text    data     bss     dec     hex filename
   8192     112    1024    9328    2470 DMCM_WVAF.elf

Build Finished.
0 errors, 0 warnings.        ← Target yang diharapkan
```

File output yang dibutuhkan untuk Proteus:
```
DMCM_WVAF/
└── Debug/
    ├── DMCM_WVAF.elf
    └── DMCM_WVAF.hex   ← ← ← Load file ini ke Proteus
```

---

## 🔁 Langkah 9 — Jika Perlu Update Konfigurasi (Re-generate)

Jika ada perubahan pin atau peripheral:

```
1. Buka file DMCM_WVAF.ioc (double-click)
2. Ubah konfigurasi yang diperlukan
3. Klik [GENERATE CODE] lagi
4. Kode di USER CODE blocks AMAN dari overwrite ✅
5. Build ulang (Ctrl+B)
6. Load ulang .hex ke Proteus
```

---

## 📊 Ringkasan Konfigurasi CubeMX

| Peripheral | Mode | Pin | Setting Kunci |
|---|---|---|---|
| **ADC1 CH0** | Single-ended | PA0 | 12-bit, Scan ON, Continuous ON |
| **ADC1 CH1** | Single-ended | PA1 | Sampling: 56 cycles |
| **GPIO PB0** | Output PP | PB0 | Label: LED_RED |
| **GPIO PB1** | Output PP | PB1 | Label: LED_GREEN |
| **GPIO PB8** | Output PP | PB8 | Label: RELAY_CTRL |
| **USART1** | Async | PA9/PA10 | 9600bps, 8N1 |
| **TIM2** | Internal CLK | — | PSC=**15**, ARR=4999 → **5ms** |
| **TIM2 NVIC** | — | — | **Global IRQ: ENABLE** |
| **RCC** | HSI Direct | — | SYSCLK = **16 MHz** (tanpa PLL) |

---

*Panduan CubeMX DMCM-WVAF | STM32F401CD | v1.0*
