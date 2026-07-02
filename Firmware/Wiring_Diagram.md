# 🔌 Wiring Diagram Lengkap — DMCM-WVAF
## STM32F401CD + RV1/RV2 + LED + Relay BC547 + Buzzer

---

## 📌 Daftar Pin STM32F401CD (Yang Digunakan)

```
                    STM32F401CD
                  ┌─────────────┐
      VBAT ── 1 ──┤             ├── 11 ── PA1   → VOUT LM35 (ADC1_IN1)
       GND ── 2 ──┤             ├── 29 ── PA8
     PC14 ── 3 ──┤             ├── 30 ── PA9   → TX ke Virtual Terminal
     PC15 ── 4 ──┤             ├── 31 ── PA10  → RX ke Virtual Terminal
  PH0/OSC ── 5 ──┤             ├── 32 ── PA11
  PH1/OSC ── 6 ──┤             ├── 33 ── PA12
      NRST ── 7 ──┤             ├── 34 ── PA13
  VSSA/REF── 8 ──┤             ├── 37 ── PA14
     VREF+ ── 9 ──┤             │
                  │             │   PB0 ── 18  → ke R1 → D1 LED-RED
      3.3V──VDD   │             │   PB1 ── 19  → ke R2 → D2 LED-GREEN
       GND──VSS   │             │   PB2 ── 20
                  │             │   PB3 ── 39
                  │             │   PB4 ── 40
                  │             │   PB5 ── 41
                  │             │   PB6 ── 42
                  │             │   PB7 ── 43
                  │             │   PB8 ── 45  → ke R3 → Q1 Base
                  │             │   PB9 ── 46
                  │  BOOT0 ─ 44─┤
                  │  VCAP1 ─ 22─┤
                  │  PC13  ──  3─┤
                  └─────────────┘
```

---

## 🟢 BAGIAN 1 — Koneksi Power Supply (3.3V)

```
   POWER SOURCE 3.3V
         │
         ├──────────────────────────────────────────── VDD  (STM32 pin 24)
         │
         ├──────────────────────────────────────────── VDDA (STM32 pin 9)
         │
         ├──── Ujung atas RV1 (terminal 1)
         │
         └──── Ujung atas RV2 (terminal 1)

   GND ──┬───────────────────────────────────────────── VSS  (STM32 pin 23)
         │
         ├─────────────────────────────────────────────VSSA  (STM32 pin 8)
         │
         ├──── Ujung bawah RV1 (terminal 3)
         │
         ├──── Ujung bawah RV2 (terminal 3)
         │
         ├──── Katoda D1 LED-RED
         │
         └──── Katoda D2 LED-GREEN
```

> **Penting:** BOOT0 (pin 44) harus disambungkan ke **GND** agar STM32 boot dari Flash.

---

## 🌡️ BAGIAN 2 — Koneksi Sensor Suhu (LM35 → PA1)

### LM35 → PA1 (ADC1_IN1 — Sensor Utama WVAF)

LM35 adalah sensor suhu presisi dengan output linear 10 mV/°C.
VOUT dihubungkan langsung ke pin PA1 (ADC1_IN1) untuk dikonversi oleh ADC 12-bit.

```
   VCC 3.3V
    │
    ├── VCC LM35 (pin 1)
    │
   [LM35]
    │
    ├── VOUT LM35 (pin 2) ─────────────────► PA1 (pin 11) → ADC1_IN1
    │
    └── GND LM35 (pin 3)
         │
        GND
```

**Konversi ADC → Suhu:**
```
T(°C) = ADC × 330 / 4096   (Vref=3.3V, 12-bit, LM35 = 10 mV/°C)

ADC  <  372  →  T < 30°C   →  NORMAL
ADC  <  496  →  T < 40°C   →  WARNING
ADC  ≥  496  →  T ≥ 40°C   →  DANGER
```

**Tabel wiring LM35:**

| Titik | Sambung ke |
|---|---|
| VCC LM35 (pin 1) | 3.3V |
| VOUT LM35 (pin 2) | PA1 (pin 11) STM32 — ADC1_IN1 |
| GND LM35 (pin 3) | GND |

> **Catatan:** Tambahkan kapasitor 100nF antara VOUT LM35 dan GND (dekat pin PA1) untuk mengurangi noise ADC.

---

## 🔴 BAGIAN 3 — Koneksi LED Indikator

### D1 LED-RED (Indikator WARNING / DANGER)

