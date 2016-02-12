#!/usr/bin/ruby
# 
# Copyright (c) 2015 netnea, AG. (https://www.netnea.com/)
#
# Perform the binning process on a list of values.
#
# Binning is a way to group a number of more or less continuous values into 
# a smaller number of "bins". For example, if you have data about a group of
# people, you might want to arrange their ages into a smaller number of age 
# intervals.
#   
#
# FIXME: implement decimalplaces (beginning is here, but not finished)
#
# bug: cat labor-07-example-access.log | alduration | do-binning.rb --label -n 25 --min 0 --max 2500000.0
#       final additional line should be removed
# 
   

# -----------------------------------------------------------
# INIT
# -----------------------------------------------------------

require "optparse"
require "getoptlong"
require 'pp'

$params = Hash.new

$params[:verbose]             = false
$params[:debug]               = false

$params[:num_bins]          = 20
$params[:num_bins_string]   = ""
$params[:min]                 = nil
$params[:max]                 = nil
$params[:max_str]             = ""
$params[:labels]              = false
$params[:do_boundaries]       = false	# run in boundaries mode. That means boundaries of bins are passed on command line
$params[:boundaries_str]      = ""
$params[:decimalplaces]       = 1       # number of decimal places after dot

values = Array.new()
bins = Array.new()
    # bin is an array with three sub-items:
    #   0: number of bin
    #   1: min of bin
    #   2: number of occurences of value (0 by default)

# -----------------------------------------------------------
# SUB-FUNCTIONS (those that are specific to this script)
# -----------------------------------------------------------

# -----------------------------------------------------------
# GENERIC SUB-FUNCTIONS (those that come with every script)
# -----------------------------------------------------------

def dump_parameters(params)
  # Purpose: Display parameters
  # Input  : Parameter Hash
  # Output : Dump parameters to stdout
  # Return : none
  # Remarks: none
  
  puts "Paramter overview"
  puts "-----------------"
  puts "verbose    : #{params[:verbose]}"

end

def vprint(text)
  # Purpose: output text if global variable $params[:verbose] is set.
  # Input  : String input
  # Output : stdout
  # Return : none
  # Remarks: none
  
  if $params[:verbose]
    puts text + "\n"
  end

end

def dprint(text)
  # Purpose: output text if global variable $params[:debug] is set.
  # Input  : String input
  # Output : stdout
  # Return : none
  # Remarks: none
  
  if $params[:debug]
    puts text + "\n"
  end

end

def check_stdin ()
  # Purpose: Check for access to STDIN
  # Input  : none
  # Output : none
  # Return : bool
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

  return err_status
  
end

def puts_error(msg, detail)
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

begin

  parser = OptionParser.new do|opts|
    opts.banner = <<EOF
    
Perform the binning process on a list of numerical values.

Binning is a way to group a number of more or less continuous values into 
a smaller number of "bins". For example, if you have data about a group of
people, you might want to arrange their ages into a smaller number of age 
intervals like 0-19,20-29,30-39,...

Usage: STDIN | #{__FILE__} [options]
EOF
  
    opts.banner.gsub!(/^\t/, "")
  
          opts.separator ""
          opts.separator "Options:"
  
    opts.on('-d', '--debug', 'Display debugging infos') do |none|
      $params[:debug] = true
    end

    opts.on('-D', '--decimalplaces MAN', "Number of decimal places after dot. Default is #{$params[:decimalplaces]}.") do |man|
      $params[:decimalplaces] = man.to_i
    end
  
    opts.on('-v', '--verbose', 'Be verbose') do |none|
      $params[:verbose] = true
    end
  
    opts.on('-b', '--boundaries MAN', 'Pass boundaries of bins on the command line, i.e. "5,10,15,20".') do |man|
      $params[:boundaries_str] = man
      $params[:do_boundaries] = true
    end
  
    opts.on('-m', '--min MAN', 'Minimum value. When working with boundaries, this option may not be passed.', 'The lowest boundary is automatically the min value.') do |man|
      $params[:min] = man.to_f
    end
  
    opts.on('-M', '--max MAN', 'Maximum value. When working with boundaries this option can be set.') do |man|
      $params[:max] = man.to_f
      $params[:max_str] = man
    end
  
    opts.on('-l', '--labels', 'Print bin sizes with labels. By default, this is off.') do |none|
      $params[:labels] = true
    end
  
    opts.on('-n', '--numbins MAN', 'Number of bins to be created.', 'You can not set this option if you also set boundaries option.', "Default is #{$params[:num_bins]}.") do |man|
      $params[:num_bins_string] = man
      $params[:num_bins] = man.to_i
    end
  
    opts.on('-h', '--help', 'Displays Help') do
      puts opts
      exit
    end
  
    # Usage notes (to be printed in help text after cli options) 
    notes = <<EOF
  
Notes:

You can either pass the number of bin you want to fill, or you pass the
boundaries of the bins yourself.  If you pass the number of bins with
numbins, then you can not pass boundaries. 

Boundaries need not be of equal size. It is ok to call with boundaries
value of 0-19,20-29,30-39, etc.  Boundaries can be integers or floating
point numbers. Negative values are OK too.

Boundaries define the bin. The first boundary is automatically the min
value that will be considered.  So passing a min value on the command line
is no accepted. The final boundary defines the min value of the final bin.
It is therefore acceptable to define a separate max value or to leave the
max value open and let the final bin stretch to infinity.
  
EOF

    notes.gsub!(/^\t/, "")
  
    opts.on_tail(notes)

  end

parser.parse!

