#!/usr/bin/ruby
#
# Copyright (c) 2015 netnea, AG. (https://www.netnea.com/)
#
# A ruby script to analyse modsecurity core rules anomaly scores in 
# STDIN.
# The data is then extracted and summarized in a statistical table
# that gives an overview over the anomaly scores in the data.
#
# This script was written by Christian Folini. Feel free to use it
# and to adopt it to your needs.
#
# Run with --help to get an usage overview.
#

# -----------------------------------------------------------
# INIT
# -----------------------------------------------------------

require "optparse"
require "date"
require "pp"
require "rubygems"


$params = Hash.new

$params[:verbose] = false
$params[:debug]   = false
$params[:incoming] = true;
$params[:outgoing] = true;
$params[:headers] = true;
$params[:totals] = true;
$params[:empty] = true;
$params[:summary] = true;
$params[:baseline] = 0;		# Number of requests with scores 0/0 to be added to stats

# -----------------------------------------------------------
# SUB-FUNCTIONS (those that are specific to this script)
# -----------------------------------------------------------

def read_stdin()
  # Purpose: import data out of STDIN
  # Input  : none
  # Output : Array of inbound scores, array ouf outbound scores
  # Remarks: Empty values are mapped to nil, non-integer values are mapped to 0
  
  vprint "Starting to read STDIN"

  def map_data(data,nils,stats)
    if data == "-" or data == ""
       nils = nils + 1
    else
       stats << data.to_i
    end
    return nils, stats
  end

  stats_in = Array.new()
  stats_out = Array.new()
  nils_in = 0 
  nils_out = 0 
  
  n = 0
  formatcheck_ok = false

  STDIN.each do |line| # we checked for STDIN in check parameter phase
     n = n + 1
     dprint "Processing line ##{n}: #{line.chomp}"
     begin
       in_data, out_data = line.chomp.split(";")
       unless formatcheck_ok
         if in_data  != in_data.to_i.to_s
       	   puts_error("Input's first line indicates, input is not in CSV format as")
	   puts_error("explained by help text. This is fatal. Aborting.")
	   exit 1
         else
           formatcheck_ok = true
         end
       end
       nils_in, stats_in = map_data(in_data, nils_in, stats_in)
       nils_out, stats_out = map_data(out_data, nils_out, stats_out)
     rescue => detail
       puts_error("Could not read line ##{n}: \"#{line.chomp}\". Ignoring.")
     end

  end

  1.upto($params[:baseline]) do
	  stats_in << 0
	  stats_out << 0
  end

  vprint "Done reading STDIN (imported #{n} lines of data)"

  return nils_in, stats_in, nils_out, stats_out

end

