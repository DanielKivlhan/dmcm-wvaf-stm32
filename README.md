# 🔋 Deterministic Mixed-Criticality Matrix with Variable-Window Adaptive Filtering (DMCM-WVAF) on STM32F401CD

This repository contains the complete simulation workspace, firmware implementation, and dynamic analysis of a bare-metal instrumentation safety framework (**DMCM-WVAF**). The project focuses on eliminating software branching latency and suppressing high-frequency sensor noise for Safety-Critical IoT applications without the overhead of a commercial RTOS.

## 🎯 Overview
In modern safety-critical embedded systems (e.g., industrial safety loops, avionics, and medical units), execution determinism and instantaneous transient responses are non-negotiable. Traditional digital filters introduce severe phase lag during sudden sensor spikes, while conventional nested conditional branching structures (`if-else`) create unpredictable execution timing jitter.

This project implements the **DMCM-WVAF** framework entirely on a bare-metal **ARM Cortex-M4** architecture using the STM32F401CD microcontroller. By engineering a hardware-enforced temporal partition alongside a flat $O(1)$ constant state-matrix lookup table, the system achieves microsecond-scale execution determinism and near-instantaneous emergency response times.

## 🚀 Key Features
* **Variable-Window Adaptive Filtering (WVAF):** Real-time, on-the-fly digital signal filtering. The filter window size dynamically shrinks to $W_{\min} = 2$ during sharp sensor transients to slash phase lag by 93.3% ($\approx 2.5$ ms response time), and expands to $W_{\max} = 16$ during steady-state conditions to suppress $kT/C$ quantization noise by 75% (12 dB reduction).
* **Software-Based Temporal Partitioning (SBTP):** Hardware-enforced task isolation utilizing a periodic `TIM2` timer interrupt (5 ms tick). Critical safety loops execute exclusively within the high-priority ISR (Interrupt Service Routine) context, fully insulating vital operations from software hangs or infinite loops in the background thread.
* **Jitter-Free $O(1)$ State-Matrix Lookup:** Replaces conventional nested branching logic with a pre-computed 2D lookup array stored inside the FLASH memory. Actuator driving tokens are mapped in exactly **3 ARM assembly instructions**, reducing algorithmic timing jitter to absolute zero.
* **Atomic Actuator Actuation:** Utilizes the single-cycle atomic Bit Set/Reset Register (`GPIOB->BSRR`) to trigger physical alarms (LED status indicators, transistor drivers, and safety Relays/Buzzers) instantly, completely bypassing read-modify-write software overhead.

## 🧠 System Architecture & Data Flow

The DMCM architecture strictly isolates processing priorities into two distinct execution zones to prevent failure propagation:

```text
                  ┌────────────────────────────────────────┐
                  │          STM32F401CD HARDWARE          │
                  └───────────────────┬────────────────────┘
                                      │
                     [ 5 ms Hardware Interrupt Tick ]
                                      ▼
     ┌─────────────────────────────────────────────────────────────────┐
     │  SAFETY-CRITICAL ZONE (TIM2 ISR Context) - High Priority        │
     ├─────────────────────────────────────────────────────────────────┤
     │ 1. Atomic ADC Sampling (PA0) ──► ADC1->DR                       │
     │ 2. Variable-Window Adaptive Filtering (WVAF Calculation)        │
     │ 3. O(1) State-Matrix Lookup ──► u_k = M[State][Mode]            │
     │ 4. Jitter-Free GPIO Bit-Masking ──► GPIOB->BSRR (LEDs & Relay)  │
     │ 5. Non-blocking UART Telemetry Pipeline                         │
     └────────────────────────────────┬────────────────────────────────┘
                                      │
                        [ Hardware Interrupt Return ]
                                      ▼
     ┌─────────────────────────────────────────────────────────────────┐
     │  NON-CRITICAL ZONE (Main Background Loop) - Best-Effort         │
     ├─────────────────────────────────────────────────────────────────┤
     │ • LCD Display Refresh & Interface Update                        │
     │ • Non-critical Sensor Data Logging to Flash Memory              │
     │ • User Parameter Tuning & UI Interface Execution                │
     └─────────────────────────────────────────────────────────────────┘
```
## 📁 Repository Structure
* `📂 Firmware/` : Contains the complete bare-metal C/C++ source code generated via STM32CubeMX and the Keil $\mu$Vision IDE workspace optimized with ARM Compiler 6 (AC6).
* `📂 Simulation/` : Features the comprehensive Proteus Professional 8.17 workspace containing the interactive electronics circuit validation and virtual oscilloscope setups.
* `📂 Data_Analysis/` : Includes the raw CSV telemetry logs (`data.csv`), standard IBM/IEEE-formatted GNUPlot scripts, and 3D spatial energy mapping profiles (`energy_profile_3d.png`).
* `📂 Report/` : Contains the full academic LaTeX (`.tex`) source code, package configurations, and high-resolution figures used to compile the final document.

## 🛠️ Getting Started

### 1. Hardware Simulation Validation (Proteus)
1. Navigate to the `Simulation/` folder.
2. Open the schematic workspace using **Proteus Design Suite 8.17**.
3. Press the **Run** button to observe real-time interaction. Adjust the linear potentiometers (RV1/RV2) to verify dynamic state transitions between `NORMAL`, `WARNING`, and `DANGER` states on both the Virtual Terminal and physical relays.

### 2. 3D Energy Profile Mapping
1. Navigate to the `Data_Analysis/` folder.
2. Open the 3D telemetry dataset using your preferred surface plotting software (or execute the provided script).
3. Analyze the spatial power distribution graph (`energy_profile_3d.png`) to verify the ultra-low power consumption ($\approx 1.2\,\mu\text{W}$) achieved during steady-state runtime configurations.

### 3. Compiling the Academic Report
1. Open the LaTeX document source files inside the `Report/` folder.
2. Compile the project using **PDFLaTeX / XeLaTeX** via Overleaf or TeXstudio.
3. The table structures utilize `>{\centering\arraybackslash}` macros to ensure a perfectly aligned, publication-ready scientific documentation layout.

## 📈 Evaluation Results
* **Steady-State Noise Suppression:** 12 dB amplitude reduction (75% noise attenuation).
* **Emergency Transient Response Latency:** Cut down from 37.5 ms (fixed filtering window) to **2.5 ms** (WVAF adaptive path)—yielding a **93.3% reduction** in response latency.
* **CPU Core Utilization:** Safety-critical operations consume only **3.6%** of the core CPU availability, leaving **96.4%** free for non-critical best-effort background logging and UI tasks.

## 👥 Authors
* **Daniel Kivlhan Katoroy** (NRP. 2042241004)
* **Faris Ahmad Holili** (NRP. 2042241028)

*Advisor: Ahmad Radhy, S.Si., M.Si.* \
**Department of Instrumentation Engineering, Faculty of Vocational Studies, Institut Teknologi Sepuluh Nopember (ITS), Surabaya, Indonesia.**
