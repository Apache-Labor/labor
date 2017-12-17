#!/usr/bin/awk -f
#
# awk script to calculate basic statistical info
#
# Pipe one numerical value per line into the script.
#
# $> ... STDIN | basicstats.awk
#
#Typical Output:
#
# Num of values:        10000
#          Mean:        91306
#        Median:         2431
#           Min:           18
#           Max:    301455050
#         Range:    301455032
# Std deviation:      3023884
#

BEGIN {
	sum = 0.0 
	sum2 = 0.0
	min = 10e10
	max = -min
}

(NF>0) {
        sum += $1
	sum2 += $1 * $1 
	N++;

        if ($1 > max) {
		max = $1
	}
        if ($1 < min) {
		min = $1
	}

        arr[NR]=$1
}

END{
    
    asort(arr)

    if (NR%2==1) {
        median = arr[(NR+1)/2]
    }
    else {
        median = (arr[NR/2]+arr[NR/2+1])/2
    }
    if(N>0) {
                printf "%14s %'18.2f\n", "Num of values:" ,N
                printf "%14s %'18.2f\n", "Mean:", sum/N
                printf "%14s %'18.2f\n", "Median:", median
                printf "%14s %'18.2f\n", "Min:", min
                printf "%14s %'18.2f\n", "Max:", max
                printf "%14s %'18.2f\n", "Range:", max-min
                printf "%14s %'18.2f\n", "Std deviation:", sqrt((sum2 - sum*sum/N)/N)
    }
    else {
                print "ERROR: No non-null values found"
    }
}
