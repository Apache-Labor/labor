#!/usr/bin/ruby
# == Synopsis
#
# Apache Logfile Scanning Script
# 
# Copyright 2007-2015 Christian Folini (folini@netnea.com)
#
# This software has been released under the GPL 3.0.
#
# parse-apache-log-extended.rb [OPTIONS] file(s)
# <STDIN> | parse-apache-log-extended.rb [OPTIONS]
#
# Call with --help to get an overview of options.
#

require "tempfile"
require "getoptlong"
require 'zlib'
require 'pp'
include Zlib

LOGFORMAT_EXTENDED2015 = "Remote-IP Country Remote-User [Timestamp] \"Method Path Version\" Status Response-Size \"Referer\" \"User-Agent\" ServerName Local-IP Local-Port RspHandler BalRoute ConnStatus \"Tracking-ID\" Request-ID SSLProtocol SSLCipher IO-In IO-Out Deflate-Ratio Duration ModSecPerfIn PerfAppl ModSecPerfOut ModSecScoreIn ModSecScoreOut"
LOGFORMAT_EXTENDED2014 = "Remote-IP Country Remote-User [Timestamp] \"Method Path Version\" Status Response-Size \"Referer\" \"User-Agent\" ServerName Local-IP Local-Port RspHandler BalRoute ConnStatus \"Tracking-ID\" Request-ID SSLProtocol Cipher IO-In IO-Out Deflate-Ratio Duration ModSecPerfIn PerfAppl ModSecPerfOut ModSecScoreIn ModSecScoreOut"
LOGFORMAT_EXTENDED2012 = "Remote-IP Remote-Logname Remote-User [Timestamp] \"Method Path Version\" Status Response-Size \"Referer\" \"User-Agent\" ServerName Local-IP Local-Port RspHandler BalRoute ConnStatus \"Tracking-ID\" Request-ID IO-In IO-Out Deflate-Ratio Duration ModSecPerfIn PerfAppl ModSecPerfOut ModSecScoreIn ModSecScoreOut"
LOGFORMAT_EXTENDED2011 = "Remote-IP Remote-Logname Remote-User [Timestamp] \"Method Path Version\" Status Response-Size \"Referer\" \"User-Agent\" ServerName Local-IP Local-Port RspHandler BalRoute ConnStatus \"Tracking-ID\" Request-ID IO-In IO-Out Deflate-Ratio Duration ModSecTime1 ModSecTime2 ModSecTime3 ModSecAnomaly"
LOGFORMAT_EXTENDED2007 = "Remote-IP Remote-Logname Remote-User [Timestamp] \"Method Path Version\" Status Response-Size \"Referer\" \"User-Agent\" ServerName Local-IP Local-Port \"Tracking-ID\" Request-ID IO-In IO-Out Deflate-Ratio Duration ModSecTime1 ModSecTime2 ModSecTime3"

LOGFORMAT_COMBINED = "Remote-IP Remote-Logname Remote-User [Timestamp] \"Method Path Version\" Status Response-Size \"Referer\" \"User-Agent\""

params = Hash.new
params["logfiles"] = nil     # space seperated list of logfiles

params["logformat"] = LOGFORMAT_EXTENDED2015
params["outformat"] = nil # format to display the data after processing
params["filterstring"] = nil    # format to display the data after processing

# ------------------------------------------
# Subfunctions
# ------------------------------------------

def vprint(text)
  # 
  # Output text if global variable $verbose is set.
  #
  
  if $verbose
    puts text + "\n"
  end
end

def usage ()

	puts <<EOF
#
Synopsis
--------

Apache Logfile Scanning Script

Copyright 2007-2012 Christian Folini (folini@netnea.com)

This software has been released under the GPL.

Usage
-----

scan-apache-log-extended.rb [OPTIONS] file(s)
<STDIN> | scan-apache-log-extended.rb [OPTIONS]


-h  --help             This text
-?  --usage            This text
-v  --verbose          Be verbose
-i  --informat         Specify the logfile format
                         Default is extended2012
-o  --outformat        Specify an output format. This is a
                         required parameter
-f  --filter           Filter for specific conditions


