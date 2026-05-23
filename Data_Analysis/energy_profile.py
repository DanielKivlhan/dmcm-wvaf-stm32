"""
energy_profile.py — DMCM-WVAF Energy Profile Generator
========================================================
Menganalisis data dari dmcm_data.csv dan membuat data 3D
untuk profil efisiensi energi berdasarkan parameter WVAF:
  X: Frekuensi Sampling WVAF (Hz) — 50 sampai 500
  Y: Ukuran Window Adaptif (N) — 2 sampai 16
  Z: Konsumsi Arus Rata-rata (mA)

Model arus berdasarkan datasheet STM32F401CD + aktivitas
aktuator dari data sensor DMCM-WVAF simulasi Proteus.
"""

import csv
import os
import math

# ──────────────────────────────────────────────
# 1. Baca data sensor dari CSV
# ──────────────────────────────────────────────
def read_sensor_data(csv_path):
    """Baca data sensor dan hitung statistik aktivitas."""
    rows = []
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append(row)

    total_samples = len(rows)
    if total_samples == 0:
        print("[ERROR] CSV kosong!")
        return None

    # Hitung jumlah sampel per state
    count_normal  = sum(1 for r in rows if r['state'] == '0')
    count_warning = sum(1 for r in rows if r['state'] == '1')
    count_danger  = sum(1 for r in rows if r['state'] == '2')

    # Hitung jumlah sampel relay aktif
    count_relay   = sum(1 for r in rows if r['relay'] == '1')
    count_led_red = sum(1 for r in rows if r['led_red'] == '1')
    count_led_grn = sum(1 for r in rows if r['led_green'] == '1')

    # Hitung jumlah sampel window kecil (fast response)
    count_win_min = sum(1 for r in rows if r['window_size'] == '2')
    count_win_max = sum(1 for r in rows if r['window_size'] == '16')

    # Rata-rata ADC raw
    avg_raw = sum(int(r['raw']) for r in rows) / total_samples

    # Persentase masing-masing state
    pct_normal  = count_normal  / total_samples * 100
    pct_warning = count_warning / total_samples * 100
    pct_danger  = count_danger  / total_samples * 100

    stats = {
        'total_samples': total_samples,
        'pct_normal':    pct_normal,
        'pct_warning':   pct_warning,
        'pct_danger':    pct_danger,
        'pct_relay_on':  count_relay / total_samples * 100,
        'pct_led_red':   count_led_red / total_samples * 100,
        'pct_led_green': count_led_grn / total_samples * 100,
        'pct_win_min':   count_win_min / total_samples * 100,
        'pct_win_max':   count_win_max / total_samples * 100,
        'avg_raw':       avg_raw,
    }

    print(f"[INFO] Data sensor: {total_samples} sampel")
    print(f"       NORMAL:  {pct_normal:.1f}%  ({count_normal} sampel)")
    print(f"       WARNING: {pct_warning:.1f}%  ({count_warning} sampel)")
    print(f"       DANGER:  {pct_danger:.1f}%  ({count_danger} sampel)")
    print(f"       Relay ON:  {stats['pct_relay_on']:.1f}%")
    print(f"       LED Red:   {stats['pct_led_red']:.1f}%")
    print(f"       LED Green: {stats['pct_led_green']:.1f}%")
    print(f"       WIN=2 (fast): {stats['pct_win_min']:.1f}%")
    print(f"       WIN=16 (smooth): {stats['pct_win_max']:.1f}%")
    print(f"       Avg RAW:  {avg_raw:.0f}")

    return stats


# ──────────────────────────────────────────────
# 2. Model Konsumsi Arus STM32F401CD + DMCM-WVAF
# ──────────────────────────────────────────────
# Datasheet STM32F401xD/E @3.3V, HSI 16MHz:
#   - Run mode @16MHz:    ~5.5 mA
#   - CPU core scaling:   ~0.1 mA/MHz (approx)
#
# WVAF Filter:
#   - Higher sampling freq = more ADC conversions + more TIM IRQs
#   - Larger window = more memory access + more averaging ops
#
# Peripheral costs (per cycle):
#   - ADC conversion:    ~1.0 mA
#   - UART transmit:     ~0.3 mA per tx burst
#   - TIM IRQ overhead:  scales with frequency
#   - WVAF computation:  scales with window size
#
# Actuator (from sensor data distribution):
#   - LED Red:           ~2.0 mA
#   - LED Green:         ~2.0 mA
#   - Relay driver:      ~3.0 mA (BC547 base + RL1 coil)

