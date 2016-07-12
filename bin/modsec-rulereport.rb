#!/usr/bin/ruby
#
# A ruby script which extracts ModSec alerts out of an apache
# error log and displays them in a terse report.
#
# Multiple options exist to tailor the report. When trying to
# tune a modsecurity installation, the script can propose
# rules or directives for the apache configuration, which can 
# be used to bypass the false positives reported by the script.
#
# Call with the option --help to get an usage overview.
#
# TODO / FIXME
# - Import Error-Log
# - ignore-rule modes:
#   - non-empty username
#   - method-based
#   - reduce anomaly score as ignore-rule
#   - stats mode (number and percentages of rule hits, paths, parameters)
# - order by number of hits per rule or rule id
# - option to have anomaly scoring checks be included in the rule
#     (hidden by default)

# -----------------------------------------------------------
# INIT
# -----------------------------------------------------------

require "optparse"
require "date"
require "pp"
require 'open-uri'
require "rubygems"

$params = Hash.new

$params[:verbose] = false
$params[:debug]   = false

RULEID_DEFAULT = 10000

MODE_SUPERSIMPLE=1
MODE_SIMPLE=2
MODE_PARAMETER=3
MODE_PATH=4
MODE_COMBINED=5
MODE_GRAPHVIZ=6
MODE_ALL=16

$params[:mode]   = MODE_SUPERSIMPLE

$params[:filenames] = Array.new
$params[:ruleid] = RULEID_DEFAULT

Severities = {
	"NOTICE" => 2,
	"WARNING" => 3,
	"ERROR" => 4,
	"CRITICAL" => 5
}

class Event
	attr_accessor :id, :unique_id, :ip, :msg, :uri, :severity, :parameter, :hostname, :file, :tags

	def initialize(id, unique_id, ip, msg, uri, severity, parameter, hostname, file, tags)
		@id = id
		@unique_id = unique_id
		@ip = ip
		@msg = msg
		@uri = uri
		@severity = severity
		@parameter = parameter
		@hostname = hostname
		@file = file
		@tags = tags
	end
end


# -----------------------------------------------------------
# SUB-FUNCTIONS (those that are specific to this script)
# -----------------------------------------------------------

def import_files(filenames)
  # Purpose: Import files
  # Input  : filename array
  # Output : none
  # Return : events array
  # Remarks: none

  events = Array.new()

  begin

    unless (check_stdin())

      filenames.each do |filename|

        File.open(filename, "r") do |file|

      	  vprint "Reading file #{filename} ..."
	  events.concat(read_file(file))

	end

      end

    else

      	vprint "Reading STDIN ..."
	events.concat(read_file(STDIN))

    end

  rescue Errno::ENOENT => detail
    puts_error("File could not be opened. This is fatal. Aborting.", detail)
    exit 1
  rescue => detail
    puts_error("Unknown error during file read. This is fatal. Aborting.", detail)
    exit 1
  end

  return events

end

