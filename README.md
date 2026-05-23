# 🔋 Deterministic Mixed-Criticality Matrix dengan Variable-Window Adaptive Filtering (DMCM-WVAF) pada STM32F401CD

Repository ini memuat berkas simulasi lengkap, implementasi firmware, dan analisis dinamis dari sebuah framework keselamatan instrumentasi berbasis *bare-metal* (**DMCM-WVAF**). Proyek ini berfokus pada eliminasi latensi percabangan perangkat lunak (*software branching latency*) dan penekanan derau sensor frekuensi tinggi untuk aplikasi IoT *Safety-Critical* tanpa beban *overhead* dari RTOS komersial.

## 🎯 Ringkasan
Pada sistem tertanam keselamatan-kritis (*safety-critical embedded systems*) modern (seperti *safety loops* industri, avionik, dan perangkat medis), determinisme eksekusi dan respons transien instan adalah hal yang mutlak. Filter digital tradisional sering kali memperkenalkan penundaan fasa (*phase lag*) yang parah saat terjadi lonjakan sensor secara mendadak, sementara struktur kontrol percabangan bersarang (*nested if-else*) menciptakan ketidakpastian waktu eksekusi (*timing jitter*).

Proyek ini mengimplementasikan framework **DMCM-WVAF** sepenuhnya pada arsitektur **ARM Cortex-M4** (*bare-metal*) menggunakan mikrokontroler STM32F401CD. Dengan merekayasa partisi temporal berbasis perangkat keras (*hardware-enforced temporal partition*) bersama dengan tabel lookup matriks status konstan $O(1)$, sistem berhasil mencapai determinisme eksekusi dalam skala mikrodetik dan waktu respons darurat yang sangat instan.

## 🚀 Fitur Utama
* **Variable-Window Adaptive Filtering (WVAF):** Penyaringan sinyal digital adaptif secara langsung (*on-the-fly*). Ukuran jendela filter secara dinamis menyusut hingga $W_{\min} = 2$ saat terjadi transien sensor yang tajam untuk memotong penundaan fasa sebesar 93.3% ($\approx 2.5$ ms waktu respons), dan melebar hingga $W_{\max} = 16$ pada kondisi mantap (*steady-state*) untuk menekan derau kuantisasi $kT/C$ sebesar 75% (reduksi 12 dB).
* **Software-Based Temporal Partitioning (SBTP):** Isolasi loop tugas keselamatan yang dipaksa oleh perangkat keras menggunakan interupsi periodik `TIM2` (setiap 5 ms). Operasi keselamatan kritis berjalan secara eksklusif di dalam konteks ISR (*Interrupt Service Routine*) berprioritas tinggi, melindungi sistem dari risiko macet (*freeze/infinite loop*) pada thread latar belakang.
* **Jitter-Free $O(1)$ State-Matrix Lookup:** Menggantikan logika percabangan bersarang (*nested if-else*) konvensional dengan array lookup 2D konstan yang disimpan di dalam memori FLASH. Perintah aktuasi dipetakan tepat dalam **3 instruksi assembly ARM**, mereduksi *timing jitter* komputasi hingga nol mutlak.
* **Atomic Actuator Actuation:** Memanfaatkan register perangkat keras atomik single-cycle Bit Set/Reset Register (`GPIOB->BSRR`) untuk memicu aktuator fisik (LED indikator, driver transistor, dan Relay/Buzzer keselamatan) secara instan tanpa beban *overhead* dari operasi perangkat lunak *read-modify-write*.

## 🧠 Arsitektur Sistem & Aliran Data

Arsitektur DMCM secara ketat memisahkan prioritas pemrosesan menjadi dua zona eksekusi terisolasi untuk mencegah penyebaran kegagalan (*failure propagation*):

