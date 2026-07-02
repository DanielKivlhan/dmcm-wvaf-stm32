# ============================================================
# plot_lm35_excel.gp
# GNU Plot script — DMCM-WVAF LM35 IEEE Style
# Data source: dmcm_lm35_data.csv (Excel-compatible format)
# Output: PNG (1600x2000) + PDF (IEEE 3.5in column)
# ============================================================
# Jalankan dengan:
#   gnuplot plot_lm35_excel.gp
# ============================================================

set encoding utf8
set datafile separator ","

# ── Path Data (CSV yang bisa dibuka Excel) ───────────────────
DATA = "C:/Users/danil/Downloads/DMCM-WVAF/Data_Analysis/dmcm_lm35_data.csv"

# ── Kolom mapping dari CSV ───────────────────────────────────
# Col 1 : index
# Col 2 : time_s
# Col 3 : T_raw
# Col 4 : T_filtered
# Col 5 : N_win
# Col 6 : |DeltaT|
# Col 7 : State  (0=Normal, 1=Warning, 2=Danger)
# Col 8 : Relay
# Col 9 : LED_Red
# Col 10: LED_Green

# ── Batas plot ───────────────────────────────────────────────
XMIN  = 0.0
XMAX  = 104.4
YMIN  = 17
YMAX  = 45
TWARN = 30.0
TCRIT = 40.0

# ── Line styles (warna sesuai dmcm_lm35_ieee.png) ───────────
set style line 10  lc rgb "#CC0000" lw 1.5 lt 1 pt 7  ps 0.55   # T_raw   (Merah)
set style line 11  lc rgb "#1a5ecc" lw 1.5 lt 1 pt 5  ps 0.45   # T_filt  (Biru)
set style line 12  lc rgb "#555555" lw 1.0 lt 2 dt (6,4)         # Threshold garis
set style line 20  lc rgb "#E65C00" lw 2.0 lt 1                  # N_win   (Orange)
set style line 21  lc rgb "#555555" lw 2.5 lt 1                  # |DeltaT|(Abu impulse)
set style line 30  lc rgb "#1a9c2a" lw 2.0 lt 1                  # State S (Hijau)
set style line 40  lc rgb "#CC0000" lw 2.0 lt 1                  # Relay   (Merah)
set style line 41  lc rgb "#E65C00" lw 1.5 lt 2 dt (8,4)         # LED_Red (Orange dash)
set style line 42  lc rgb "#1a9c2a" lw 1.5 lt 3 dt (4,4)         # LED_Grn (Hijau dash)

# ── Grid dan border ──────────────────────────────────────────
set grid xtics ytics lc rgb "#cccccc" lw 0.4 lt 0
set border lw 1.0
set tics font "Arial,9"

# ============================================================
# OUTPUT 1 — PNG (untuk Word / Laporan / Preview)
# ============================================================
set terminal pngcairo enhanced color font "Arial,10" \
    linewidth 1.5 rounded size 1600,2000 background "#ffffff"
set output "C:/Users/danil/Downloads/DMCM-WVAF/Data_Analysis/dmcm_lm35_excel.png"

set multiplot layout 4,1 \
    title "{/:Bold DMCM-WVAF Real-Time LM35 Temperature Monitoring & Control}" \
    font "Arial,12" offset 0,0.8

# ──────────────────────────────────────────────────────────
# Subplot (a) — Temperature Signal: Raw vs. WVAF-Filtered
# ──────────────────────────────────────────────────────────
set tmargin at screen 0.97
set bmargin at screen 0.75
set xrange [XMIN:XMAX]
set yrange [YMIN:YMAX]
set ytics YMIN,5,YMAX
set ylabel "Temperature ({/Symbol \260}C)" font "Arial,10" offset -1,0
set xlabel ""
set title "(a) Temperature Signal: Raw vs. WVAF-Filtered" \
    font "Arial,10" offset 0,-0.5 noenhanced

# Garis threshold
set arrow 1 from XMIN,TCRIT to XMAX,TCRIT nohead ls 12 lw 1.0
set arrow 2 from XMIN,TWARN to XMAX,TWARN nohead lw 1.0 \
    lc rgb "#aaaaaa" dt (6,4)

# Label threshold
set label 1 "{/Italic T}_{crit} = 40 {/Symbol \260}C" \
    at XMAX-0.05*(XMAX-XMIN), TCRIT+0.8 right font "Arial,8" tc rgb "#555555"
set label 2 "{/Italic T}_{warn} = 30 {/Symbol \260}C" \
    at XMAX-0.05*(XMAX-XMIN), TWARN+0.8 right font "Arial,8" tc rgb "#888888"

set key top right font "Arial,9" samplen 2 spacing 1.1 box lw 0.5