Usage examples
--------------

Take file access.log and print Status and Path for every request line:
 scan-apache-log-extended.rb --outformat "Status Path" access.log 

Find out which Browser (User-Agent) is being used by whom:
 scan-apache-log-extended.rb -o "Remote-User User-Agent" access.log | sort | uniq

Find out which IP address accessed the / of the server:
 scan-apache-log-extended.rb -o "Timestamp Remote-IP" --filter "Path == /" access.log

Select requests taking longer than 1s (1000000 microseconds) and HTTP Status 200 OK
 scan-apache-log-extended.rb -o "Path" -f "Duration > 1000000 and Status == 200" access.log

Select requests with an Anomaly Score of 5 or above
 scan-apache-log-extended.rb -o "Timestamp Remote-IP" -f "Anomaly-Score >= 5"

Filter options
--------------

The Filter knows the following conditions

a == b      for numbers and strings
a != b      for numbers and strings
a > b       for numbers
a >= b      for numbers
a < b       for numbers
a <= b      for numbers
a =~ b      regex evaluation for numbers and strings

Filters can be concatenated with "and".
"Or" is not supported.


EOF

  puts "Predefined Formats"
  puts "------------------"
  puts
  puts "extended / extended2015:"
  puts LOGFORMAT_EXTENDED2015
  puts
  puts "extended2014:"
  puts LOGFORMAT_EXTENDED2014
  puts
  puts "extended2012:"
  puts LOGFORMAT_EXTENDED2012
  puts
  puts "extended2007:"
  puts LOGFORMAT_EXTENDED2007
  puts
  puts "combined:"
  puts LOGFORMAT_COMBINED
  puts
  puts
  puts "combined:"
  puts LOGFORMAT_COMBINED
  puts
  puts
  puts "Construction of the output format"
  puts "---------------------------------"
  puts
  puts "You can use the abbrevated names as parameter"
  puts "for command line option --outformat.:"
  puts "All variable names in the informat can be used to construct a new "
  puts "outformat or a filter. A typical example for an outformat:"
  puts
  puts "scan-apache-log-extended.rb --informat extended2012 --outformat \"Timestamp Status\" ..."
  puts "..."
  puts "12/Nov/2007:21:50:49 +0100 200"
  puts "12/Nov/2007:21:51:28 +0100 200"
  puts "12/Nov/2007:21:51:39 +0100 200"
  puts "..."
  puts
  puts "However, you can also do conversions like:"
  puts "scan-apache-log-extended.rb --informat extended2012 --outformat combined ..."
  puts

  return

end

def check_stdin ()
  # check for existence of stdin
  if STDIN.tty?
    # no stdin
    return false
  else
    # stdin
    return true
  end
end

def check_parameters(params)
  # 
  # Check the validity of the command line parameters.
  # Bail out if an error occurs.
  #
  
  params["logfiles"].each do |file|
    unless FileTest::exists?(file)
      puts "Logfile parameter #{file} does not exist. This is fatal. Aborting."
      exit 1
    end
    unless FileTest::file?(file)
      puts "Logfile parameter #{file} is not a file. This is fatal. Aborting."
      exit 1
    end
  end

  unless ( params["logformat"].downcase == "combined" ||
  	   params["logformat"].downcase == "extended" ||
	   params["logformat"].downcase == "extended07" ||
	   params["logformat"].downcase == "extended11" ||
	   params["logformat"].downcase == "extended12" ||
	   params["logformat"].downcase == "extended14" ||
	   params["logformat"].downcase == "extended15" )
    error = parse_logformat(params["logformat"])[3]

    if error
      puts "Could not parse the logformat (see next line). This is fatal. Aborting."
      puts params["logformat"]
      exit 1
    end
  end

  if params["outformat"] == "" or params["outformat"].nil?
      params["outformat"] = params["informat"]
  end

end