def read_file(file)
  # Purpose: Read file
  # Input  : file handle
  # Output : none
  # Return : events array
  # Remarks: none

  events = Array.new()

  def scan_line (line, key, default)
    begin
      return line.scan(/\[#{key} \"([^"]*)\"/)[0][0]
    rescue
      return default
    end
  end

  while ! file.eof?
	line = file.readline
	if /ModSecurity: (Warning|Access denied.*). (?!Unconditional match in SecAction)/.match(line)

	  # standard parameters
          id = scan_line(line, "id", "0")
          unique_id = scan_line(line, "unique_id", "no-id-found")
          msg = scan_line(line, "msg", "none")
	  uri = scan_line(line, "uri", "/")
	  severity = scan_line(line, "severity", "NONE/UNKOWN")
	  hostname = scan_line(line, "hostname", "unknown")
	  eventfile = scan_line(line, "file", "none")

	  # custom parameters
	  begin
	    ip = line.scan(/\[client ([^\]]*)\]/)[0][0]
	  rescue
	    ip = "0.0.0.0"
	  end
	  begin
	    parameter = line.scan(/ (at|against) "?(.*?)"?( required)?\. \[file \"/)[0][1]
	  rescue
	    parameter = ""
	  end
	  # FIXME: read tags
	  tags = Array.new

	  events << Event.new(id, unique_id, ip, msg, uri, severity, parameter, hostname, eventfile, tags)

        end
  end

  return events
	
end

def display_ignore_rule_mode_parameter(id, event, events)
  # Purpose: display ignore rule based on parameter of event
  # Input  : rule id, event object, events array
  # Output : report via stdout
  # Return : none
  # Remarks: none

	parameters = Array.new
	events.select{|h| h.id == id }.each do |h|
		if parameters.grep(h.parameter).length == 0 
			parameters << h.parameter
		end
	end
	parameters.sort!{|x,y| x <=> y }

	if parameters.length == 0 or ( parameters.length == 1 and parameters[0] == "" )
		puts "      No parameter available to create ignore-rule proposal."
	else
		puts "      # ModSec Rule Exclusion: #{id} : #{event.msg} (severity: #{Severities[event.severity].to_s} #{event.severity})"


	
		parameters.each do |parameter|
			num = events.select{|h| h.id == id && h.parameter == parameter}.length
			if parameter != ""
				printf "      SecRuleUpdateTargetById %6d \"!%s\"\n", id, parameter
			end
		end
	end

end

def display_ignore_rule_mode_path(id, event, events)
  # Purpose: display ignore rule based on path of event
  # Input  : rule id, event object, events array
  # Output : report via stdout
  # Return : none
  # Remarks: none

	puts "      # ModSec Rule Exclusion: #{id} : #{event.msg} (severity: #{Severities[event.severity].to_s} #{event.severity})"
	puts "      SecRule REQUEST_FILENAME \"@beginsWith /foo\" \"phase:1,nolog,pass,id:#{$params[:ruleid]},ctl:ruleRemoveById=#{id}\""
	$params[:ruleid] = $params[:ruleid] + 1

	uris = Array.new
	events.select{|h| h.id == id }.each do |h|
		if uris.grep(h.uri).length == 0 
			uris << h.uri
		end
	end
	uris.sort!{|x,y| x <=> y }

	puts
	puts "      Individual paths:"
	uris.each do |uri|
		num = events.select{|h| h.id == id && h.uri == uri}.length

		hostnames = Array.new
		events.select{|h| h.id == id and h.uri == uri}.each do |h|
			if hostnames.grep(h.hostname).length == 0
				hostnames << h.hostname
			end
		end

		if hostnames.length > 1
			printf "  %6d %s\t(multiple services: %s)\n", num.to_s, uri, hostnames.join(" ")
		else
			printf "  %6d %s\t(service %s)\n", num.to_s, uri, hostnames[0]
		end
	end

end

def display_ignore_rule_mode_path_and_parameter(id, event, events)
  # Purpose: display ignore rule based on path and parameter of event
  # Input  : rule id, event object, events array
  # Output : report via stdout
  # Return : none
  # Remarks: none

	puts "      # ModSec Rule Exclusion: #{id} : #{event.msg} (severity: #{Severities[event.severity].to_s} #{event.severity})"
	items = Array.new
	dprint "Building list with paths and parameters for this rule / event id:"
	events.select{|e| e.id == id }.each do |e|
		if e.parameter != ""
			num = items.select{|couple| couple[:parameter] == e.parameter && couple[:uri] == e.uri}.length
			if num == 0
				# FIXME: calling this couple is really stupid, now that's a triple
				couple = Hash.new
				couple[:parameter] = e.parameter
				couple[:uri] = e.uri
				couple[:num] = 1
				dprint "  Creating new couple with parameter #{couple[:parameter]} and uri #{couple[:uri]}"
				items << couple
			else
				couple = items.select{|couple| couple[:parameter] == e.parameter && couple[:uri] == e.uri}[0]
				dprint "  Raising number of occurrence of couple with parameter #{couple[:parameter]} and uri #{couple[:uri]} to #{couple[:num] + 1}"
				couple[:num] = couple[:num] + 1
			end
		else
			dprint "  No argument found in event. Event can thus not be handled in this mode. Passing to next event."
		end
	end
	items.sort!{|x,y| x[:parameter] <=> y[:parameter] }
	if $params[:debug]
		puts "Items/couples to be used for ignore rule with id #{id}:"
		pp items
	end

	if items.length == 0 or ( items.length == 1 and items[0] == "" )
		puts "  No parameter available to create ignore-rule proposal. Please try and use different mode."
	else
		items.each do |couple|
				prefix = ""
				if $params[:verbose]
					prefix = couple[:num].to_s + " x"
				end
				printf "     %s SecRule REQUEST_FILENAME \"@beginsWith %s\" \"phase:2,nolog,pass,id:%d,ctl:ruleRemoveTargetById=%d;%s\"\n", prefix, couple[:uri], $params[:ruleid], id, couple[:parameter]
				$params[:ruleid] = $params[:ruleid] + 1

		end
	end
 
end



def display_report(events)
  # Purpose: display report
  # Input  : events array
  # Output : report via stdout
  # Return : none
  # Remarks: none

  ids = Array.new
  dprint "Building list of relevant ids:"
  events.each do |event|
		if ids.grep(event.id).length == 0 && 
			( event.id != "981176" && event.id != "981202" && event.id != "981203" && event.id != "981204" && event.id != "981205" ) # 981203/4/5 are the rules checking anomaly score in the end. Ignoring those
			dprint "  Adding event id #{event.id}"
			ids << event.id
		else
			# id is already part of id list
			dprint "  Ignoring event id #{event.id}"
		end
  end
  ids.sort!{|a,b| a <=> b }
  
  if $params[:mode] != MODE_SIMPLE and $params[:mode] != MODE_SUPERSIMPLE
	puts
  end

  ids.each do |id|
	event = events.find {|e| e.id == id }
	len = events.select{|e| e.id == id }.length
	case $params[:mode]
		when MODE_SIMPLE
			out = len.to_s + " x " + id.to_s + " " + event.msg + " (severity: " + Severities[event.severity].to_s + " " + event.severity + ") : " 
			n = 0
			events.select{|e| e.id == id }.each do |e|
				out = out + ", " unless n == 0 
				out = out + e.parameter
				n = n + 1
			end
		when MODE_SUPERSIMPLE
			out = len.to_s + " x " + id.to_s + " " + event.msg
		else
			out = len.to_s + " x " + id.to_s + " " + event.msg + " (severity: " + Severities[event.severity].to_s + " " + event.severity + ")"
	end
	print out + "\n"
	if $params[:mode] != MODE_SIMPLE and $params[:mode] != MODE_SUPERSIMPLE
		0.upto(out.length-1) do |i| print "-"; end; print "\n" # breakline
	end
	case $params[:mode]
		when MODE_PARAMETER
			display_ignore_rule_mode_parameter(id, event, events)
		when MODE_PATH
			display_ignore_rule_mode_path(id, event, events)
		when MODE_COMBINED
			display_ignore_rule_mode_path_and_parameter(id, event, events)
		when MODE_ALL
			display_ignore_rule_mode_parameter(id, event, events)
			puts
			display_ignore_rule_mode_path(id, event, events)
			puts
			display_ignore_rule_mode_path_and_parameter(id, event, events)
	end
	if $params[:mode] != MODE_SIMPLE and $params[:mode] != MODE_SUPERSIMPLE
		puts
	end
  end

end


			


def display_report_graphviz(events)
  # Purpose: display graphviz report
  # Input  : events array
  # Output : report via stdout
  # Return : none
  # Remarks: none

  # Prepare ids
  dprint "Building list of relevant ids:"
  ids = Array.new
  events.each do |event|
		if ids.grep(event.id).length == 0 && 
			( event.id != "981176" && event.id != "981202" && event.id != "981203" && event.id != "981204" && event.id != "981205" ) # 981203/4/5 are the rules checking anomaly score in the end. Ignoring those
			dprint "  Adding event id #{event.id}"
			ids << event.id
		else
			# id is already part of id list
			dprint "  Ignoring event id #{event.id}"
			# FIXME: Grow number
		end
  end
  ids.sort!{|a,b| a <=> b }
  
  
  # Prepare uris
  dprint "Building list of relevant uris:"
  uris = Array.new
  events.each do |event|
		if uris.grep(event.uri).length == 0
			dprint "  Adding event uri #{event.uri}"
			uris << event.uri
		else
			dprint "  Ignoring event uri #{event.uri}"
		end
  end
  uris.sort!{|a,b| a <=> b }


  
  # Prepare parameters
  dprint "Building list of relevant parameters:"
  parameters = Array.new
  events.each do |event|
		if parameters.grep(event.parameter).length == 0
			dprint "  Adding event parameter #{event.parameter}"
			parameters << event.parameter
		else
			dprint "  Ignoring event parameter #{event.parameter}"
		end
  end


  puts "// HEADER"
  puts "digraph G {"
  puts "  size = \"24,24\";"
  puts "  ranksep=\"8\";"
  puts

  puts "// DEFINING URI NODES"
  uris.each do |item|
  	puts "  \"#{item}\" [shape=house,fontname=helvetica];"
  end
  puts

  puts "// DEFINING PARAMETER NODES"
  parameters.each do |item|
  	puts "  \"#{item}\" [shape=invhouse,fontname=helvetica];"
  end
  puts

  puts "// DEFINING ID NODES"
  ids.each do |item|
  	puts "  \"#{item}\" [shape=box,fontname=helvetica];"
  end
  puts

  puts "// EDGES: URI -> PARAMETER"
  uris.each do |uri|
	event = events.find {|e| e.uri == uri }
   
  	items = Array.new

	dprint "Building list with parameters for this uri:"
	events.select{|e| e.uri == uri }.each do |e|
		if e.parameter != ""
			num = items.select{|couple| couple[:parameter] == e.parameter && couple[:uri] == e.uri}.length
			if num == 0
				couple = Hash.new
				couple[:parameter] = e.parameter
				couple[:uri] = e.uri
				couple[:num] = 1
				dprint "  Creating new couple with parameter #{couple[:parameter]} and uri #{couple[:uri]}"
				items << couple
			else
				couple = items.select{|couple| couple[:parameter] == e.parameter && couple[:uri] == e.uri}[0]
				dprint "  Raising number of occurrence of couple with parameter #{couple[:parameter]} and uri #{couple[:uri]} to #{couple[:num] + 1}"
				couple[:num] = couple[:num] + 1
			end
		else
			dprint "  No argument found in event. Event can thus not be handled in this mode. Passing to next event."
		end
	end
	items.sort!{|x,y| x[:parameter] <=> y[:parameter] }
	if $params[:debug]
		puts "Items/couples to be used in this group with uri #{uri}:"
		pp items
	end

	if items.length == 0 or ( items.length == 1 and items[0] == "" )
		puts "  No parameter available to display group."
	else
		items.each do |couple|
				penwidth = 1
				if couple[:num] >= 10
					penwidth = 4
				end
				if couple[:num] >= 100
					penwidth = 8
				end
				if couple[:num] >= 1000
					penwidth = 12
				end
				printf "  \"%s\"	-> \"%s\" [penwidth=#{penwidth},weight=#{penwidth}];\n", couple[:uri], couple[:parameter]

		end
	end
 
  end

  puts
  puts
  puts "// EDGES: PARAMETER -> ID"
  parameters.each do |parameter|
	event = events.find {|e| e.parameter == parameter }
   
  	items = Array.new

	dprint "Building list with ids for this parameter:"
	events.select{|e| e.parameter == parameter }.each do |e|
		if e.parameter != ""
			num = items.select{|couple| couple[:parameter] == e.parameter && couple[:id] == e.id}.length
			if num == 0
				couple = Hash.new
				couple[:parameter] = e.parameter
				couple[:id] = e.id
				couple[:num] = 1
				dprint "  Creating new couple with parameter #{couple[:parameter]} and id #{couple[:id]}"
				items << couple
			else
				couple = items.select{|couple| couple[:id] == e.id && couple[:parameter] == e.parameter}[0]
				dprint "  Raising number of occurrence of couple with parameter #{parameter} and id #{couple[:id]}"
				dprint "  Raising number of occurrence of couple with parameter #{parameter} and id #{couple[:id]} to #{couple[:num] + 1}"
				couple[:num] = couple[:num] + 1
			end
		else
			dprint "  No argument found in event. Event can thus not be handled in this mode. Passing to next event."
		end
	end
	items.sort!{|x,y| x[:parameter] <=> y[:parameter] }
	if $params[:debug]
		puts "Items/couples to be used in this group with uri #{uri}:"
		pp items
	end

	if items.length == 0 or ( items.length == 1 and items[0] == "" )
		puts "  No parameter available to display group."
	else
		items.each do |couple|
				penwidth = 1
				if couple[:num] >= 10
					penwidth = 4
				end
				if couple[:num] >= 100
					penwidth = 8
				end
				if couple[:num] >= 1000
					penwidth = 12
				end
				printf "  \"%s\"	-> \"%s\" [penwidth=#{penwidth},weight=#{penwidth}];\n", couple[:parameter], couple[:id]

		end
	end
 
  end


  if $params[:mode] == MODE_GRAPHVIZ
  	puts "}"
  end


end
	
# -----------------------------------------------------------
# GENERIC SUB-FUNCTIONS (those that come with every script)
# -----------------------------------------------------------
#
def dump_parameters(params)
  # Purpose: Display parameters
  # Input  : Parameter Hash
  # Output : Dump parameters to stdout
  # Return : none
  # Remarks: none
  
  puts "Paramter overview"
  puts "-----------------"
  puts "verbose    : #{params[:verbose]}"
  unless check_stdin()
  	puts "files      : #{params[:filenames].each do |x| x ; end}"
  else
  	puts "files      : [STDIN]"
  end
  puts "mode       : #{params[:mode]}" # FIXME: translate modes back to text strings

end

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

  unless $params[:ruleid] > 0
   $stderr.puts "Error in ruleid parameter (#{$params[:ruleid]}). Has to be an integer above 0. This is fatal. Aborting."
   err_status = true
  end
  
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
#

begin

parser = OptionParser.new do|opts|
  opts.banner = <<EOF
  Description of script ...
  A ruby script which extracts ModSec alerts out of an apache
  error log and displays them in a terse report.

  Multiple options exist to tailor the report. When trying to
  tune a modsecurity installation, the script can propose
  rules or directives for the apache configuration, which can 
  be used to bypass the false positives reported by the script.

  Usage: #{__FILE__} [options]
EOF

  opts.banner.gsub!(/^\t/, "")

        opts.separator ""
        opts.separator "Options:"

  opts.on('-d', '--debug', 'Display debugging infos') do |none|
    $params[:debug] = true;
  end

  opts.on('-v', '--verbose', 'Be verbose') do |none|
    $params[:verbose] = true;
  end

  opts.on('-m', '--mode MAN', 'Ignore-Rule suggestion mode:
                                     One of "simple", "supersimple", "parameter", "path",
                                     "combined" or "graphviz". Default is "supersimple"') do |mode|
	  case mode
	  when "simple"
    		$params[:mode] = MODE_SIMPLE;
	  when "supersimple"
    		$params[:mode] = MODE_SUPERSIMPLE;
	  when "parameter"
    		$params[:mode] = MODE_PARAMETER;
	  when "path"
    		$params[:mode] = MODE_PATH;
	  when "combined"
    		$params[:mode] = MODE_COMBINED;
	  when "graphviz"
    		$params[:mode] = MODE_GRAPHVIZ;
	  when "all"
    		$params[:mode] = MODE_ALL;
	  else
		$stderr.puts "Unknown mode \"#{mode}. This is fatal. Aborting."
		exit 1
	  end
  end
  
  opts.on('-r', '--ruleid MAN', "Start of ruleid namespace to be used. Default is #{RULEID_DEFAULT}.") do |ruleid|
    $params[:ruleid] = ruleid.to_i;
  end

  opts.on('-h', '--help', 'Displays Help') do
    puts opts
    exit
  end

  # Usage notes (to be printed in help text after cli options) 
  notes = <<EOF

  Notes:

  ...

EOF

  notes.gsub!(/^\t/, "")
  
  opts.on_tail(notes)
end

parser.parse!

ARGV.each do|f|  
  $params[:filenames] << f
end

# Mandatory Argument Check
# if $params[:man].nil?
#       $stderr.puts "FIXME argument missing in call. This is fatal. Aborting."
#       exit 1
# end

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

dump_parameters($params) if $params[:verbose]

vprint "Starting main program"

events = import_files($params[:filenames])

unless $params[:mode] == MODE_GRAPHVIZ
	display_report(events)
else
	display_report_graphviz(events)
end

vprint "Finishing main program. Bailing out."
