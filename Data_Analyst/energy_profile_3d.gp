# =============================================================================
# Profil Konsumsi Daya DMCM-WVAF (STM32F401CD)
# 3D Surface Plot — Frekuensi Sampling vs Window Size vs Arus
# =============================================================================
# Data source: dmcm_data.csv (78 sampel UART Virtual Terminal Proteus)
#
# Cara pakai:
#   1. python energy_profile.py
#   2. gnuplot energy_profile_3d.gp
# =============================================================================

# --- Output Configuration ---
set terminal pngcairo size 1200,900 enhanced font 'Arial,12' background '#ffffff'
set output 'energy_profile_3d.png'

# --- Title ---
set title "Profil Konsumsi Daya DMCM-WVAF: Sampling Rate vs Window Size vs Arus Sistem" font 'Arial,14'

# --- Axis Labels ---
set xlabel "Frekuensi Sampling (Hz)" font 'Arial,12' offset 1,-2
set ylabel "Ukuran Window WVAF (N)" font 'Arial,12' offset -2,-1
set zlabel "" font 'Arial,12'

# --- Axis Ranges ---
set xrange [50:500]
set yrange [2:16]
set zrange [0:15]

# --- Tics ---
set xtics 50
set ytics 2
set ztics 2

# --- Grid ---
set grid xtics ytics ztics
set xyplane at 0

# --- View angle ---
set view 60, 225, 1, 1

# --- Colorbar (viridis palette) ---
set palette defined ( \
    0   '#440154', \
    0.1 '#482575', \
    0.2 '#414487', \
    0.3 '#355F8D', \
    0.4 '#2A788E', \
    0.5 '#21918C', \
    0.6 '#22A884', \
    0.7 '#44BF70', \
    0.8 '#7AD151', \
    0.9 '#BDDF26', \
    1.0 '#FDE725'  \
)

set cbrange [0:15]
set cbtics 2
set cblabel "Konsumsi Arus Rata-rata (mA)" font 'Arial,12' rotate by -90 offset 2,0

# --- Surface style ---
set pm3d depthorder border lc rgb '#bbbbbb' lw 0.15
set style data pm3d
unset hidden3d
unset key

# --- Plot ---
DATAFILE = 'energy_profile_data.dat'

splot DATAFILE using 1:2:3 with pm3d title ''

# --- Reset ---
set output

print ""
print "=== Plot selesai! ==="
print "Output: energy_profile_3d.png"