def parse_filter(filterstring, informat_fields)
  # example: filterstring = "Response-Size < 500 AND Response-Size > 200"
  # returns an array with multiple hash-items.
  # filters will be connected via "AND".
  # "OR" is not supported.

  filters = []
  fieldname, operator, parameter = nil
  
  unless filterstring.nil?
    myfilterstring = filterstring.gsub(" and ", " AND ")  # capitalize AND
    myfilterstring = myfilterstring.gsub(" && ", " AND ")   # rewrite
    myfilterstring = myfilterstring.gsub(" or ", " OR ")  # capitalize OR (which is not supported. see below)

    
    if (myfilterstring.split(" OR ").length > 1 || myfilterstring.split(" || ").length > 1 )
      $stderr.puts "Filter contains \"OR\" resp. \"or\" resp \"||\". This is not supported. Aborting."
      exit 1
    end

    begin
      filterstringparts = myfilterstring.split("AND")

      filterstringparts.each do |item|
        fieldname, operator, parameter = item.split(" ")
        if fieldname.nil? or operator.nil? or parameter.nil?
          raise
        end
        if ["==", "!=", ">=", "<=", ">", "<", "=", "=~" ].index(operator).nil?
          $stderr.puts "Filter operator #{operator} is not known. This is fatal. Aborting."
          exit 1
        end
          
        # start adjust operators and parameters
        operator = "==" if operator == "="

        if ["==", "!="].index(operator)
          parameter = parameter[1..parameter.length] if parameter[0..0] == "\"" # remove beginning "
          parameter = parameter[0..parameter.length-2] if parameter[-1..-1] == "\"" # remove trailing "
        end

        if operator == "=~"
          parameter = parameter[1..parameter.length] if parameter[0..0] == "/" # remove beginning slash
          parameter = parameter[0..parameter.length-2] if parameter[-1..-1] == "/"  # remove trainling slash
        end

        # end start adjust operators and parameters
        
        filters << {"field" => informat_fields.index(fieldname), "operator" => operator , "parameter" => parameter}
      end
    rescue => detail
      $stderr.puts "Could not parse filter (current subitem is fieldname/operator/paramter: #{fieldname}/#{operator}/#{parameter}. This is fatal. Aborting."
      $stderr.puts detail
      exit 1
    end
  end
  return filters
end

def extract_next_param(ignoreflag, linenum, line, sep=" ", sep2="")

  item = ""
  
  if sep == " "                   # space separated
    n = line.index(sep)
    if n.nil? # no space separator found (= last item of line)
      n = line.length
      item = line
    else
      item = line[0,n]
    end
    line = line[n + 1, line.length]
    
  elsif (sep == "[" and sep2 == "]") or (sep == "\"" and sep2 == "\"")
    # different separator
    n = line.index(sep)
    begin
      line = line[n + 1, line.length]
      n = line.index(sep2)
      item = line[0,n]
      line = line[n + 2, line.length]
    rescue
      $stderr.puts "Error parsing line #{linenum}. Ignoring Line."
      ignoreflag = true
      item = ""
      line = ""
    end
  else
    $stderr.puts "Separators #{sep} and #{sep2} unknown. This is fatal. Aborting."
    exit 1
  end
  return ignoreflag, line, item
end
      