# skip 1 = lewati baris header CSV
plot DATA skip 1 using 2:3 with linespoints ls 10 title "{/Italic T}_{raw}", \
     DATA skip 1 using 2:4 with linespoints ls 11 title "{/Italic T}_{ft} (WVAF)"

unset arrow 1; unset arrow 2
unset label 1; unset label 2

# ──────────────────────────────────────────────────────────
# Subplot (b) — Adaptive Window Size N_win dan |DeltaT|
# ──────────────────────────────────────────────────────────
set tmargin at screen 0.72
set bmargin at screen 0.52
set title "(b) Adaptive Window Size {/Italic N}_{win} and Rate-of-Change |{/Symbol D}{/Italic T}|" \
    enhanced font "Arial,10" offset 0,-0.5
set ylabel "{/Italic N}_{win}" font "Arial,10" tc rgb "#E65C00" offset -1,0
set yrange [0:10]
set ytics 0,2,10 tc rgb "#E65C00"
set y2label "|{/Symbol D}{/Italic T}| ({/Symbol \260}C)" \
    font "Arial,10" tc rgb "#777777" offset 1.5,0
set y2range [0:6]
set y2tics 0,1,5 tc rgb "#777777"
set ytics nomirror
set y2tics

# Garis threshold delta T
set arrow 10 from XMIN, second 3.0 to XMAX, second 3.0 \
    nohead lw 0.8 lc rgb "#999999" dt (4,4)
set label 10 "|{/Symbol D}{/Italic T}|_{th}=3" \
    at XMIN+0.78*(XMAX-XMIN), second 3.4 font "Arial,8" tc rgb "#777777"

set key top right font "Arial,9" samplen 2 spacing 1.1 box lw 0.5

plot DATA skip 1 using 2:5 with steps    ls 20 axes x1y1 title "{/Italic N}_{win}", \
     DATA skip 1 using 2:6 with impulses ls 21 axes x1y2 title "|{/Symbol D}{/Italic T}|"

unset arrow 10
unset label 10
unset y2label
unset y2tics
unset ytics
set ytics mirror

# ──────────────────────────────────────────────────────────
# Subplot (c) — State Machine Classification S(t)
# ──────────────────────────────────────────────────────────
set tmargin at screen 0.49
set bmargin at screen 0.30
set title "(c) State Machine Classification S(t)" \
    font "Arial,10" offset 0,-0.5 noenhanced
set yrange [-0.5:2.7]
set ytics ("Normal" 0, "Warning" 1, "Danger" 2) tc rgb "#000000"
set ylabel "State {/Italic S}" font "Arial,10" offset -1,0
set key top right font "Arial,9" samplen 2 spacing 1.1 box lw 0.5

plot DATA skip 1 using 2:7 with steps ls 30 lw 2.0 \
    title "Criticality Level {/Italic S}({/Italic t})"

# ──────────────────────────────────────────────────────────
# Subplot (d) — Actuator Outputs (Relay & LEDs)
# ──────────────────────────────────────────────────────────
set tmargin at screen 0.27
set bmargin at screen 0.07
set title "(d) Actuator Outputs (Relay & LEDs)" \
    font "Arial,10" offset 0,-0.5 noenhanced
set yrange [-0.15:1.3]
set ytics ("Off" 0, "On" 1) tc rgb "#000000"
set ylabel "Output" font "Arial,10" offset -1,0
set xlabel "{/Italic t} (s)" font "Arial,10" offset 0,-0.3
set key top right font "Arial,9" samplen 2.5 spacing 1.1 box lw 0.5

# Col 10 = LED_Green, Col 9 = LED_Red, Col 8 = Relay
plot DATA skip 1 using 2:($10*0.97) with steps ls 42 lw 1.5 title "LED_{Green}", \
     DATA skip 1 using 2:($9*1.00)  with steps ls 41 lw 1.5 title "LED_{Red}", \
     DATA skip 1 using 2:($8*1.00)  with steps ls 40 lw 2.0 title "Relay"

unset multiplot
unset output

# ============================================================
# OUTPUT 2 — PDF (IEEE Publication, kolom tunggal 3.5in)
# ============================================================
set terminal pdfcairo enhanced color font "Arial,10" \
    linewidth 1.2 rounded size 3.5in,4.375in background "#ffffff"
set output "C:/Users/danil/Downloads/DMCM-WVAF/Data_Analysis/dmcm_lm35_excel.pdf"

set grid xtics ytics lc rgb "#cccccc" lw 0.4 lt 0
set border lw 1.0
set tics font "Arial,9"

set multiplot layout 4,1 \
    title "{/:Bold DMCM-WVAF Real-Time LM35 Temperature Monitoring & Control}" \
    font "Arial,11" offset 0,0.8

