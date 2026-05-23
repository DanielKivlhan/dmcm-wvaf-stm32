# ==============================================================
# plot_ieee.gp — IEEE Journal Publication-Quality Plot
# DMCM-WVAF Real-Time Sensor Analysis
# ==============================================================
# Style: IEEE Transactions / Conference format
#   - Serif font (Times New Roman)
#   - Minimal decoration, high information density
#   - Grayscale-friendly with distinguishable line patterns
#   - 300 DPI equivalent resolution
#   - Compact, dense labeling
# ==============================================================

# ── File paths ────────────────────────────────────────────────
DATAFILE = 'c:/Users/danil/Downloads/GnuPlot/data.csv'
OUTFILE  = 'c:/Users/danil/Downloads/GnuPlot/dmcm_ieee.png'

# ── Terminal — 300 DPI equivalent (3600x2800 px) ──────────────
set terminal pngcairo size 3600,2800 enhanced \
    font 'Times New Roman,24' \
    fontscale 1.0 \
    linewidth 1.5 \
    background "#ffffff"
set output OUTFILE

# ── Data ──────────────────────────────────────────────────────
set datafile separator ','
set encoding utf8

# ── Color Palette (IEEE-friendly, print-safe) ─────────────────
# Distinct colors that also work in grayscale/B&W printing
COL_TEXT     = "#000000"
COL_AXIS     = "#000000"
COL_GRID     = "#d0d0d0"
COL_BORDER   = "#000000"

COL_RAW      = "#d62728"       # Red (raw signal)
COL_FLT      = "#1f77b4"       # Blue (filtered)
COL_WIN      = "#ff7f0e"       # Orange (window)
COL_DELTA    = "#7f7f7f"       # Gray (delta impulses)
COL_STATE    = "#2ca02c"       # Green (state)
COL_RELAY    = "#d62728"       # Red (relay)
COL_LED_R    = "#ff7f0e"       # Orange (LED red)
COL_LED_G    = "#2ca02c"       # Green (LED green)

COL_THRESH_W = "#999999"       # Gray dashed
COL_THRESH_D = "#555555"       # Dark gray dashed

# ── Line Styles (IEEE: distinct dash patterns for B&W) ────────
#  Raw:      solid red, circle marker
#  Filtered: solid blue, square marker
set style line 1  lc rgb COL_RAW   lt 1 lw 2.5 pt 7  ps 0.9 dt 1
set style line 2  lc rgb COL_FLT   lt 1 lw 3.0 pt 5  ps 1.0 dt 1
#  Window:   solid orange, no marker (steps)
#  Delta:    gray impulses
set style line 3  lc rgb COL_WIN   lt 1 lw 2.8 dt 1
set style line 4  lc rgb COL_DELTA lt 1 lw 1.5 dt 1
#  State:    solid green (steps)
set style line 5  lc rgb COL_STATE lt 1 lw 3.0 dt 1
#  Relay:    solid red, thick
set style line 6  lc rgb COL_RELAY lt 1 lw 3.5 dt 1
#  LED Red:  dashed orange
set style line 7  lc rgb COL_LED_R lt 1 lw 2.5 dt (18,6)
#  LED Green: dash-dot green
set style line 8  lc rgb COL_LED_G lt 1 lw 2.5 dt (18,6,4,6)

# ── Global Settings ───────────────────────────────────────────
set border linecolor rgb COL_BORDER linewidth 2.0
set grid xtics ytics lc rgb COL_GRID lw 0.8 lt 1 dt (6,3)
set tics nomirror
set xtics textcolor rgb COL_TEXT font 'Times New Roman,20'
set ytics textcolor rgb COL_TEXT font 'Times New Roman,20'
set mxtics 5
set mytics 2

# ── Multiplot ─────────────────────────────────────────────────
set multiplot layout 4,1 \
    title "{/:Bold=30 DMCM-WVAF Real-Time Monitoring Results}" \
    font 'Times New Roman,30' textcolor rgb COL_TEXT

set lmargin 16
set rmargin 6
set tmargin 2.2
set bmargin 1.0

# ==============================================================
# PANEL (a) — ADC Raw vs WVAF Filtered
# ==============================================================
set title "{/:Bold=24 (a)}" textcolor rgb COL_TEXT offset -60,0
set xlabel "" textcolor rgb COL_TEXT
set ylabel "{/Times-New-Roman:Italic=22 V}_{ADC} (counts)" \
    font 'Times New Roman,22' textcolor rgb COL_TEXT offset 0,0
set format x ""
set yrange [0:4500]
set ytics 500
set xrange [*:*]
set key outside right top vertical font 'Times New Roman,18' \
    textcolor rgb COL_TEXT spacing 1.6 samplen 4 width -2 \
    box lc rgb "#aaaaaa" lw 1.0

# Threshold dashed lines (IEEE style: annotated reference lines)
set arrow 1 from graph 0, first 1365 to graph 1, first 1365 \
    nohead lc rgb COL_THRESH_W lw 1.8 dt (15,8)
set arrow 2 from graph 0, first 2730 to graph 1, first 2730 \
    nohead lc rgb COL_THRESH_D lw 1.8 dt (15,8)

# Inline annotations (IEEE style)
set label 1 "{/Times-New-Roman:Italic=17 T}_{warn} = 1365" \
    at graph 0.72, first 1530 left tc rgb "#555555" font 'Times New Roman,17'
set label 2 "{/Times-New-Roman:Italic=17 T}_{crit} = 2730" \
    at graph 0.72, first 2900 left tc rgb "#555555" font 'Times New Roman,17'

