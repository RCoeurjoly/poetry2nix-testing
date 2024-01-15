set terminal png size 800,600
set output 'plot.png'
set title "Average Error Probability Across 100 Slots"
set xlabel "Slot (1% of Total Packages per Slot)"
set ylabel "Average Error Probability"
set grid
set style data linespoints

# Plotting the data
plot "/path/to/slot_error_probabilities.dat" using 1:2 title "Error Probability" with linespoints