def parse_display_logfile(file, informat_fields, displayfields_prefixes, displayfields, displayfields_suffixes, filters, logformat)

  def process_handler(handler, informat_fields, displayfields_prefixes, displayfields, displayfields_suffixes, filters, logformat, filename=nil)
    linenum = 0
    
    unless filename.nil?
      if ( File.basename(filename, ".gz") != File.basename(filename) )
        handler = GzipReader.new(handler)
      end
    end

    case logformat
      when LOGFORMAT_COMBINED
        pattern = /^(\S+) (\S+) (\S+) \[([^\]]+)\] "(\S+) (.+?) (\S+)" (\S+) (\S+) "([^"]+)" "([^"]+)"$/ 
        numfields = 11
      when LOGFORMAT_EXTENDED2007
        pattern = /^(\S+) (\S+) (\S+) \[([^\]]+)\] "(\S+) (.+?) (\S+)" (\S+) (\S+) "([^"]+)" "([^"]+)" (\S+) (\S+) (\S+) "(\S+)" (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+)$/
        numfields = 23 
      when LOGFORMAT_EXTENDED2011
        pattern = /^(\S+) (\S+) (\S+) \[([^\]]+)\] "(\S+) (.+?) (\S+)" (\S+) (\S+) "([^"]+)" "([^"]+)" (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) "(\S+)" (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+)$/
        numfields = 27 
      when LOGFORMAT_EXTENDED2012
        pattern = /^(\S+) (\S+) (\S+) \[([^\]]+)\] "(\S+) (.+?) (\S+)" (\S+) (\S+) "([^"]+)" "([^"]+)" (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) "(\S+)" (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+)$/
        numfields = 28 
      when LOGFORMAT_EXTENDED2014
        pattern = /^(\S+) (\S\S?) (\S+) \[([^\]]+)\] "(\S+) (.+?) (\S+)" (\S+) (\S+) "([^"]+)" "([^"]+)" (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) "(\S+)" (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+)$/
        numfields = 30
      when LOGFORMAT_EXTENDED2015
        pattern = /^(\S+) (\S\S?) (\S+) \[([^\]]+)\] "(\S+) (.+?) (\S+)" (\S+) (\S+) "([^"]+)" "([^"]+)" (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) "([^"]+)" (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+)$/
        numfields = 30
      else
        raise
    end

    handler.each do |line|
      begin

        linenum += 1
        ignoreflag = false

        linearray = Array.new

        ret = pattern.match(line)
        if ret != nil
          linearray = ret[1,numfields]
        else
	  # line does not match our pattern
	  # one reason could be, that we did not receive a request line
	  # or a broken request line. We will now expand the
	  # placeholder "-" to get a request line which we
	  # can parse.
	  line.gsub!(/" 40([08]) ([0-9-])/, ' -" 40\1 \2')
          ret = pattern.match(line)
          if ret != nil
            linearray = ret[1,numfields]
          else
	    # did not work. Another expansion attempt.
	    line.gsub!(/" 40([08]) ([0-9-])/, ' -" 40\1 \2')
            ret = pattern.match(line)
            if ret != nil
              linearray = ret[1,numfields]
	    else
	      # no luck
	      raise
	    end
	  end
        end

        # --- start filter code

        display = true

        filters.each do |filter|
          value = linearray[filter["field"]]
          operator = filter["operator"]
          parameter = filter["parameter"]

          # puts "#{value} #{operator} #{parameter} #{display}"

          if not /^\d+([.,]\d+)?$/.match(parameter).nil? and ["==", "!=", ">=", "<=", ">", "<"].index(operator)
            # filtering for number
	    value = 0 if value == "-"
            if not eval "#{value} #{operator} #{parameter}"
              display = false
            end
          elsif operator == "=~"
            unless /#{parameter}/.match(value).to_a.length > 0
              display = false
            end
          elsif value.to_s == "-" and parameter.to_i > 0
              # filtering for number, but there is "-" in the logfile instead.
              display = false
          elsif value.to_s.length > 0 and ["==", "!="].index(operator)
            # filtering for string
            if not eval "\"#{value}\" #{operator} \"#{parameter.gsub("\"","")}\""
              display = false
            end
            #puts "#{value} #{operator} #{parameter} #{display}"
          else
            $stderr.puts "Can not cope with filter value/operator/parameter (#{value} #{operator} #{parameter}) on line #{linenum}. Not applying this filter to this line."
          end

        end

        # --- end filter code

        if display
          n = 0
          displine=""
          displayfields.each do |x|
             displine += "#{displayfields_prefixes[n]}#{linearray[x]}#{displayfields_suffixes[n]}"
             n += 1
          end
          print "#{displine}\n"
        end


      rescue => err
        $stderr.puts "Problems parsing line #{linenum}. Ignoring line. (Error #{err})"
	$stderr.puts line
      end

    end
    # --- end handle each line

  end
  # --- end process handler

  if check_stdin()
    process_handler(STDIN, informat_fields, displayfields_prefixes, displayfields, displayfields_suffixes, filters, logformat)
  else
    File.open(file) { |handler|
      process_handler(handler, informat_fields, displayfields_prefixes, displayfields, displayfields_suffixes, filters, logformat, file)
    }
  end