def print_stats_wrapper(nils_in, stats_in, nils_out, stats_out)
  # Purpose: print statistics about anomaly score data
  # Input  : stats arrays, number of nil values
  # Output : statistics to STDOUT
  # Remarks: none
  
  vprint "Starting to calculate and print statistics"

  def avg(arr)
     return arr.inject(0.0){ |sum, el| sum + el } / arr.size
  end

  def median(arr)
     sorted = arr.sort
     len = sorted.length
     return (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
  end

  def sample_variance(arr)
    avg=avg(arr)
    sum=arr.inject(0){ |acc,i| acc + (i - avg)**2 }
    return(1/arr.length.to_f*sum)
  end
 
  def standard_deviation(arr)
    return Math.sqrt(sample_variance(arr))
  end

  def print_stats(verb, nils, stats)
     def round(f, n)
	     # The ruby "round" function before ruby 1.9 works differently, so we implement it ourselves
	     return (f * 10 ** n).to_i.to_f / 10 ** n
     end

     total = stats.length + nils
     max = stats.max {|a,b| a <=> b }
     
     freq = Hash.new
     0.upto(max) { |n| 
       freq[n] = stats.select{|x| x == n }.length
     }

     puts "#{verb.upcase}                     Num of req. | % of req. |  Sum of % | Missing %" if $params[:headers]
     printf("Number of %s req. (total) |%7i | %8.4f%% | %8.4f%% | %8.4f%%\n\n", verb, total, 100, 100, 0) if $params[:totals]
     sum_perc = 0.0

     if $params[:empty]
        perc = nils / total.to_f * 100
        sum_perc = sum_perc + perc
        printf("Empty or miss. #{verb} score   | %6d | %8.4f%% | %8.4f%% | %8.4f%%\n", nils, perc, sum_perc, 100 - sum_perc)
     end

     freq.sort_by{ |key, value| key }.each { |key, value|
        perc = value / total.to_f * 100
        sum_perc = sum_perc + perc
        printf("Reqs with #{verb} score of %3d | %6d | %8.4f%% | %8.4f%% | %8.4f%%\n", key, value, round(perc, 4), round(sum_perc, 4), 100 - round(sum_perc, 4))
     }

     printf("\n#{verb.capitalize} average: %8.4f    Median %8.4f    Standard deviation %8.4f\n", avg(stats), median(stats), standard_deviation(stats)) if $params[:summary]

     puts if ($params[:incoming] && $params[:outgoing] && verb == "incoming" && $params[:outgoing])
     puts if ($params[:incoming] && $params[:outgoing] && verb == "incoming" && $params[:outgoing] && ($params[:header] || $params[:summary]))

  end

  print_stats("incoming", nils_in, stats_in) if $params[:incoming]
  print_stats("outgoing", nils_out, stats_out) if $params[:outgoing]

  vprint "Done printing statistics"

end

# -----------------------------------------------------------
# GENERIC SUB-FUNCTIONS (those that come with every script)
# -----------------------------------------------------------

def vprint(text)
  # Purpose: output text if global variable $verbose is set.
  # Input  : String input
  # Output : stdout
  # Remarks: none

  if $params[:verbose]
    puts text + "\n"
  end

end

def dprint(text)
  # Purpose: output text if global variable $debug is set.
  # Input  : String input
  # Output : stdout
  # Remarks: none

  if $params[:debug]
    puts text + "\n"
  end

end

def check_stdin ()
  # Purpose: Check for access to STDIN
  # Input  : none
  # Output : bool
  # Remarks: none

  if STDIN.tty?
    # no stdin
    return false
  else
    # stdin
    return true
  end

end


def check_parameters()
  # Purpose: check parameters
  # Input  : global variable params
  # Output : stderr in case there is a problem with one of the parameters
  # Return : true if there is an error with one of the parameters; or false in absence of errors
  # Remarks: None

  err_status = false

  # unless /^foo$/.match($params["x"])
  #  $stderr.puts "Error in parameter x ..."
  #  err_status = true
  # end

  unless check_stdin()
     puts_error("No STDIN available. This is fatal. Aborting.", nil)
     exit 1
  end

  unless $params[:baseline].to_s.to_i == $params[:baseline]
     puts_error("Baseline parameter is not integer. This is fatal. Aborting.", nil)
     exit 1
  end

  return err_status

end

def puts_error(msg, detail=nil)
  # Purpose: Print error message
  # Input  : string msg and detail exception object
  # Output : $stderr
  # Return : None
  # Remarks: There is a ruby exception class hierarchy.
  #          See http://makandracards.com/makandra/4851-ruby-exception-class-hierarchy

  err_status = false
  $stderr.puts msg
  $stderr.puts "Error: #{detail.message}" if detail
  $stderr.puts "Backtrace:" if detail
  $stderr.puts detail.backtrace.join("\n") if detail
  $stderr.puts "--------------------------"

end


# -----------------------------------------------------------
# COMMAND LINE PARAMETER EXTRACTION
# -----------------------------------------------------------
#

begin

parser = OptionParser.new do|opts|
        opts.banner = <<EOF

A ruby script to analyse modsecurity anomaly scores in STDIN.
The data is extracted and summarized in a statistical table
that gives an overview over the anomaly scores in the data.

This script was written by Christian Folini and put into the
public domain. Feel free to use it and to adopt it to your needs.	

Usage: #{__FILE__} [options]
EOF

        opts.banner.gsub!(/^\t/, "")

        opts.separator ""
        opts.separator "Options:"

        opts.on('-d', '--debug', 'Display debugging infos') do |none|
                $params[:debug] = true;
        end
        opts.on('-b', '--baseline MAN', 'Indicate baseline of additional requests with score 0/0') do |baseline|
                $params[:baseline_str] = baseline;
        end
        opts.on('-v', '--verbose', 'Be verbose') do |none|
                $params[:verbose] = true;
        end
        opts.on('-i', '--incoming', 'Display only incoming statistics') do |none|
                $params[:outgoing] = false;
        end
        opts.on('-o', '--outgoing', 'Display only outgoing statistics') do |none|
                $params[:incoming] = false;
        end
        opts.on('-H', '--noheaders', 'Do not display column headers') do |none|
                $params[:headers] = false;
        end
        opts.on('-T', '--nototal', 'Do not display total number of requests') do |none|
                $params[:totals] = false;
        end
        opts.on('-E', '--noempty', 'Do not display number of empty values') do |none|
                $params[:empty] = false;
        end
        opts.on('-S', '--nosummary', 'Do not display stat. summary (avg, median, etc.)') do |none|
                $params[:summary] = false;
        end
        opts.on('-h', '--help', 'Displays Help') do
                puts opts
                exit
        end

        # Usage notes (to be printed in help text after cli options)
        notes = <<EOF

Notes:

Input is supposed to by in CSV format, 
one request with the two scores per line:

<incoming_anomaly_score>;<outgoing_anomaly_score>

I.e.:
0;0
1;0
0;0
0;2
12;3
0;0
2;0
0;1
2;5
...


ATTENTION: Missing anomaly scores are excluded from the calculation
of the average, the median and the standard deviation.

You get this stream of scores by defining the webserver's access log
accordingly and then extract the data out of that format.

Note that you can add an additional baseline of STR requests to the
statistics. This makes sense if your STDIN comes without the requests
which did not trigger any rules, but you want to include them in
the calculation.


Example:
LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\" \\
%v %A %p %R %{BALANCER_WORKER_ROUTE}e \ %X \"%{cookie}n\" \\
%{UNIQUE_ID}e %I %O %{ratio}n%% %D \\
%{TX.perf_modsecinbound}M %{TX.perf_application}M %{TX.perf_modsecoutbound}M \\
%{TX.INBOUND_ANOMALY_SCORE}M %{TX.OUTBOUND_ANOMALY_SCORE}M" extended

$> cat access.log  | egrep -o "[0-9]+ [0-9]+$" | tr " " ";"  | modsec-positive-stats.rb

INCOMING                     Num of req. | % of req. |  Sum of % | Missing %
Number of incoming req. (total) |  10000 | 100.0000% | 100.0000% |   0.0000%

Empty or miss. incoming score   |      0 |   0.0000% |   0.0000% | 100.0000%
Reqs with incoming score of   0 |   9970 |  99.7000% |  99.7000% |   0.3000%
Reqs with incoming score of   1 |      4 |   0.0400% |  99.7400% |   0.2600%
Reqs with incoming score of   2 |     21 |   0.2100% |  99.9500% |   0.0500%
Reqs with incoming score of   3 |      0 |   0.0000% |  99.9500% |   0.0500%
Reqs with incoming score of   4 |      4 |   0.0400% |  99.9900% |   0.0100%
Reqs with incoming score of   5 |      1 |   0.0100% | 100.0000% |   0.0000%

Incoming average:   0.0067    Median   0.0000    Standard deviation   0.1329


OUTGOING                     Num of req. | % of req. |  Sum of % | Missing %
Number of outgoing req. (total) |  10000 | 100.0000% | 100.0000% |   0.0000%

Empty or miss. outgoing score   |      0 |   0.0000% |   0.0000% | 100.0000%
Reqs with outgoing score of   0 |   9997 |  99.9700% |  99.9700% |   0.0300%
Reqs with outgoing score of   1 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with outgoing score of   2 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with outgoing score of   3 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with outgoing score of   4 |      2 |   0.0200% |  99.9900% |   0.0100%
Reqs with outgoing score of   5 |      1 |   0.0100% | 100.0000% |   0.0000%

Outgoing average:   0.0013    Median   0.0000    Standard deviation   0.0755


Note that you can add an additional baseline of STR requests to the
statistics. This makes sense if your STDIN comes without the requests
with a score of 0/0, but you want to include them in the calculation 
for the sake of a clean statistic.
Filtering out scores of 0/0 is very useful on big logfiles where script
takes a long time to run.

EOF

        opts.on_tail(notes)
end

parser.parse!

unless $params[:baseline_str].nil?
	if $params[:baseline_str].to_i.to_s != $params[:baseline_str]
       		$stderr.puts "Baseline parameter is not integer. This is fatal. Aborting."
	       exit 1
	else
		$params[:baseline] = $params[:baseline_str].to_i
	end
end

rescue OptionParser::InvalidOption => detail
  puts_error("Invalid Option in command line parameter extraction. This is fatal. Aborting.", detail)
  exit 1
rescue => detail
  puts_error("Unknown error in command line parameter extraction. This is fatal. Aborting.", detail)
  exit 1
end

# -----------------------------------------------------------
# MAIN
# -----------------------------------------------------------

vprint "Starting parameter checking"

exit 1 if (check_parameters)

vprint "Starting main program"

nils_in, stats_in, nils_out, stats_out = read_stdin()

print_stats_wrapper(nils_in, stats_in, nils_out, stats_out)

vprint "Done. Bailing out."



