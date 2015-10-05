#!/usr/bin/awk -f
#
# A script that takes a "uniq -c" output and reformats it adding percentages
#
#
# $> ... | uniq -c | sort -n | percent.awk
#
#                         Entry        Count Percent
#---------------------------------------------------
#                     MSIE-10.0            1   0.03%
#                      MSIE-9.0            1   0.03%
#                      MSIE-7.0           64   1.83%
#                      MSIE-8.0         3435  98.11%
#---------------------------------------------------
#                         Total         3501 100.00%
#

BEGIN{  printf "%30s        Count Percent\n", "Entry";
        print "---------------------------------------------------"
     }

{
        sum+=$1;
        i++;
        count[i]=$1;
        entry[i]=$2
}

END{
        for (j=1; j<=i; j++) {
                printf "%30s %12i %6.2f%%\n", entry[j], count[j], count[j] * 100 / sum
        }
        print "---------------------------------------------------"
        printf "                         Total %12i 100.00%%\n", sum
}

