set boxwidth 0.5
set terminal png size 950,550 truecolor nocrop enhanced font VeraBd 12


set output 'incoming-anomaly-scores-distribution.png'

set logscale y 10

# draw axis on the left and below
set border 3

# label both axis, but hide tics from top and right border
set xtics axis nomirror
set ytics axis nomirror
set ytics scale 0

# Axis Labels
set xlabel 'Anomalie Werte der Requests'
set ylabel 'Anzahl der Anfragen pro Anomalie Wert (log. Skala)'


# bar will be filled
set style fill solid

plot "scores.dat" using 1:3:xtic(2) with boxes linecolor rgb '#00ff88' title ""