```
   PB0 (pin 18)
       │
      [R1 330Ω]   ← current limiting resistor
       │
       ▼ (Anoda)
      [D1 LED-RED]
       │ (Katoda)
       │
      GND
```

**Tabel wiring D1:**

| Titik | Sambung ke |
|---|---|
| PB0 (pin 18) | Kaki R1 sisi kiri |
| Kaki R1 sisi kanan | Anoda (+) D1 LED-RED |
| Katoda (–) D1 LED-RED | GND |

---

### D2 LED-GREEN (Indikator NORMAL)

```
   PB1 (pin 19)
       │
      [R2 300Ω]   ← current limiting resistor
       │
       ▼ (Anoda)
      [D2 LED-GREEN]
       │ (Katoda)
       │
      GND
```

**Tabel wiring D2:**

| Titik | Sambung ke |
|---|---|
| PB1 (pin 19) | Kaki R2 sisi kiri |
| Kaki R2 sisi kanan | Anoda (+) D2 LED-GREEN |
| Katoda (–) D2 LED-GREEN | GND |

---

## 🟡 BAGIAN 4 — Koneksi Relay (Aktuator Darurat)

Relay dikendalikan oleh transistor NPN BC547 (Q1) karena GPIO STM32 tidak bisa langsung menghidupkan relay.

### Diagram Lengkap Relay Driver

```
   3.3V ──────────────────────────────┐
                                      │
                                   [RL1 Coil]  ← kumparan relay
                                      │
                                   Kolektor Q1 (BC547)
                                      │
   PB8 (pin 45) ──── [R3 1kΩ] ────► Base Q1
                                      │
                                   Emiter Q1
                                      │
                                     GND


   Flyback Protection (WAJIB!):
   D3 1N4007:
     Anoda (–)  ──► Kolektor Q1  (= sisi bawah kumparan)
     Katoda (+) ──► 3.3V         (= sisi atas kumparan)
   [Dipasang PARALEL dengan kumparan RL1, arah terbalik]
```

**Tabel wiring relay driver:**

| Dari | Ke | Keterangan |
|---|---|---|
| PB8 (pin 45) | R3 kaki kiri | Sinyal kontrol dari MCU |
| R3 kaki kanan | Base Q1 BC547 | Arus basis transistor |
| 3.3V | Kumparan RL1 (kaki 1) | Supply relay |
| Kumparan RL1 (kaki 2) | Kolektor Q1 | Switch relay |
| Emiter Q1 | GND | Ground transistor |
| Anoda D3 1N4007 | Kolektor Q1 | Proteksi spike tegangan |
| Katoda D3 1N4007 | 3.3V | Proteksi spike tegangan |

---

## 🔋 BAGIAN 5 — Koneksi Beban Relay (BAT1 12V + Buzzer)

```
   BAT1 12V (+) ─────────────────► Kontak COM relay (RL1)
                                         │
                                   [Saat relay ON]
                                         │
                                   Kontak NO relay ──────► Buzzer (+)
                                                                │
                                                           Buzzer (–)
                                                                │
   BAT1 12V (–) ───────────────────────────────────────────────┘
```

**Penjelasan:**
- Saat relay **OFF** → kontak COM–NC → buzzer **tidak bunyi**
- Saat relay **ON** (DANGER) → kontak COM–NO terhubung → buzzer **bunyi** 🔔

---

## 🖥️ BAGIAN 6 — Koneksi Virtual Terminal (UART Monitor)

```
   STM32F401CD              Virtual Terminal
   ───────────              ────────────────
   PA9  (TX) ─────────────► RXD
   PA10 (RX) ◄──────────── TXD
   GND ───────────────────► GND
```

**Setting Virtual Terminal di Proteus:**

| Parameter | Nilai |
|---|---|
| Baud Rate | **9600** |
| Data Bits | **8** |
| Parity | **None** |
| Stop Bits | **1** |
| Flow Control | **None** |

---

## 📋 BAGIAN 7 — Ringkasan Semua Koneksi (Master Wiring Table)

