set terminal png size 800,600
set output 'plot.png'
set title "Download Count vs. Installation Error Probability"
set xlabel "Download Count"
set ylabel "Error Probability"
set logscale x  # Using logarithmic scale for better visibility if counts vary widely
set grid
set style data points

# Plotting the data
plot "plot_data.dat" using 2:3 title "Packages" pt 7 lc rgb "blue"