```text
                  ┌────────────────────────────────────────┐
                  │         PERANGKAT KERAS STM32          │
                  └───────────────────┬────────────────────┘
                                      │
                     [ 5 ms Hardware Interrupt Tick ]
                                      ▼
     ┌─────────────────────────────────────────────────────────────────┐
     │  ZONA KESELAMATAN KRITIS (Konteks TIM2 ISR) - Prioritas Tinggi  │
     ├─────────────────────────────────────────────────────────────────┤
     │ 1. Sampling ADC Atomik (PA0) ──► ADC1->DR                       │
     │ 2. Kalkulasi Filter Adaptif Jendela Variabel (WVAF)             │
     │ 3. Lookup Matriks Status O(1) ──► u_k = M[State][Mode]          │
     │ 4. Manipulasi Pin GPIO Bebas Jitter ──► GPIOB->BSRR             │
     │ 5. Pipeline Telemetri UART Non-blocking                         │
     └────────────────────────────────┬────────────────────────────────┘
                                      │
                        [ Hardware Interrupt Return ]
                                      ▼
     ┌─────────────────────────────────────────────────────────────────┐
     │  ZONA NON-KRITIS (Main Background Loop) - Best-Effort           │
     ├─────────────────────────────────────────────────────────────────┤
     │ • Pembaruan dan Refresh Tampilan Layar LCD                      │
     │ • Pencatatan Data Sensor Non-Kritis ke Memori Flash             │
     │ • Antarmuka Pengguna (UI) & Penyesuaian Parameter               │
     └─────────────────────────────────────────────────────────────────┘
```
## 📁 Struktur Repositori
* `📂 Firmware/` : Berisi *source code* lengkap berbasis *bare-metal* C/C++ yang dihasilkan melalui STM32CubeMX dan *workspace* IDE Keil $\mu$Vision yang dioptimalkan dengan ARM Compiler 6 (AC6).
* `📂 Simulation/` : Menyediakan file lembar kerja Proteus Professional 8.17 yang memuat validasi rangkaian elektronik interaktif dan konfigurasi osiloskop virtual.
* `📂 Data_Analysis/` : Mencakup log telemetri CSV mentah (`data.csv`), skrip pemformatan grafik standar publikasi IBM/IEEE menggunakan GNUPlot, dan profil pemetaan spasial 3D (`energy_profile_3d.png`).
* `📂 Report/` : Berisi *source code* laporan akademik lengkap berbasis LaTeX (`.tex`), konfigurasi paket (*packages*), dan figur resolusi tinggi yang digunakan untuk kompilasi dokumen akhir.

## 🛠️ Memulai Penggunaan

### 1. Validasi Simulasi Perangkat Keras (Proteus)
1. Buka folder `Simulation/`.
2. Jalankan file proyek skematik menggunakan **Proteus Design Suite 8.17**.
3. Tekan tombol **Run** untuk mengamati interaksi *real-time*. Ubah nilai potensiometer linier (RV1/RV2) untuk memverifikasi transisi status antara kondisi `NORMAL`, `WARNING`, dan `DANGER` pada Virtual Terminal dan relay fisik.

### 2. Pemetaan Profil Energi 3D
1. Masuk ke folder `Data_Analysis/`.
2. Buka dataset telemetri 3D menggunakan perangkat lunak plot permukaan pilihan Anda (atau jalankan skrip plot yang tersedia).
3. Analisis grafik distribusi daya spasial (`energy_profile_3d.png`) untuk memverifikasi konsumsi daya ultra-rendah ($\approx 1.2\,\mu\text{W}$) yang dicapai selama konfigurasi kondisi mantap (*steady-state*).

### 3. Kompilasi Laporan Dokumen
1. Buka berkas dokumen LaTeX di dalam folder `Report/`.
2. Compile menggunakan kompiler **PDFLaTeX / XeLaTeX** melalui Overleaf atau TeXstudio.
3. Struktur tabel telah menggunakan makro `>{\centering\arraybackslash}` untuk memastikan luaran tata letak dokumentasi ilmiah yang sejajar dan rapi.

## 📈 Hasil Evaluasi Sistem
* **Penekanan Derau Kondisi Mantap:** Reduksi amplitudo derau sebesar 12 dB (atenuasi 75%).
* **Latensi Respons Transien Darurat:** Dipangkas dari yang semula 37.5 ms (pada filter konvensional dengan jendela tetap) menjadi hanya **2.5 ms** (jalur adaptif WVAF)—menghasilkan reduksi latensi sebesar 93.3%.
* **Utilisasi Core CPU:** Operasi keselamatan kritis hanya mengonsumsi **3.6%** dari total ketersediaan core CPU, menyisakan **96.4%** *resource* bebas yang dapat digunakan untuk mengeksekusi tugas telemetri non-kritis di latar belakang *loop* utama.

## 👥 Penulis
* **Daniel Kivlhan Katoroy** (NRP. 2042241004)
* **Faris Ahmad Holili** (NRP. 2042241028)

*Dosen Pengampu: Ahmad Radhy, S.Si., M.Si.*\ 
**Program Studi Teknologi Rekayasa Instrumentasi, Departemen Teknik Instrumentasi, Fakultas Vokasi, Institut Teknologi Sepuluh Nopember (ITS), Surabaya, Indonesia.**