plot DATAFILE skip 1 \
     using ($1/1000.0):2 with linespoints ls 1 title '{/Times-New-Roman:Italic V}_{raw}', \
  '' using ($1/1000.0):3 with linespoints ls 2 title '{/Times-New-Roman:Italic V}_{flt} (WVAF)'

# Cleanup panel (a)
unset arrow 1; unset arrow 2
unset label 1; unset label 2

# ==============================================================
# PANEL (b) — Window Size & Delta (dual Y-axis)
# ==============================================================
set rmargin 18
set title "{/:Bold=24 (b)}" textcolor rgb COL_TEXT offset -60,0
set format x ""
set yrange [0:20]
set ylabel "{/Times-New-Roman:Italic=22 N}_{win}" \
    font 'Times New Roman,22' textcolor rgb COL_WIN offset 0,0
set y2label "|{/Symbol D}{/Times-New-Roman:Italic V}| (counts)" \
    font 'Times New Roman,22' textcolor rgb COL_DELTA offset 0,0
set ytics ("2" 2, "4" 4, "8" 8, "12" 12, "16" 16) \
    nomirror textcolor rgb COL_WIN font 'Times New Roman,20'
set y2tics 200 nomirror textcolor rgb COL_DELTA font 'Times New Roman,20'
set y2range [0:1400]
set mytics 1
set border 11 linecolor rgb COL_BORDER linewidth 2.0
set key outside right top vertical font 'Times New Roman,18' \
    textcolor rgb COL_TEXT spacing 1.6 samplen 4 width -2 \
    box lc rgb "#aaaaaa" lw 1.0

# Delta threshold
set arrow 3 from graph 0, second 200 to graph 1, second 200 \
    nohead lc rgb "#888888" lw 1.5 dt (10,6)
set label 3 "{/Symbol D}_{th} = 200" \
    at graph 0.82, second 280 left tc rgb "#666666" font 'Times New Roman,17'

plot DATAFILE skip 1 \
     using ($1/1000.0):4 with steps    ls 3 lw 3.0 title '{/Times-New-Roman:Italic N}_{win}', \
  '' using ($1/1000.0):5 with impulses ls 4 lw 2.0 axes x1y2 title '|{/Symbol D}{/Times-New-Roman:Italic V}|'

# Cleanup panel (b)
unset y2label; unset y2range; unset y2tics
unset arrow 3; unset label 3
set border 3 linecolor rgb COL_BORDER linewidth 2.0
set rmargin 6
set ytics autofreq nomirror textcolor rgb COL_TEXT font 'Times New Roman,20'
set mytics 2

# ==============================================================
# PANEL (c) — System State
# ==============================================================
set title "{/:Bold=24 (c)}" textcolor rgb COL_TEXT offset -60,0
set format x ""
set ylabel "State {/Times-New-Roman:Italic=22 S}" \
    font 'Times New Roman,22' textcolor rgb COL_TEXT offset 0,0
set yrange [-0.5:2.8]
set ytics ("Normal" 0, "Warning" 1, "Danger" 2) \
    mirror textcolor rgb COL_TEXT font 'Times New Roman,20'
set mytics 1
set key outside right top vertical font 'Times New Roman,18' \
    textcolor rgb COL_TEXT spacing 1.6 samplen 4 width -2 \
    box lc rgb "#aaaaaa" lw 1.0

# Reference lines at state boundaries
set arrow 4 from graph 0, first 0.5 to graph 1, first 0.5 \
    nohead lc rgb "#cccccc" lw 1.0 dt (6,4)
set arrow 5 from graph 0, first 1.5 to graph 1, first 1.5 \
    nohead lc rgb "#cccccc" lw 1.0 dt (6,4)

plot DATAFILE skip 1 \
     using ($1/1000.0):6 with steps ls 5 lw 3.5 title 'Criticality Level {/Times-New-Roman:Italic S(t)}'

unset arrow 4; unset arrow 5
set ytics autofreq mirror textcolor rgb COL_TEXT font 'Times New Roman,20'

# ==============================================================
# PANEL (d) — Actuator Outputs
# ==============================================================
set bmargin 4.5
set title "{/:Bold=24 (d)}" textcolor rgb COL_TEXT offset -60,0
set xlabel "{/Times-New-Roman:Italic=23 t} (s)" \
    font 'Times New Roman,23' textcolor rgb COL_TEXT offset 0,-0.3
set ylabel "Output" font 'Times New Roman,22' textcolor rgb COL_TEXT offset 0,0
set format x "%.2f"
set yrange [-0.3:1.5]
set ytics ("Off" 0, "On" 1) mirror textcolor rgb COL_TEXT font 'Times New Roman,20'
set mxtics 5
set mytics 1
set key outside right top vertical font 'Times New Roman,18' \
    textcolor rgb COL_TEXT spacing 1.6 samplen 4 width -2 \
    box lc rgb "#aaaaaa" lw 1.0

# Reference line at y=1
set arrow 6 from graph 0, first 1.0 to graph 1, first 1.0 \
    nohead lc rgb "#e0e0e0" lw 0.8 dt (4,4)

plot DATAFILE skip 1 \
     using ($1/1000.0):12 with steps ls 8 lw 3.0 title 'LED_{Green}', \
  '' using ($1/1000.0):11 with steps ls 7 lw 3.0 title 'LED_{Red}', \
  '' using ($1/1000.0):10 with steps ls 6 lw 3.5 title 'Relay'

unset arrow 6

# ==============================================================
unset multiplot

print ""
print "=== IEEE-quality plot generated ==="
print "Resolution: 3600 x 2800 px (~300 DPI at 12x9.3 inch)"
print "Output: " . OUTFILE