#rescue OptionParser::InvalidOption => detail
#  puts_error("Invalid Option in command line parameter extraction. This is fatal. Aborting.", detail)
#  exit 1
#rescue => detail
#  puts_error("Unknown error in command line parameter extraction. This is fatal. Aborting.", detail)
#  exit 1
end

  
if $params[:do_boundaries] and $params[:num_bins_string] != ""
	$stderr.puts "Boundaries and numbins passed together. Please pick one of the two. Aborting."
	exit 1
end

if $params[:do_boundaries] and not $params[:min].nil?
	$stderr.puts "Boundaries and min value passed. Lowest boundary is mean to be min value. Please omitt min value. Aborting."
	exit 1
end

if /^[0-9,.-]*$/.match($params[:boundaries_str]).nil?
	$stderr.puts "Boundaries passed can not be read. This is fatal. Aborting."
	exit 1
end

if /^[0-9]$/.match($params[:decimalplaces].to_s).nil?
	$stderr.puts "Decimal places passed is not an integer number <= 9. This is fatal. Aborting."
	exit 1
end

unless check_stdin
	$stderr.puts "No STDIN found. Please pass STDIN to script."
	exit 1
end


# ----------------------------------
# MAIN
# ----------------------------------

STDIN.each do |line|
  values << line.chomp.to_f
end

if ( $params[:do_boundaries] )
  
  boundaries_str_array = $params[:boundaries_str].split(",")
  boundaries_array = Array.new
  boundaries_str_array.each do |item|
  	boundaries_array << item.to_f
  end

  if boundaries_array.length <= 1
	$stderr.puts "Boundaries passed can not be interpreted. Did you pass no real boundary or only a single one? Aborting."
	exit 1
  end

  boundaries_array.sort!

  0.upto(boundaries_array.length-1) do |i|
    bins[i] = [i, boundaries_array[i], 0]
  end

  # check boundaries and compatibility with min / max

  $params[:min] = boundaries_array[0]

  if ( not $params[:max].nil? )
  	if boundaries_array[boundaries_array.length-1] > $params[:max]
		$stderr.puts "Last boundary is higher than max. This is fatal. Aborting."
		exit 1
	end
  end
  	
  # How we perform the binning
  # - sort values
  # - start with first bin
  # - loop over values
  # -   if value fits into bin, add 1 to size of bin
  # -   if value does not fit into bin, move to next bin
  # - done

  values.sort!

  i = 0
  boundary_next = bins[i + 1][1]

  values.each do |item|

   if item < $params[:min]
   	next
   end

    unless $params[:max].nil?
      if item > $params[:max]
    	break
      end
    end

    infinity_bin = false
    while (item >= boundary_next and not infinity_bin)
        i = i + 1
	if i >= bins.length - 1		# reached top bin. can't calculate boundary_next
		infinity_bin = true
	else
		# puts "#{i} #{item} #{bins.length}"
		boundary_next = bins[i + 1][1]
	end
    end

    if i >= bins.length - 1 # it is a rare case, which leads to an error if this clause is commented out
    			      # echo -e "10\n173759\n10000000000000" | do-binning.rb -b 1000,50000,100000 --labels
    	i = bins.length - 1
    end

    bins[i][2] += 1 # raise number of occ. of this bin

  end

  $params[:num_bins] = bins.length

else

  boundaries_array = Array.new

  # initialize empty bins array
  $params[:min] = values.min if $params[:min].nil?
  $params[:max] = values.max if $params[:max].nil?
  step = ($params[:max] - $params[:min]) / $params[:num_bins]

  0.upto($params[:num_bins]) do |i|
	boundary = $params[:min] + i * step
	boundary = (boundary * 10 ** $params[:decimalplaces]).round / (10 ** $params[:decimalplaces]).to_f
  	boundaries_array << boundary
  end

  0.upto(boundaries_array.length-1) do |i|
    bins[i] = [i, boundaries_array[i], 0]
  end


  # check boundaries and compatibility with min / max
  $params[:min] = boundaries_array[0]

  if ( not $params[:max].nil? )
  	if boundaries_array[boundaries_array.length-1] > $params[:max]
		$stderr.puts "Last boundary is higher than max. This is fatal. Aborting."
		exit 1
	end
  end

  values.sort!

  i = 0
  boundary_next = bins[i + 1][1]

  values.each do |item|

   if item < $params[:min]
   	next
   end

    unless $params[:max].nil?
      if item > $params[:max]
    	break
      end
    end

    infinity_bin = false
    while (item >= boundary_next and not infinity_bin)
        i = i + 1
	if i >= bins.length - 1		# reached top bin. can't calculate boundary_next
		infinity_bin = true
	else
		# puts "#{i} #{item} #{bins.length}"
		boundary_next = bins[i + 1][1]
	end
    end

    if i >= bins.length - 1 # it is a rare case, which leads to an error if this clause is commented out
    			      # echo -e "10\n173759\n10000000000000" | do-binning.rb -b 1000,50000,100000 --labels
    	i = bins.length - 1
    end

    bins[i][2] += 1 # raise number of occ. of this bin

  end

  $params[:num_bins] = bins.length

end

# pp bins

0.upto($params[:num_bins] - 1) do |n|
	unless $params[:labels]
    		puts "#{bins[n][2]}"
	else
		if n == $params[:num_bins] - 1
			if $params[:max_str] == ""
				$params[:max_str] = "infinity"
			end
			puts "#{bins[n][1]}-#{$params[:max_str]}	#{bins[n][2]}"
		else
			puts "#{bins[n][1]}-#{bins[n+1][1]}	#{bins[n][2]}"
		end
	end
	n = n + 1
end