# Subplot (a) PDF
set tmargin at screen 0.97
set bmargin at screen 0.75
set xrange [XMIN:XMAX]
set yrange [YMIN:YMAX]
set ytics YMIN,5,YMAX
set ylabel "Temperature ({/Symbol \260}C)" font "Arial,9" offset -0.5,0
set xlabel ""
set title "(a) Temperature Signal: Raw vs. WVAF-Filtered" \
    font "Arial,9" offset 0,-0.3 noenhanced
set arrow 1 from XMIN,TCRIT to XMAX,TCRIT nohead ls 12 lw 1.0
set arrow 2 from XMIN,TWARN to XMAX,TWARN nohead lw 1.0 \
    lc rgb "#aaaaaa" dt (6,4)
set label 1 "{/Italic T}_{crit} = 40 {/Symbol \260}C" \
    at XMAX-0.05*(XMAX-XMIN), TCRIT+0.8 right font "Arial,7.5"
set label 2 "{/Italic T}_{warn} = 30 {/Symbol \260}C" \
    at XMAX-0.05*(XMAX-XMIN), TWARN+0.8 right font "Arial,7.5"
set key top right font "Arial,8.5" samplen 2 spacing 1.1 box lw 0.5
plot DATA skip 1 using 2:3 with linespoints ls 10 title "{/Italic T}_{raw}", \
     DATA skip 1 using 2:4 with linespoints ls 11 title "{/Italic T}_{ft} (WVAF)"
unset arrow 1; unset arrow 2; unset label 1; unset label 2

# Subplot (b) PDF
set tmargin at screen 0.72
set bmargin at screen 0.52
set title "(b) Adaptive Window Size {/Italic N}_{win} and Rate-of-Change |{/Symbol D}{/Italic T}|" \
    enhanced font "Arial,9" offset 0,-0.3
set ylabel "{/Italic N}_{win}" font "Arial,9" tc rgb "#E65C00" offset -0.5,0
set yrange [0:10]
set ytics 0,2,10 tc rgb "#E65C00"
set y2label "|{/Symbol D}{/Italic T}| ({/Symbol \260}C)" \
    font "Arial,9" tc rgb "#777777" offset 1.5,0
set y2range [0:6]
set y2tics 0,1,5 tc rgb "#777777"
set ytics nomirror; set y2tics
set arrow 10 from XMIN, second 3.0 to XMAX, second 3.0 \
    nohead lw 0.8 lc rgb "#999999" dt (4,4)
set label 10 "|{/Symbol D}{/Italic T}|_{th}=3" \
    at XMIN+0.78*(XMAX-XMIN), second 3.4 font "Arial,7.5" tc rgb "#777777"
set key top right font "Arial,8.5" samplen 2 spacing 1.1 box lw 0.5
plot DATA skip 1 using 2:5 with steps    ls 20 axes x1y1 title "{/Italic N}_{win}", \
     DATA skip 1 using 2:6 with impulses ls 21 axes x1y2 title "|{/Symbol D}{/Italic T}|"
unset arrow 10; unset label 10
unset y2label; unset y2tics; unset ytics; set ytics mirror

# Subplot (c) PDF
set tmargin at screen 0.49
set bmargin at screen 0.30
set title "(c) State Machine S(t)" font "Arial,9" offset 0,-0.3 noenhanced
set yrange [-0.5:2.7]
set ytics ("Normal" 0, "Warning" 1, "Danger" 2) font "Arial,9"
set ylabel "State {/Italic S}" font "Arial,9" offset -0.5,0
set key top right font "Arial,8.5" samplen 2 spacing 1.1 box lw 0.5
plot DATA skip 1 using 2:7 with steps ls 30 lw 2.0 \
    title "{/Italic S}({/Italic t})"

# Subplot (d) PDF
set tmargin at screen 0.27
set bmargin at screen 0.07
set title "(d) Actuator Outputs" font "Arial,9" offset 0,-0.3 noenhanced
set yrange [-0.15:1.3]
set ytics ("Off" 0, "On" 1) font "Arial,9"
set ylabel "Output" font "Arial,9" offset -0.5,0
set xlabel "{/Italic t} (s)" font "Arial,9" offset 0,-0.3
set key top right font "Arial,8.5" samplen 2.5 spacing 1.1 box lw 0.5
plot DATA skip 1 using 2:($10*0.97) with steps ls 42 lw 1.5 title "LED_{Green}", \
     DATA skip 1 using 2:($9*1.00)  with steps ls 41 lw 1.5 title "LED_{Red}", \
     DATA skip 1 using 2:($8*1.00)  with steps ls 40 lw 2.0 title "Relay"

unset multiplot
unset output

# ============================================================
# Selesai — file output:
#   dmcm_lm35_excel.png   (preview PNG)
#   dmcm_lm35_excel.pdf   (IEEE PDF)
# Data source:
#   dmcm_lm35_data.csv    (buka dengan Excel/LibreOffice)
#   dmcm_lm35_data.xlsx   (Excel terformat, generate dengan
#                          python generate_excel_data.py)
# ============================================================