end


def read_logfiles(logfiles, logformat, informat_fields, displayfields_prefixes, displayfields, displayfields_suffixes, filters)

  lines = Array.new

  unless check_stdin()
    # logfiles as parameter
    logfiles.each do |logfile|
      parse_display_logfile(logfile, informat_fields, displayfields_prefixes, displayfields, displayfields_suffixes, filters, logformat)
    end
  else
    # logfile via stdin
    parse_display_logfile(STDIN, informat_fields, displayfields_prefixes, displayfields, displayfields_suffixes, filters, logformat)
  end
  
end


def parse_logformat(format)
  # Take a format string and extract the fieldnames and the separators
  # The only separators allowed are <space>, " and [ resp. ].

  error = false
  
  separators = Array.new
  itemnames = Array.new
  itemname = ""
  lookout = ""

  begin
    chars = format.scan(/./)
    chars.each { |char|
      if char == " "
        if itemname.length > 0
          separators << [" ", " "]
          itemnames << itemname
          itemname = ""
        end
      elsif char == lookout
        itemnames << itemname
        itemname = ""
        lookout = ""
      elsif char == "["
        separators << ["[", "]"]
        lookout = "]"
      elsif char == "\""
        separators << ["\"", "\""]
        lookout = "\""
      else
        itemname += char
      end
    }
    if itemname.length > 0 # cleanup
      separators << [" ", " "] # this will be the last item of the line
      itemnames << itemname
    end
    
    vprint "Logformat analysed. Found #{itemnames.length} items in format."

  rescue
    error = true
  end

  return itemnames, separators, error

end


def output_parse_logformat(format)

  fieldnum = 0
  lasthit = 0
  fieldnames_prefixes = []
  fieldnames = []
  fieldnames_suffixes = []

  curr_prefix = ""
  curr_field = ""
  curr_suffix = ""
  
  0.upto(format.length - 1) do |n|
    letter = format[n,1]
    hit = /[a-zA-Z0-9_-]/.match(letter).to_a.length

    if hit == 1
      if lasthit != hit
        fieldnames_prefixes << curr_prefix
        curr_prefix = ""
        fieldnames_suffixes << curr_suffix if fieldnames_prefixes.length > 1
        curr_suffix = ""
      end
      curr_field += letter
    else
      if lasthit != hit
        fieldnames << curr_field
        curr_field = ""
      end
      if fieldnames_prefixes.length == fieldnames_suffixes.length
        curr_prefix += letter
      else
        curr_suffix += letter
      end
    end
    lasthit = hit

     #puts "State run #{n}: P:#{curr_prefix} F:#{curr_field} S:#{curr_suffix} PL:#{fieldnames_prefixes.length} FL:#{fieldnames.length} SL:#{fieldnames_suffixes.length}"
  end
  fieldnames << curr_field if curr_field.length > 0 # this one might still be left
  fieldnames_suffixes << curr_suffix # this one is still left
    
  #puts "------------"
  #puts fieldnames_prefixes
  #puts "------------"
  #puts fieldnames
  #puts "------------"
  #puts fieldnames_suffixes
  #puts "------------"

  return fieldnames_prefixes, fieldnames, fieldnames_suffixes

end

def check_outputformat_fieldnames(outformat_fields, informat_fields)
  return (outformat_fields - informat_fields).length == 0   # length of difference set of the arrays
end