| No | Dari | Ke | Warna Kabel (Saran) |
|---|---|---|---|
| 1 | 3.3V | VDD STM32 (pin 24) | 🔴 Merah |
| 2 | 3.3V | VDDA STM32 (pin 9) | 🔴 Merah |
| 3 | GND | VSS STM32 (pin 23) | ⚫ Hitam |
| 4 | GND | VSSA STM32 (pin 8) | ⚫ Hitam |
| 5 | GND | BOOT0 STM32 (pin 44) | ⚫ Hitam |
| 6 | 3.3V | VCC LM35 (pin 1) | 🔴 Merah |
| 7 | VOUT LM35 (pin 2) | PA1 STM32 (pin 11) — ADC1_IN1 | 🟡 Kuning |
| 8 | GND | GND LM35 (pin 3) | ⚫ Hitam |
| 9 | PB0 STM32 (pin 18) | R1 kaki kiri | 🟢 Hijau |
| 10 | R1 kaki kanan | Anoda (+) D1 LED-RED | 🟢 Hijau |
| 11 | Katoda (–) D1 LED-RED | GND | ⚫ Hitam |
| 12 | PB1 STM32 (pin 19) | R2 kaki kiri | 🟢 Hijau |
| 13 | R2 kaki kanan | Anoda (+) D2 LED-GREEN | 🟢 Hijau |
| 14 | Katoda (–) D2 LED-GREEN | GND | ⚫ Hitam |
| 15 | PB8 STM32 (pin 45) | R3 kaki kiri | 🔵 Biru |
| 16 | R3 kaki kanan | Base Q1 BC547 | 🔵 Biru |
| 17 | 3.3V | RL1 Kumparan kaki 1 | 🔴 Merah |
| 18 | RL1 Kumparan kaki 2 | Kolektor Q1 BC547 | 🔵 Biru |
| 19 | Emiter Q1 BC547 | GND | ⚫ Hitam |
| 20 | Anoda D3 1N4007 | Kolektor Q1 (= RL1 kaki 2) | 🟠 Oranye |
| 21 | Katoda D3 1N4007 | 3.3V (= RL1 kaki 1) | 🟠 Oranye |
| 22 | BAT1 (+) 12V | Kontak COM relay RL1 | 🔴 Merah |
| 23 | Kontak NO relay RL1 | Buzzer (+) | 🟣 Ungu |
| 24 | Buzzer (–) | BAT1 (–) GND | ⚫ Hitam |
| 25 | PA9 STM32 (pin 30) | RXD Virtual Terminal | 🟤 Cokelat |
| 26 | PA10 STM32 (pin 31) | TXD Virtual Terminal | 🟤 Cokelat |
| 27 | GND | GND Virtual Terminal | ⚫ Hitam |

---

## ✅ Checklist Verifikasi Sebelum Simulasi

```
[ ] 3.3V terhubung ke VDD dan VDDA STM32
[ ] GND terhubung ke VSS dan VSSA STM32
[ ] BOOT0 (pin 44) disambung ke GND
[ ] VCC LM35 → 3.3V | GND LM35 → GND | VOUT LM35 → PA1
[ ] R1 (330Ω) → D1 LED-RED → GND dari PB0
[ ] R2 (300Ω) → D2 LED-GREEN → GND dari PB1
[ ] PB8 → R3 (1kΩ) → Base Q1 BC547
[ ] 3.3V → RL1 kumparan → Kolektor Q1 → Emiter Q1 → GND
[ ] D3 1N4007 paralel dengan kumparan RL1 (arah terbalik)
[ ] BAT1 (+) → COM relay → NO relay → Buzzer (+) → Buzzer (–) → BAT1 (–)
[ ] PA9 → Virtual Terminal RXD
[ ] PA10 → Virtual Terminal TXD
[ ] File HEX sudah di-load ke U1 (STM32F401CD)
[ ] Virtual Terminal: 9600 bps, 8N1
```

---

## ⚠️ Kesalahan Umum & Cara Menghindarinya

| ❌ Kesalahan | ✅ Solusi |
|---|---|
| LED tidak menyala | Pastikan **katoda** ke GND, **anoda** ke resistor |
| LED terbakar | Jangan lupa resistor R1/R2 sebelum LED |
| Relay tidak bunyi | Cek emiter Q1 → GND; cek 3.3V ke kumparan |
| Tegangan balik merusak MCU | Pasang D3 1N4007 paralel kumparan relay |
| ADC baca 0 terus | Pastikan 3.3V ke VCC LM35 dan VOUT LM35 → PA1 |
| STM32 tidak boot | BOOT0 harus ke GND, bukan floating |
| Virtual Terminal kosong | PA9=TX→RXD terminal; baud sama-sama 9600 |

---

*Wiring Diagram DMCM-WVAF | STM32F401CD | LM35 Sensor | v2.0*