def calc_current_mA(freq_hz, win_size, stats):
    """
    Hitung konsumsi arus rata-rata (mA) untuk:
      freq_hz   : Frekuensi sampling WVAF (50-500 Hz)
      win_size  : Ukuran window adaptif (2-16)
      stats     : Statistik dari data sensor

    Model menghitung CPU duty cycle:
      - Pada freq rendah (50Hz), CPU banyak idle (WFI/sleep between IRQs)
      - Pada freq tinggi (500Hz), CPU hampir selalu aktif
      - Window besar = lebih banyak operasi per IRQ = duty cycle lebih tinggi
    """
    # Normalized parameters (0..1)
    freq_norm = (freq_hz - 50.0) / 450.0    # 0 at 50Hz, 1 at 500Hz
    win_norm  = (win_size - 2.0) / 14.0     # 0 at WIN=2, 1 at WIN=16

    # ── CPU active current @16MHz HSI ──
    I_cpu_active = 5.5  # mA, STM32F401CD @16MHz Run mode

    # ── CPU sleep current (WFI between interrupts) ──
    I_cpu_sleep = 0.3   # mA, Sleep mode @16MHz

    # ── CPU duty cycle ──
    # At 50Hz/WIN=2: CPU active ~5% of time (mostly sleeping)
    # At 500Hz/WIN=16: CPU active ~95% of time (barely sleeps)
    # Processing time per IRQ scales with window size
    irq_time_us = 50.0 + 200.0 * win_norm**1.2    # 50-250 us per IRQ
    period_us = 1e6 / freq_hz                       # Period in us
    duty_cycle = min(0.95, irq_time_us / period_us * freq_hz / 50.0)
    duty_cycle = max(0.03, duty_cycle)

    I_cpu = I_cpu_active * duty_cycle + I_cpu_sleep * (1.0 - duty_cycle)

    # ── ADC current (active during conversion) ──
    I_adc = 1.2 * duty_cycle**0.7

    # ── WVAF computation overhead ──
    # More buffer reads + averaging with larger window
    I_wvaf = 0.3 * win_norm * duty_cycle + 0.05

    # ── UART transmit (scales with frequency) ──
    I_uart = 0.4 * (freq_hz / 200.0)**0.7

    # ── TIM2 IRQ + peripheral overhead ──
    I_periph = 0.1 + 0.3 * freq_norm

    # ── Actuator current (from actual sensor data) ──
    # Weighted by observed state distribution
    I_led_red   = 2.0 * (stats['pct_led_red'] / 100.0)
    I_led_green = 2.0 * (stats['pct_led_green'] / 100.0)
    I_relay     = 3.0 * (stats['pct_relay_on'] / 100.0)
    I_actuator  = I_led_red + I_led_green + I_relay

    # ── Total ──
    I_total = I_cpu + I_adc + I_wvaf + I_uart + I_periph + I_actuator

    return I_total


# ──────────────────────────────────────────────
# 3. Generate data 3D untuk GnuPlot
# ──────────────────────────────────────────────
def generate_3d_data(stats, output_path):
    """
    Generate file data 3D dalam format GnuPlot:
    Setiap blok = satu nilai freq, dipisahkan baris kosong.
    Kolom: Frekuensi_Sampling(Hz)  Window_Size(N)  Arus(mA)
    """
    freqs = list(range(50, 501, 10))     # 50, 60, ..., 500 Hz
    wins  = [w / 10.0 for w in range(20, 161, 3)]  # 2.0, 2.3, ..., 16.0

    with open(output_path, 'w') as f:
        f.write("# Profil Konsumsi Daya DMCM-WVAF (STM32F401CD)\n")
        f.write("# Data sensor: {0} sampel (Proteus Virtual Terminal)\n".format(stats['total_samples']))
        f.write("# State: NORMAL={0:.1f}% WARNING={1:.1f}% DANGER={2:.1f}%\n".format(
            stats['pct_normal'], stats['pct_warning'], stats['pct_danger']))
        f.write("# Kolom: Frekuensi_Sampling(Hz)  Window_Size(N)  Konsumsi_Arus(mA)\n")
        f.write("#\n")

        for freq in freqs:
            for win in wins:
                current = calc_current_mA(freq, win, stats)
                f.write(f"{freq}\t{win:.1f}\t{current:.4f}\n")
            f.write("\n")  # Baris kosong = pemisah blok GnuPlot

    print(f"\n[OK] Data 3D ditulis ke: {output_path}")
    print(f"     Grid: {len(freqs)} x {len(wins)} = {len(freqs)*len(wins)} titik data")
    print(f"     Freq range:  {freqs[0]}-{freqs[-1]} Hz")
    print(f"     Win  range:  {wins[0]:.0f}-{wins[-1]:.0f}")

    # Tampilkan titik referensi
    print(f"\n     Titik referensi:")
    for freq in [50, 200, 350, 500]:
        for win in [2, 9, 16]:
            I = calc_current_mA(freq, win, stats)
            print(f"       f={freq}Hz, win={win} -> I={I:.2f} mA")


# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────
if __name__ == '__main__':
    base_dir = os.path.dirname(os.path.abspath(__file__))
    csv_input  = os.path.join(base_dir, 'dmcm_data.csv')
    data_output = os.path.join(base_dir, 'energy_profile_data.dat')

    print("=" * 60)
    print("DMCM-WVAF Energy Profile Generator")
    print("=" * 60)

    stats = read_sensor_data(csv_input)
    if stats:
        generate_3d_data(stats, data_output)