def prepare_outformat(informat, outformat)
  
  informat_fields, displayfields_prefixes, displayfields, displayfields_suffixes = []

  if outformat == "combined"
    outformat = LOGFORMAT_COMBINED
  elsif outformat == "extended2007"
    outformat = LOGFORMAT_EXTENDED2007
  elsif outformat == "extended2011"
    outformat = LOGFORMAT_EXTENDED2011
  elsif outformat == "extended2012"
    outformat = LOGFORMAT_EXTENDED2012
  elsif outformat == "extended2014"
    outformat = LOGFORMAT_EXTENDED2014
  elsif outformat == "extended2015"
    outformat = LOGFORMAT_EXTENDED2015
  elsif outformat == "extended"
    outformat = LOGFORMAT_EXTENDED2015
  elsif outformat.nil?
    vprint "No output parameter passed. Assuming extended-2015."
    outformat = LOGFORMAT_EXTENDED2015
  end


  if outformat
  
      informat_fields = output_parse_logformat(informat)[1] # get the logfile fieldnames

      displayfields_prefixes, displayfields, displayfields_suffixes = output_parse_logformat(outformat)

      unless check_outputformat_fieldnames(displayfields, informat_fields)
        $stderr.puts "Output format contains items not appearing in the input format (=input logfile). This is fatal. Aborting."
        exit 1
      end

      # now we transform the array displayfields (containing fieldnames) into 
      # index numbers of the fields of the logfile(s)
      
      0.upto(displayfields.length - 1) do |n|
        displayfields[n] = informat_fields.index(displayfields[n])
      end
  end

  return informat_fields, displayfields_prefixes, displayfields, displayfields_suffixes
  
end

def display_lines(lines, displayfields_prefixes, displayfields, displayfields_suffixes)
  unless displayfields.nil?
        # now doing the display

        linenum = 0
        lines.each do |line|
        linenum += 1
        displine = ""
        begin
          n = 0
          displayfields.each do |x|
            displine += "#{displayfields_prefixes[n]}#{line[x]}#{displayfields_suffixes[n]}"
            n += 1
          end
          print "#{displine}\n"
        rescue => err
          $stderr.puts "Problems parsing line #{linenum}. Ignoring line. (Error #{err})"
        end
      end

  end

end
# ----------------------------------
# Command line options and arguments
# ----------------------------------

opts = GetoptLong.new(
  [ '-h', '--help', '-?', '--usage',  GetoptLong::NO_ARGUMENT ],
  [ '-v', '--verbose',                GetoptLong::NO_ARGUMENT ],
  [ '-f', '--filter',                 GetoptLong::REQUIRED_ARGUMENT ],
  [ '-i', '--informat',               GetoptLong::REQUIRED_ARGUMENT ],
  [ '-o', '--outformat',              GetoptLong::REQUIRED_ARGUMENT ]
)



opts.each do |opt, arg|
  case opt
    when '-h'
      usage
      exit
    when '--help'
      RDoc::usage
    when '-v'
      $verbose = true
    when '--verbose'
      $verbose = true
    when '-i', '--informat'
      if arg == "combined"
        params["logformat"] = LOGFORMAT_COMBINED
      elsif arg == "extended2007"
        params["logformat"] = LOGFORMAT_EXTENDED2007
      elsif arg == "extended2011"
        params["logformat"] = LOGFORMAT_EXTENDED2011
      elsif arg == "extended2012"
        params["logformat"] = LOGFORMAT_EXTENDED2012
      elsif arg == "extended2014"
        params["logformat"] = LOGFORMAT_EXTENDED2014
      elsif arg == "extended2015"
        params["logformat"] = LOGFORMAT_EXTENDED2015
      elsif arg == "extended"
        params["logformat"] = LOGFORMAT_EXTENDED2015
      else
        params["logformat"] = arg
      end
    when '-f'
      params["filterstring"] = arg
    when '--filter'
      params["filterstring"] = arg
    when '-o'
      params["outformat"] = arg
    when '--outformat'
      params["outformat"] = arg
    when '-?'
      usage
      exit
    when '--usage'
      usage
      exit
  end
end

if ARGV.length < 1 and not check_stdin()
   puts "Missing logfiles argument and missing stdin as well (try --help). This is fatal. Aborting."
   exit 1
end

params["logfiles"] = ARGV
vprint "Logfiles set to #{params["logfiles"].join(" ")}."

# ----------------------------------
# MAIN
# ----------------------------------

check_parameters(params)

informat_fields, displayfields_prefixes, displayfields, displayfields_suffixes = prepare_outformat(params["logformat"], params["outformat"])

filters = parse_filter(params["filterstring"], informat_fields)

read_logfiles(params["logfiles"], params["logformat"], informat_fields, displayfields_prefixes, displayfields, displayfields_suffixes, filters)


