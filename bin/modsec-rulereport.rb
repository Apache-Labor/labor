#!/usr/bin/ruby
# vim: set expandtab shiftwidth=2 softtabstop=2:
#
# Copyright (C) 2015-2021 Christian Folini <folini@netnea.com>
# See below for license information
#
# This is a script that extracts ModSec alerts out of an apache error log and
# displays them in a terse report.
#
# The script is meant to be used together with the ModSecurity / Core Rule Set
# tuning methodology described at netnea.com.
#
# Multiple options exist to tailor the report. When trying to
# tune a modsecurity installation, the script can propose
# rule exclusions or directives for the apache configuration, which 
# can be used to bypass the false positives reported by the script.
#
# Call with the option --help to get an usage overview.
#
# --------------------------------------------------------------------------------------
#
# LICENSE: GPL3
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3
# of the License only.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to 
# Free Software Foundation, 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# --------------------------------------------------------------------------------------
#
# TODO / FIXME
# - Import Error-Log from file
# - function tests
# - List tag mode
# - Handle rules where variables should be updated instead of exclusion rules 
# - Force flag to override the special handling of rules where a variable should be reconfigured
#   But do a standard rule exclusion instead
# - Make sure all alert message types are understood and parsed
#   This depends on the operator
#   List of operators:
#   - rx
#   - streq
#   - ...
# - default values for startup<->runtime, rule<->target, id<->tag<->msg
# - env values for startup<->runtime, rule<->target, id<->tag<->msg
# - Indicate PL with rule ids in comments
# - Option to limit width of rule output. Line break
# - change sort order of rules
# - new interface: new modes
#   - selector (->only with runtime)
#     - path (+ optional: number of pathsegments)
#     - method
#     - user-agent
#     - referer
#     - selectors should be stackable
# - Support for audit log
# - Support for raw error message
# - check all function descriptions (key items like input/output/return-value)
# - support for alerts of whitelisting rules (Match of ... required)
# - mockup tests of script
# - naked call to script does not generate any output
# - Expand metainfo support to multiple events input
# - Expand advisory support to multiple events
#
# --------------------------------------------------------------------------------------

# -----------------------------------------------------------
# INIT
# -----------------------------------------------------------

require "optparse"
require "date"
require "json"
require "pp"
require 'open-uri'
require "rubygems"

params = Hash.new

params[:verbose] = false
params[:debug]   = false

MODE_STARTTIME = 1
MODE_RUNTIME = 2

RTMODE_RULE = 1
RTMODE_TARGET = 2

TEXT = 1
MARKDOWN = 2

BY_ID = 1
BY_TAG = 2

OUTPUT_TEXT = 1
OUTPUT_JSON = 2

RULEID_DEFAULT = 10000

ADVISORY_RULES = ["911100", "920360", "920370", "920380", "920390", "920400", "920410", "920420", "920430", "920440", "920450", "920480", "949110", "949111", "959100", "980120", "980130", "980140"] # These are rules that should not be handled with a rule exclusion but with an advisory instead.

TRANSPOSE_RULES = ["920300", "921180", "930120", "931130", "932200"] # These are rules, where the parameter name has to be transposed to be used in a rule exclusion

params[:filenames] = Array.new
params[:output_format] = OUTPUT_TEXT
params[:ruleid_file] = "/home/dune73/.ruleid"
params[:metainformation] = false
params[:advisory_format] = TEXT

  #          Priority 1: user submitted base id
  #          Priority 2: stored value on disk
  #          Priority 3: RULEID_DEFAULT
  #          Subsequent calls will increment the rule id
  #          FIXME: not properly implemented yet
  

Severities = {
	"NOTICE" => 2,
	"WARNING" => 3,
	"ERROR" => 4,
	"CRITICAL" => 5
}

class Event
	attr_accessor :timestamp, :id, :unique_id, :ip, :msg, :data, :uri, :parameter, :orig_parameter, :hostname, :file, :line, :version, :tags, :advisory

	def initialize(timestamp, id, unique_id, ip, msg, data, uri, parameter, orig_parameter, hostname, file, line, version, tags, advisory)
		@timestamp = timestamp
		@id = id
		@unique_id = unique_id
		@ip = ip
		@msg = msg
		@data = data
		@uri = uri
		@parameter = parameter
		@orig_parameter = orig_parameter
		@hostname = hostname
		@file = file
		@line = line
		@version = version
		@tags = tags
                @advisory = advisory
	end

	def to_hash
		hash = {}
		instance_variables.each { |var| hash[var.to_s.delete('@')] = instance_variable_get(var) }
		hash
	end
        

end


# -----------------------------------------------------------
# SUB-FUNCTIONS (those that are specific to this script)
# -----------------------------------------------------------

def import_files(filenames, params)
  # Purpose: Import files
  # Input  : filename array
  # Output : none
  # Return : events array
  # Remarks: none

  events = Array.new()
  advisory = nil

  begin

    unless (check_stdin())

      filenames.each do |filename|

        File.open(filename, "r") do |file|

      	  vprint("Reading file #{filename} ...", params)

          events.concat(read_file(file, params))

	end

      end

    else

      	vprint("Reading STDIN ...", params)

        events.concat(read_file(STDIN, params))

    end

  rescue Errno::ENOENT => detail
    puts_error("File could not be opened. This is fatal. Aborting.", detail)
    exit 1
  rescue => detail
    puts_error("Unknown error during file read. This is fatal. Aborting.", detail)
    exit 1
  end

  if params[:verbose]
    puts("Events imported:")
    pp(events)
  end

  return events

end

def parse_event_from_string(str, params)
  # Purpose: Wrap read_file so that a string can be passed
  # Input  : string, params
  # Output : none
  # Return : events array
  # Remarks: none

  file = StringIO.new(str)

  events = read_file(file, params)

  file.close

  return events

end

def get_advisory_ruleid(id, data, params)
  # Purpose: Return an advisory
  # Input  : rule id (string)
  # Output : none
  # Return : advisory text
  # Remarks: none

  advisory = ""

  if id == "911100"

    advisory = <<EOF
There is an alert on rule `911100`. This rule has a special role in the rule set. It
examines the HTTP method of the incoming request against the allowed HTTP methods
configured in the variable tx.allowed_methods. Instead of writing a rule exclusion
it is better to adjust the value of `tx.allowed_methods`.

You can do so by enabling the rule `900200` in the `crs-setup.conf` file and setting the
value `tx.allowed_methods` accordingly.

The rule alert examined logged the following data: 

`#{data}`
EOF

  elsif id == "920360"

    advisory = <<EOF
There is an alert on rule `920360`. This rule limits the length of the argument names
via the variable `tx.arg_name_length`. Instead of writing a rule exclusion it is better to
raise the value of `tx.arg_name_length`.

You can do so by enabling the rule `900310` in the `crs-setup.conf` file and setting the
value `tx.arg_name_length` accordingly.

The rule alert examined logged the following data:

`#{data}`
EOF

  elsif id == "920370"

    advisory = <<EOF
There is an alert on rule `920370`. This rule limits the length of the argument values
via the variable `tx.arg_length`. Instead of writing a rule exclusion it is better to
raise the value of `tx.arg_length`.

You can do so by enabling the rule `900320` in the `crs-setup.conf` file and setting the
value `tx.arg_length` accordingly.

The rule alert examined logged the following data:

`#{data}`

EOF

  elsif id == "920380"

    advisory = <<EOF
There is an alert on rule `920380`. This rule limits the number of arguments
via the variable `tx.max_num_args`. Instead of writing a rule exclusion it is better to
raise the value of `tx.max_num_args`.

You can do so by enabling the rule `900300` in the `crs-setup.conf` file and setting the
value `tx.max_num_args` accordingly.

The rule alert examined logged the following data:

`#{data}`
EOF

  elsif id == "920390"

    advisory = <<EOF
There is an alert on rule `920390`. This rule limits the total size of all arguments
via the variable `tx.total_arg_length`. Instead of writing a rule exclusion it is better to
raise the value of `tx.total_arg_length`.

You can do so by enabling the rule `900330` in the `crs-setup.conf` file and setting the
value `tx.total_arg_length` accordingly.

The rule alert examined logged the following data:

`#{data}`
EOF

  elsif id == "920400"

    advisory = <<EOF
There is an alert on rule `920400`. This rule limits the individual size of a file upload
via the variable `tx.max_file_size`. Instead of writing a rule exclusion it is better to
raise the value of `tx.max_file_size`.

You can do so by enabling the rule `900340` in the `crs-setup.conf` file and setting the
value `tx.max_file_size` accordingly.

The rule alert examined logged the following data:

`#{data}`
EOF

  elsif id == "920410"

    advisory = <<EOF
There is an alert on rule `920410`. This rule limits the total or combined size of all 
uploaded files the variable `tx.combined_file_sizes`. Instead of writing a rule exclusion
 it is better to raise the value of `tx.combined_file_sizes`.

You can do so by enabling the rule `900350` in the `crs-setup.conf` file and setting the
value `tx.combined_file_sizes` accordingly.

The rule alert examined logged the following data:

`#{data}`
EOF

  elsif id == "920420"

    advisory = <<EOF
There is an alert on rule `920420`. This rule checks the HTTP request content type 
against the predefined list of allowed content type in the variable 
`tx.allowed_request_content_type`. Instead of writing a rule exclusion it is better 
to reconfigure the value of `tx.allowed_request_content_type`.

You can do so by enabling the rule `900220` in the `crs-setup.conf` file and setting the
value `tx.allowed_request_content_type` accordingly.

The rule alert examined logged the following data:

`#{data}`
EOF

  elsif id == "920430"

    advisory = <<EOF
There is an alert on rule `920430`. This rule checks the HTTP version of the request
against the predefined list of allowed HTTP versions in the variable 
`tx.allowed_http_versions`. Instead of writing a rule exclusion it is better 
to reconfigure the value of `tx.allowed_http_versions`.

You can do so by enabling the rule `900230` in the `crs-setup.conf` file and setting the
value `tx.allowed_http_versions` accordingly.

The rule alert examined logged the following data:

`#{data}`
EOF

  elsif id == "920440"

    advisory = <<EOF
There is an alert on rule `920440`. If there is a file extension present in the filename
of the HTTP request URI, then this rule checks thus extension against a list of
prohibited / restricted file extensions in the variable `tx.restricted_extensions`.
Instead of writing a rule exclusion it is better to reconfigure the value of 
`tx.restricted_extensions`.

You can do so by enabling the rule `900240` in the `crs-setup.conf` file and setting the
value `tx.restricted_extensions` accordingly.

The rule alert examined logged the following data:

`#{data}`
EOF

  elsif id == "920450"

    advisory = <<EOF
There is an alert on rule `920450`. This rule checks the HTTP request headers 
against the predefined list of prohibited or restricted HTTP headers in the
variable `tx.restricted_headers`. Instead of writing a rule exclusion it is better 
to reconfigure the value of `tx.restricted_headers`.

You can do so by enabling the rule `900250` in the `crs-setup.conf` file and setting the
value `tx.restricted_headers` accordingly.

The rule alert examined logged the following data:

`#{data}`
EOF

  elsif id == "920480"

    advisory = <<EOF
There is an alert on rule `920480`. If there is a charset defined in the HTTP request
header `Content-Type`, then this charset is checked against a list of allowed charsets
in the variable `tx.allowed_request_content_type_charset`.
Instead of writing a rule exclusion it is better to reconfigure the value of 
`tx.allowed_request_content_type_charset`.

You can do so by enabling the rule `900240` in the `crs-setup.conf` file and setting the
value `tx.allowed_request_content_type_charset` accordingly.

The rule alert examined logged the following data:

`#{data}`
EOF

  elsif id == "949110"

    advisory = <<EOF
There is an alert on rule `949110`. This rule has a special role in the rule set. It
examines the anomaly score of the incoming request. If the anomaly score is
equal or higher than the anomaly threshold, then the rule blocks the request.

You should therefore not disable this rule. Instead you should work on different
rules so you can avoid false positives and make sure the anomaly score is low.
EOF

  elsif id == "949111"

    advisory = <<EOF
There is an alert on rule `949111`. This rule has a special role in the rule set. It
examines the anomaly score of the incoming request at the end of ModSecurity phase 1.
If the anomaly score is equal or higher than the anomaly threshold, then the rule 
blocks the request immediately.

You should therefore not disable this rule. Instead you should work on different
rules so you can avoid false positives and make sure the anomaly score is low.

Please note that the standard rule to block incoming requests is `949110`, which works
in phase 2. The rule `949111` is an optional variant of this rule that happens at
the end of phase 1. This is called blocking-early and is disabled by default. If you
see this rule being active, then it has been enabled for this service.
EOF

  elsif id == "959100"

    advisory = <<EOF
There is an alert on rule `959100`. This rule has a special role in the rule set. It
examines the outbound anomaly score of the response. If the anomaly score is
equal or higher than the anomaly threshold, then the rule blocks the response and
consequently the request.

You should therefore not disable this rule. Instead you should work on different
rules so you can avoid false positives and make sure the outbound anomaly score 
is low.
EOF

  elsif id == "980120"

    advisory = <<EOF
There is an alert on rule `980120`. This rule has a special role in the rule set. It
reports the anomaly scores of the incoming request together with separate scores
for individual attack classes.

This is purely informational. This rule does not contribute to the anomaly scoring
and it will never block.

You should therefore not disable this rule. Instead you should work on different
rules so you can avoid false positives and make sure the anomaly score is low.
EOF

  elsif id == "980130"

    advisory = <<EOF
There is an alert on rule `980130`. This rule has a special role in the rule set. It
reports the anomaly scores of the incoming request together with separate scores
for individual attack classes.

This is purely informational. This rule does not contribute to the anomaly scoring
and it will never block.

You should therefore not disable this rule. Instead you should work on different
rules so you can avoid false positives and make sure the anomaly score is low.
EOF

  elsif id == "980140"

    advisory = <<EOF
There is an alert on rule `980140`. This rule has a special role in the rule set. It
reports the anomaly scores of the outgoing responses together with an individual
listing of scores per paranoia lecel.

This is purely informational. This rule does not contribute to the anomaly scoring
and it will never block.

You should therefore not disable this rule. Instead you should work on different
rules so you can avoid false positives and make sure the anomaly score is low.
EOF


  elsif id == "PCRE"

    advisory = <<EOF
The input you submitted contains a PCRE error of the following form:

`ModSecurity: Rule ... Execution error - PCRE limits exceeded (-8): (null).`

This indicates that the PCRE match limits are too low for your rules or
payload. In fact, the default PCRE match limits are quite low.

If you are running on the ModSecurity 2 release line, you can raise the
PCRE match limits via the following directives:

```
SecPcreMatchLimit             <value>
SecPcreMatchLimitRecursion    <value>
```

The default value recommended by ModSecurity is 1500. This is a very low value
that can lead to a lot of errors as the one shown above. It's usually okay to
raise this to 10,000 or 100,000 or even 500,000. But the higher you go, the
higher the chance to be hit by a Regular Expression Denial of Service attack
(ReDoS).

The ModSecurity handbook has a section dedicated to this problem. You may
want to look it up there.

If you are running on the ModSecurity 3 release line (libModSecurity 3), then
your options are more limited. This is because ModSecurity does not expose the
PCRE match limits via configuration directives. You will have to recompile your
webserver and ModSecurity with higher limits - or exclude the rule in question
for the parameter(s) affected. However, C-Rex can not support you with this.
EOF

  elsif id == "AUDITLOG"

    advisory = <<EOF
The input you submitted contains a error pointing out that the audit log for 
the request could not be written:

`ModSecurity: Audit log: Failed to create subdirectories: /.../ (Permission denied)`

This indicates that there is a problem with the permissions of the audit log folder.

The audit log folder is defined with the following directive:

`SecAuditLogStorageDir <storage-folder>`

The folder needs to be existing and writeable by the webserver user. You need to fix
this in order to get audit logs written. C-Rex can not support you with this.
EOF

  elsif id == "AUDITLOGLibModSecurity3"

    advisory = <<EOF
The input you submitted contains a error pointing out that the audit log for 
the request could not be opened:

`"modsecurity_rules_file" directive Failed to open file ...`

This indicates that there is a problem with the permissions of the audit log folder
or the file itself.

The audit log file is defined with the following directive:

`SecAuditLog <path-to-file>`

The path needs to be existing and writeable by the webserver user. You need to fix
this in order to get audit logs written. C-Rex can not support you with this.
EOF



  else 

    $stderr.puts "Rule id #{id} is unknown. We should not be here. Can not generate advisory text. This is fatal. Aborting."
    exit 1

  end

  if (params[:advisory_format] == MARKDOWN)

    str = "### Advisory\n\n" 
    str += "**This is not a rule exclusion. Do not paste this into your configuration.**\n\n"
    advisory = str + advisory
    advisory += "\n"

  else

    str = "ADVISORY\n--------\n\n" 
    str += "***This is not a rule exclusion. Do not paste this into your configuration.***\n\n"
    advisory = str + advisory
    advisory += "\n"

    advisory = advisory.gsub("`", "").gsub("\n\n\n", "\n\n")

  end

  return advisory

end

def transpose_parameter(id, parameter, data, params) 
  # Purpose: transpose a parameter name
  # Input  : rule id (str), parameter name (str), data (str), script params hash
  # Output : debug output
  # Return : transposed parameter (str)
  # Remarks: none
  # Tests:   none

  dprint("Original parameter name: #{parameter}, id: #{id}", params)

  if id == "920300"

    parameter = parameter.gsub(/^REQUEST_HEADERS:User-Agent/, "REQUEST_HEADERS:Accept")

  elsif id == "921180"
    # 921180 works on a TX parameter that is created in 921170.
    # There is a case to be made a true rule exclusion should therefore work
    # on 921170. However, given the alert happens on 921180, that would complicate 
    # the code quite a bit and it might also puzzle the users.
    #
    # Therefore we actually leave the parameter as is. Yet we keep
    # 921180 here since it looks as if it would be a rule that is in
    # need of a transposition, then we can simply take the TX parameter
    # and build the rule id based on that.

  elsif id == "930120"
    # The architecture of the rule forces us to look at logdata
    # for the parameter
    # Interestingly, there are multiple versions of this rule around
    # * variant 1: Has TX as parameter, needs to be transposed to var in logdata
    # * variant 2: Everything OK

    if /^TX/ =~ parameter
      parameter = data.gsub(/^.* ARGS/, "ARGS").gsub(/: .*/, "")
    end

  elsif id == "931130"

    parameter = parameter.gsub(/^TX:rfi_parameter_/, "")

  elsif id == "932200"
    # 932200 in CRS up to 3.3.x does not bring any information about the original
    # parameter in the alert message. There is nothing we can do in that context.
    # However, in CRS v4, the rule works with a temporary variable and reports
    # the original parameter.
    # See https://github.com/coreruleset/coreruleset/pull/3409
    #
    # The transposition rule tries to extract the right parameter name.
    # If that sticks to MATCHED_VAR if that does not work.

    var = data.gsub(/^.*within /, "").gsub(/: .*/, "")
    if (var.length > 0 and var != parameter)
      parameter = var
    end

  else

    puts_error("Transpose parameter called for a rule id that the script does not know how to transpose.", detail)
    exit 1

  end

  dprint("Transposed parameter name: #{parameter}", params)

  return parameter
  
end

def read_file(file, params)
  # Purpose: Read file
  # Input  : file handle
  # Output : none
  # Return : advisory text, events array
  # Remarks: none

  events = Array.new()

  def scan_line (line, key, default, params)
    begin
      return line.scan(/\[#{key} \"([^"]*)\"/)[0][0]
    rescue
      return default
    end
  end

  def scan_line_tags (line, params)
    tags = Array.new
    begin
      dprint("Starting to parse tags.", params)
      line.split("[tag ").drop(1).each do |item|
		if not /\[/.match(item)
			item.gsub!(/\].*/, "").gsub!(/"/, "")
			dprint("  Identified tag #{item}", params)
			tags << item
                else
                	# last tag in the list needs special treatment, we need to make sure we don't get any garbled/cut short tags
                        # first we split of the remainder of the line
                        # then we run a series of gsubs, that cuts away broken tags
                        # We attempt to save a tag when we have the closing quotes. If we lack those, we abandon it. So we never take a tag that
                        # is cut short, but the closing bracket is optional for the final tag
			item = item.split("[hostname ")[0]
                        item = item.gsub(/\ $/, "").gsub(/ta$/, "").gsub(/\]$/, "").gsub(/\[$/, "").gsub(/\ $/, "").gsub(/\]$/, "")
                        if item.length > 2 and item[-1] == "\""
                          # This is the check for the terminating quotes
			  item.gsub!(/"/, "")
			  dprint("  Identified tag #{item}", params)
			  tags << item
                        end
		end
	end
      return tags
    rescue => detail
      puts_error("Problem parsing tags on input line: #{line}", detail)
      return tags
    end
  end

  def scan_ip (line, params)
    # Read custom parameters: ip
    begin
      ip = "0.0.0.0"
      if line.scan(/\[client ([^\]]*)\]/).length > 0
        tuple = line.scan(/\[client ([^\]]*)\]/)[0]
        if tuple[0]
          ip = tuple[0]
        end
      elsif line.scan(/ client: ([^,]*),/).length > 0
        tuple = line.scan(/ client: ([^,]*),/)[0]
        if tuple[0]
          ip = tuple[0]
        end
      else
        dprint("Could not read IP address, using fallback value.", params)
      end
    rescue
      dprint("Failed reading IP address, using fallback value.", params)
      ip = "0.0.0.0"
    end

    return ip

  end

  def scan_timestamp (line, params)
    # Read custom parameters: timestamp
    begin
      # The time stamp format proposed in the netnea tutorials is privileged. If it
      # this does not work, we use the date library and if that fails too, we
      # fall back to the epoch.
      item = line.scan(/(2[0-9]{3}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}.[0-9]{6})/)
      if item.length > 0
        timestamp = item[0][0]
      else
        # DateTime.parse has a size limit of 128 bytes, we assume the date is likely to be in the first 128 bytes
        timestamp = DateTime.parse(line[0,128]).strftime("%Y-%m-%d %H:%M:%S")
      end
    rescue
      dprint("Could not read timestamp address, using fallback value.", params)
      timestamp = "1970-01-01 00:00:00.000000"
    end

    return timestamp

  end

  def determine_parameter (id, orig_parameter, data, params)

    if  TRANSPOSE_RULES.grep(id).count == 1
      # If the rule is on the list of transpose rules, then
      # we have to transpose the parameter name in a certain 
      # way depending on the rule in question. The transposed
      # parameter will replace the parameter and the original
      # parameter will be stored as original_parameter.

      dprint("Alerts points to rule where parameter has to be transposed. Executing transposition.", params)
      parameter = transpose_parameter(id, orig_parameter, data, params)

    else

      parameter = orig_parameter

    end

    return parameter

  end

  def parse_parameter (line)
    begin

      if /(ModSecurity:|\]\[\d\]) (Warning.|Access denied with)/.match(line) or 
         /^Message: (Warning. Matched|Access denied with)/.match(line) or
         /^Matched \"Operator/.match(line)

            if /(Pattern match|Matched phrase)/.match(line)
                      # Operators: pm, pmFromFile, strmatch, rx
                      # example: standard operator results in:  ModSecurity: Warning. Pattern match "^[\\\\d.:]+$" at REQUEST_HEADERS:Host.
                      orig_parameter = line.scan(/ (at|against) "?(.*?)"?( required)?\.? \[file \"/)[0][1]
  
            elsif /detected (SQLi|XSS) using libinjection/.match(line)
                      # Operators: detectSQLi, detectXSS
                      # example: ModSecurity: Warning. detected SQLi using libinjection with fingerprint 's&1' [file ...  [data "Matched Data:  found within ARGS:sqli: ' or 1=1"] 
                      # The detectSQLi / detectXSS operator do not report the affected parameter by itself. Instead we need to fetch the parameter out of the logdata field. 
                      # This only works when the logdata format is consistent.
                      # Right now, we use the format defined in CRS3 rule 942100.
                      orig_parameter = line.scan(/\[data "Matched Data:.*found within ([^ ]*): /)[0][0]
  
            elsif /String match/.match(line)
                      # Operators: beginsWith, contains, containsWord, endsWith, streq, within
                      # example: ModSecurity: Warning. String match "/" at REQUEST_URI. [file ...] 
                      # example: ModSecurity: Warning. String match within "GET POST" at REQUEST_METHOD. [file ...]
                      orig_parameter = line.scan(/String match (within )?".*" at (.*?)\.? \[file /)[0][1]
  
            elsif /Operator [A-Z][A-Z] matched/.match(line)
                      # Operators: eq, ge, gt, le, lt
                      # example: ModSecurity: Warning. Operator EQ matched 1 at ARGS. [file ...]
                      orig_parameter = line.scan(/Operator [A-Z][A-Z] matched .* at ([^ ]*)\.? \[file /)[0][0].gsub(/\.$/, "")
  
            elsif /IPmatch(FromFile)?: ".*" matched at/.match(line)
                      # Operators: ipMatch, ipMatchFromFile
                      # example: ModSecurity: Warning. IPmatch: "127.0.0.1" matched at REMOTE_ADDR.
                      orig_parameter = line.scan(/IPmatch(FromFile)?: "[^"]*" matched at ([^ ]*)\.? \[file /)[0][1].gsub(/\.$/, "")
  
            elsif /Unconditional match in SecAction/.match(line)
                      # Operators: unconditionalMatch
                      # example: ModSecurity: Warning. Unconditional match in SecAction. [file ...]
                      # The unconditionalMatch operator does not report the parameter that was involved in the rule
                      # One would need to get it out of the logdata entry of the alert, but there is no
                      # standard way of configuring that, so there is no convention to base ourselves upon.
                      # Given the use of @unconditionalMatch is very rare,
                      # we set the parameter to "UNKNOWN"
                      orig_parameter = "UNKNOWN"
  
            elsif /Found \d+ byte\(s\) in .* outside range:/.match(line)
                      # Operators: validateByteRange
                      # example: ModSecurity: Warning. Found 9 byte(s) in REMOTE_ADDR outside range: 0. [file ... ]
                      orig_parameter = line.scan(/Found \d+ byte\(s\) in ([^ ]*) outside range: /)[0][0]
                      
            elsif /Invalid UTF-8 encoding/.match(line)
                      # Operators: validateByteRange
                      # example: ModSecurity: Warning. Invalid UTF-8 encoding: overlong character detected at ARGS:foo
                      orig_parameter = line.scan(/overlong character detected at ([^ ]*)\. \[offset \"[0-9]\"\] \[file /)[0][0]
  
            elsif /Match of ".*" against ".*" required\./.match(line)
                      # Operators: All negated operators (-> "!@xxx ...")
                      # example: ModSecurity: Warning. Match of "rx ^(abc)$" against "ARGS:a" required. [file
                      orig_parameter = line.scan(/ against "([^ ]*)" required\.? \[file /)[0][0]
  
            elsif /ModSecurity: Warning\. Matched "Operator /.match(line)
                      # libModSecurity 3
                      # example: ModSecurity: Warning. Matched "Operator `ValidateByteRange' with parameter `38,44-46,48-58,61,65-90,95,97-122' against variable `ARGS:test' (Value: `/etc/passwd' ) [file                    
                      orig_parameter = line.scan(/ against variable `([^ ]*)' \(Value: `/)[0][0]
            elsif /ModSecurity: Access denied with (Warning|code [45].*)\. Matched "Operator /.match(line)
                      # libModSecurity 3
                      # example: ModSecurity: Warning. Matched "Operator `ValidateByteRange' with parameter `38,44-46,48-58,61,65-90,95,97-122' against variable `ARGS:test' (Value: `/etc/passwd' ) [file                    
                      # example: ModSecurity: Access denied with code 403 (phase 2). Matched "Operator `Ge' with parameter `5' against variable `TX:ANOMALY_SCORE' (Value: `15' )
                      orig_parameter = line.scan(/ against variable `([^ ]*)' \(Value: `/)[0][0]
            elsif /^Matched "Operator /.match(line)
                      orig_parameter = line.scan(/ against variable `([^ ]*)' \(Value: `/)[0][0]
            elsif /ModSecurity: Warning\. Invalid URL Encoding: /.match(line)
              orig_parameter = line.scan(/ at ([^ ]*)\. \[/)[0][0]
            else
                  $stderr.puts "ERROR: Could not interpret alert message. Ignoring message: #{line}"
            end
      end
    rescue => detail
      puts_error("Error parsing alert message. This is fatal. Bailing out. Alert message: #{line}", detail)
      exit 1
    end
  end

  def get_advisory (id, data, params)

    if  ADVISORY_RULES.grep(id).count == 1
      # If the rule is on the list of advisory rules, then
      # don't do a rule exclusion, but reconfigure CRS.
      # The advisory will explain how to do this for 
      # every individual rule.

      dprint("Advisory rule identified, fetching text.", params)
      advisory = get_advisory_ruleid(id, data, params)

    end

  end

  def scan_parameter (line, id, params, events, timestamp, unique_id, ip, msg, data, uri, hostname, eventfile, eventline, version, tags)
    # Parse the alert message to determine need for Advisory and to read parameter in alert
    
    if not /^Apache-Error:/.match(line)
      # ModSecurity 2.9 audit log carries Apache-Error messages that essentially duplicate
      # the ModSecurity alert message in the same log. We ignore the former to avoid
      # duplicates. The ModSecurity alert message does not carry the unique_id and the
      # hostname, though, so maybe better switch to the Apache-Error message.
      if  /ModSecurity: (Warning|Access denied.*)\. /.match(line) or 
          /\]\[\d\] (Warning. Matched|Access denied with code)/.match(line) or 
          /^Message: (Warning\. [A-Z]|Access denied with)/.match(line)

        advisory = get_advisory(id, data, params)

        orig_parameter = parse_parameter(line)

        dprint("Line parsed successfully.", params)

        parameter = determine_parameter(id, orig_parameter, data, params)

        dprint("Finished parsing line. Adding event.", params)
        events << Event.new(timestamp, id, unique_id, ip, msg, data, uri, parameter, orig_parameter, hostname, eventfile, eventline, version, tags, advisory)

      elsif /- Execution error - PCRE limits exceeded /.match(line)
        # e.g. ModSecurity: Rule 55cff957e738 [id "..."][file "/....conf"][line "471"] - Execution error - PCRE limits exceeded (-8): (null). 

        dprint("PCRE error identified.", params)
        advisory = get_advisory_ruleid("PCRE", data, params)

        dprint("Finished parsing line. Adding event.", params)
        events << Event.new(timestamp, id, unique_id, ip, msg, data, uri, parameter, orig_parameter, hostname, eventfile, eventline, version, tags, advisory)

      elsif /Audit log: Failed to create subdirectories: /.match(line)
        # e.g. ModSecurity: Audit log: Failed to create subdirectories: /.../20200121-1409 (Permission denied)
        
        dprint("Subdirectory creation error identified.", params)
        advisory = get_advisory_ruleid("AUDITLOG", data, params)

        dprint("Finished parsing line. Adding event.", params)
        events << Event.new(timestamp, id, unique_id, ip, msg, data, uri, parameter, orig_parameter, hostname, eventfile, eventline, version, tags, advisory)

      elsif /modsecurity_rules_file" directive Failed to/.match(line)
        # libModSecurity3, typically failing to open audit log file
        # example: "modsecurity_rules_file" directive Failed to open file: /root/logs/modsec_audit.log in /opt/nginx/...

        dprint("Audit log open error identified.", params)
        advisory = get_advisory_ruleid("AUDITLOGLibModSecurity3", data, params)

        dprint("Finished parsing line. Adding event.", params)
        events << Event.new(timestamp, id, unique_id, ip, msg, data, uri, parameter, orig_parameter, hostname, eventfile, eventline, version, tags, advisory)
      end

    end

    return advisory, parameter, orig_parameter, events

  end

  def dprint_event (timestamp, id, unique_id, ip, msg, data, parameter, orig_parameter, hostname, eventfile, eventline, version, tags, advisory, params)

    if params[:debug]
      dprint("Event that has been added:", params)
      dprint(" timestamp: #{timestamp}", params)
      dprint(" id: #{id}", params)
      dprint(" unique_id: #{unique_id}", params)
      dprint(" ip: #{ip}", params)
      dprint(" msg: #{msg}", params)
      dprint(" data: #{data}", params)
      dprint(" parameter: #{parameter}", params)
      dprint(" orig_parameter: #{orig_parameter}", params)
      dprint(" hostname: #{hostname}", params)
      dprint(" eventfile: #{eventfile}", params)
      dprint(" eventline: #{eventline}", params)
      dprint(" version: #{version}", params)
      dprint(" tags: #{tags}", params)
      dprint(" advisory: #{advisory}", params)
    end

  end

  def scan_standard_parameters (item, params)
    # Read standard parameters
    id = scan_line(item, "id", "0", params)
    unique_id = scan_line(item, "unique_id", "no-id-found", params)
    msg = scan_line(item, "msg", "none", params)
    data = scan_line(item, "data", "none", params)
    uri = scan_line(item, "uri", "/", params)
    hostname = scan_line(item, "hostname", "unknown", params)
    eventfile = scan_line(item, "file", "none", params)
    eventline = scan_line(item, "line", "none", params)
    version = scan_line(item, "ver", "none", params)
    tags = scan_line_tags(item, params)

    return id, unique_id, msg, data, uri, hostname, eventfile, eventline, version, tags

  end

  while ! file.eof?
	line = file.readline

	dprint("Line read: #{line}", params)

	if /^\w*#/.match(line)
            dprint("Line not relevant. Skipping.", params)
            next
        end

        if /^{"transaction":/.match(line)
            dprint("Assuming JSON input after test", params)

            hash = JSON.parse(line)

            if hash.key?("audit_data")
              # JSON ModSec v2
              dprint("Assuming ModSecurity v2 audit input", params)
              hash["audit_data"]["error_messages"].each do |event|
                # For ModSec 2.9 JSON audit log format, we take the apache error log that
                # is copied into the audit log. It duplicates the ModSecurity message that
                # is also printed in this log, but on top of the latter, it also brings the
                # hostname and the unique_id for the alert. Unfortunately it also brings
                # a 2nd iteration of the item "file" pointing to apache_util.c.
                #
                # Notice how a single JSON line / record can carry multiple alert events,
                # so we loop over the "error_messages".

                id, unique_id, msg, data, uri, hostname, eventfile, eventline, version, tags = scan_standard_parameters(event, params)
                dprint("Done parsing standard parameters", params)
                ip = scan_ip(line, params)
                if not hash["transaction"]["time"].nil?
                  timestamp = hash["transaction"]["time"]
                else
                  # This will probably result in the use of the fallback value 1970-01-01
                  timestamp = scan_timestamp(line, params)
                end

                advisory, parameter, orig_parameter, events = scan_parameter(event, id, params, events, timestamp, unique_id, ip, msg, data, uri, hostname, eventfile, eventline, version, tags)

                if params[:debug] 
                  dprint_event(timestamp, id, unique_id, ip, msg, data, parameter, orig_parameter, hostname, eventfile, eventline, version, tags, advisory, params)
                end

              end
            elsif hash["transaction"].key?("messages")
              # JSON ModSec v3
              # This is a fully split json format that we can more or less map 1:1
              #
              dprint("Assuming ModSecurity v3 JSON input", params)
              hash["transaction"]["messages"].each do |event|
              
                  timestamp = hash["transaction"]["time_stamp"]
                  id = event["details"]["ruleId"]
                  unique_id = hash["transaction"]["unique_id"]
                  ip = hash["transaction"]["client_ip"]
                  uri = hash["transaction"]["request"]["uri"]
                  msg = event["message"]
                  data = event["details"]["data"]
                  eventfile = event["details"]["file"]
                  eventline = event["details"]["lineNumber"]
                  version = event["details"]["ver"]
                  tags = event["details"]["tags"]
                  hostname = "Unknown (ModSecurity v3 JSON log format does not report hostname)"

                  orig_parameter = parse_parameter(event["details"]["match"])
                  parameter = determine_parameter(id, orig_parameter, data, params)

                  advisory = get_advisory(id, data, params)

                  if params[:debug] 
                    dprint_event(timestamp, id, unique_id, ip, msg, data, parameter, orig_parameter, hostname, eventfile, eventline, version, tags, advisory, params)
                  end

                  events << Event.new(timestamp, id, unique_id, ip, msg, data, uri, parameter, orig_parameter, hostname, eventfile, eventline, version, tags, advisory)

              end

            else
              # unknown JSON format
              $stderr.puts "Logline is supposedly JSON, but could not be identified. Ignoring line.", line
            end

        else
            dprint("Assuming non-JSON input", params)

            id, unique_id, msg, data, uri, hostname, eventfile, eventline, version, tags = scan_standard_parameters(line, params)
            dprint("Done parsing standard parameters", params)
            ip = scan_ip(line, params)
            timestamp = scan_timestamp(line, params)

            advisory, parameter, orig_parameter, events = scan_parameter(line, id, params, events, timestamp, unique_id, ip, msg, data, uri, hostname, eventfile, eventline, version, tags)

            if params[:debug] 
              dprint_event(timestamp, id, unique_id, ip, msg, data, parameter, orig_parameter, hostname, eventfile, eventline, version, tags, advisory, params)
            end

        end

  end

  dprint("Finished reading input.", params)

  return events
	
end

def build_uri_list(id, events) 
  # Purpose: build an array of URIs out of an event list filtered for given rule id
  # Input  : rule id, events array
  # Output : array with URIs
  # Return : none
  # Remarks: none
  # Tests:   none
        
      uris = Array.new
      events.select{|h| h.id == id }.each do |h|
      	if uris.grep(h.uri).length == 0 
      		uris << h.uri
      	end
      end

      uris.sort!{|x,y| x <=> y }
	
      return uris

end

def build_parameter_list(id, events)
  # Purpose: build an array of parameters out of an event list filtered for given rule id
  # Input  : rule id, event object, events array
  # Output : parameter array
  # Return : none
  # Tests:   none

	parameters = Array.new
	events.select{|h| h.id == id }.each do |h|
		if parameters.grep(h.parameter).length == 0 
                  if not h.parameter.nil?
                        # not quite sure why we can end up with a nil parameter here, but it happens
			parameters << h.parameter
                  end
		end
	end

  	parameters.sort!{|x,y| x <=> y }

	return parameters
end

def build_target_uri_list(id, events, params)
  # Purpose: build an array of parameters and paths out of an event list filtered for given rule id
  # Purpose: Build a list of path items
  # Input  : rule id, events array
  # Output : none
  # Return : array with items
  # Remarks: none
  # Tests:   none

	items = Array.new
	
	dprint("Building list with paths and parameters for this rule / event id:", params)
	
	events.select{|e| e.id == id }.each do |e|
		if e.parameter != ""
			num = items.select{|tuple| tuple[:parameter] == e.parameter && tuple[:uri] == e.uri}.length
			if num == 0
				tuple = Hash.new
				tuple[:parameter] = e.parameter
				tuple[:uri] = e.uri
				tuple[:num] = 1
				dprint("  Creating new tuple with parameter #{tuple[:parameter]} and uri #{tuple[:uri]}", params)
				items << tuple
			else
				tuple = items.select{|tuple| tuple[:parameter] == e.parameter && tuple[:uri] == e.uri}[0]
				dprint("  Raising number of occurrence of tuple with parameter #{tuple[:parameter]} and uri #{tuple[:uri]} to #{tuple[:num] + 1}", params)
				tuple[:num] = tuple[:num] + 1
			end
		else
			dprint("  No argument found in event. Event can thus not be handled in this mode. Passing to next event.", params)
		end
	end

	items.sort!{|x,y| x[:parameter] <=> y[:parameter] }
	if params[:debug]
		puts "Items/tuples to be used for ignore rule with id #{id}:"
		pp items
	end

	return items

end

def display_individual_uris(id, uris, events, params)
  # Purpose: print a list of uris out of a list of events, filtered by a rule id
  # Input  : rule id, uri array, events array
  # Output : report via stdout
  # Return : none
  # Remarks: none
  # Tests:   0100-startup-rule-byid.test OK

	str = ""

	str += "\n"
	str += "Individual paths:\n"
	uris.each do |uri|
		num = events.select{|h| h.id == id && h.uri == uri}.length

		hostnames = Array.new
		events.select{|h| h.id == id and h.uri == uri}.each do |h|
			if hostnames.grep(h.hostname).length == 0
				hostnames << h.hostname
			end
		end

		if hostnames.length > 1
			str += sprintf "  %6d %s\t(multiple services: %s)\n", num.to_s, uri, hostnames.join(" ")
		else
			str += sprintf "  %6d %s\t(service %s)\n", num.to_s, uri, hostnames[0]
		end
	end

	return str

end

def display_metainfo(event)
  # Purpose: print metainformation about an alert. This info will be used to accompany rule exclusion
  # Input  : events array
  # Output : report via stdout
  # Return : none
  # Remarks: none
  # Tests:   test_display_metainformation

        def display_metainfo_trim(str)
          
          if str.length > 77 
            str = str[0..77] + "..."
          end
          
          return str

        end

        if ! event.instance_of? Event
          # We are only accepting a single event as parameter
          return false
        end

	str = ""

	str += display_metainfo_trim("      # Based on following alert:") + "\n"
        str += display_metainfo_trim("      # //#{event.hostname}#{event.uri}") + "\n"
        str += display_metainfo_trim("      # timestamp: #{event.timestamp} id: #{event.unique_id}") + "\n"
        str += display_metainfo_trim("      # alert: #{event.id} #{event.data}") + "\n"
        str += display_metainfo_trim("      # ruleset/version: #{event.version}") + "\n"

        return str

end

def display_rule_exclusion_startup_rule_byid(id, event, events, params)
  # Purpose: print startup rule exclusion for rule selected by rule id
  # Input  : rule id, event object, events array
  # Output : report via stdout
  # Return : none
  # Remarks: none
  # Tests:   0100-startup-rule-byid.test OK

  	str = ""

	str += "# ModSec Rule Exclusion: #{event.id} : #{event.msg}\n"
        str += display_metainfo(event) if params[:metainformation]
	str += "SecRuleRemoveById #{event.id}\n"

	return str
	
end

def display_rule_exclusion_startup_rule_bytag(id, event, events, params)
  # Purpose: print startup rule exclusion for rules selected by rule tag
  # Input  : rule id, event object, events array
  # Output : report via stdout
  # Return : none
  # Remarks: none
  # Tests:   0105-startup-rule-bytag.test OK

  	str = ""

        event.tags.each do |tag|
          if tag == params[:tag] or params[:tag].nil?
		str += "# ModSec Rule Exclusion : #{event.id} via tag \"#{tag}\" (Msg: #{event.msg})\n"
                str += display_metainfo(event) if params[:metainformation]
		str += "SecRuleRemoveByTag #{escape_tag(tag)}\n"
		str += "\n"
          end
	end

	return str
	
end

def display_rule_exclusion_startup_target_byid(id, event, events, params)
  # Purpose: print startup rule exclusion for specific parameter in rule selected by rule id
  # Input  : rule id, event object, events array
  # Output : report via stdout
  # Return : none
  # Tests:   0130-startup-target-byid.test OK

  	str = ""

	parameters = build_parameter_list(id, events)

	if parameters.length == 0 or ( parameters.length == 1 and parameters[0] == "" )
		str += "No parameter available to create ignore-rule proposal.\n"
	else
		str += "# ModSec Rule Exclusion: #{id} : #{event.msg}\n"
                str += display_metainfo(event) if params[:metainformation]

		parameters.each do |parameter|
			num = events.select{|h| h.id == id && h.parameter == parameter}.length
			if parameter != ""
				str += sprintf "SecRuleUpdateTargetById %6d \"!%s\"\n", id, parameter
			end
		end
	end

	return str

end

def display_rule_exclusion_startup_target_bytag(id, event, events, params)
  # Purpose: print startup rule exclusion for specific parameter in rules selected by tag
  # Input  : rule id, event object, events array
  # Output : report via stdout
  # Return : none
  # Remarks: none
  # Tests:   0135-startup-target-bytag.test OK

  	str = ""

	parameters = build_parameter_list(id, events)

	if parameters.length == 0 or ( parameters.length == 1 and parameters[0] == "" )
		str += "No parameter available to create ignore-rule proposal.\n"
	else

        	event.tags.each do |tag|

                  if tag == params[:tag] or params[:tag].nil?

			str += "# ModSec Rule Exclusion: #{id} via tag #{tag}: (Msg: #{event.msg})\n"
                        str += display_metainfo(event) if params[:metainformation]

			parameters.each do |parameter|
				num = events.select{|h| h.id == id && h.parameter == parameter}.length
				if parameter != ""
						str += "SecRuleUpdateTargetByTag #{escape_tag(tag)} \"!#{parameter}\"\n"
				end
			end

			str += "\n"

                  end

		end
	end

	return str
end

def display_rule_exclusion_runtime_rule_byid(id, event, events, params)
  # Purpose: print runtime rule exclusion for rule selected by rule id
  # Input  : rule id, event object, events array
  # Output : report via stdout
  # Return : none
  # Remarks: proposed exclusion rule uses the first URI in the list. Additional uris are listed separately. 
  #          This can be re-considered at a later moment
  # Tests:   0150-runtime-rule-byid.test OK

  	str = ""

	uris = build_uri_list(id, events)

	str += "# ModSec Rule Exclusion: #{id} : #{event.msg}\n"
        str += display_metainfo(event) if params[:metainformation]
	str += "SecRule REQUEST_URI \"@beginsWith #{uris[0]}\" \"phase:1,nolog,pass,id:#{get_ruleid(params)},ctl:ruleRemoveById=#{id}\"\n"

        if params[:verbose]
          str += display_individual_uris(id, uris, events, params)
        end


	return str

end

def display_rule_exclusion_runtime_rule_bytag(id, event, events, params)
  # Purpose: print runtime rule exclusion for rules selected by rule tag
  # Input  : rule id, event object, events array
  # Output : report via stdout
  # Return : none
  # Remarks: This displays multiple variants based on individual tags of the same event
  #          Proposed exclusion rule uses the first URI in the list. Additional uris are listed separately. 
  #          This can be re-considered at a later moment
  # Tests:   0155-runtime-rule-bytag.test OK
	
	str = ""

	uris = build_uri_list(id, events)

        event.tags.each do |tag|

          if tag == params[:tag] or params[:tag].nil?

	 	str += "# ModSec Rule Exclusion : #{event.id} via tag \"#{tag}\" (Msg: #{event.msg})\n"
                str += display_metainfo(event) if params[:metainformation]
		str += "SecRule REQUEST_URI \"@beginsWith #{uris[0]}\" \"phase:1,nolog,pass,id:#{get_ruleid(params)},ctl:ruleRemoveByTag=#{escape_tag(tag)}\"\n"
		str += "\n"
          
          end

	end

        if params[:verbose]
         str += display_individual_uris(id, uris, events, params)
        end


	return str

end

def display_rule_exclusion_runtime_target_byid(id, event, events, params)
  # Purpose: print runtime rule exclusion for specific parameter in rule selected by rule id
  # Input  : rule id, event object, events array
  # Output : report via stdout
  # Return : none
  # Remarks: none
  # Tests:   0180-runtime-target-byid.test OK

  	str = ""

	str += "# ModSec Rule Exclusion: #{id} : #{event.msg}\n"
        str += display_metainfo(event) if params[:metainformation]

        items = build_target_uri_list(id, events, params)

	if items.length == 0 or ( items.length == 1 and items[0] == "" )
		str += "  No parameter available to create ignore-rule proposal. Please try and use different mode.\n"
	else
		items.each do |tuple|
				prefix = ""
				if params[:verbose]
					prefix = tuple[:num].to_s + " x "
				end
				str += sprintf "%sSecRule REQUEST_URI \"@beginsWith %s\" \"phase:1,nolog,pass,id:%d,ctl:ruleRemoveTargetById=%d;%s\"\n", prefix, tuple[:uri], get_ruleid(params), id, tuple[:parameter]

		end
	end

	return str
 
end

def display_rule_exclusion_runtime_target_bytag(id, event, events, params)
  # Purpose: print runtime rule exclusion for specific parameter in rules selected by rule tag
  # Input  : rule id, event object, events array
  # Output : report via stdout
  # Return : none
  # Remarks: This displays multiple variants based on individual tags of the event
  # Tests:   0185-runtime-target-bytag.test OK

  	str = ""

	parameters = Array.new
	events.select{|h| h.id == id }.each do |h|
		if parameters.grep(h.parameter).length == 0 
			parameters << h.parameter
		end
	end
	parameters.sort!{|x,y| x <=> y }

        items = build_target_uri_list(id, events, params)

	if parameters.length == 0 or ( parameters.length == 1 and parameters[0] == "" )
		str += "No parameter available to create ignore-rule proposal. Please try and use different mode.\n"
	else
		items.each do |tuple|

			event.tags.each do |tag|

                          if tag == params[:tag] or params[:tag].nil?
				str += "# ModSec Rule Exclusion: #{id} via tag #{tag}: (Msg: #{event.msg})\n"
                                str += display_metainfo(event) if params[:metainformation]

				parameters.each do |parameter|
					num = events.select{|h| h.id == id && h.parameter == parameter}.length
					if parameter != ""
							str += sprintf "SecRule REQUEST_URI \"@beginsWith %s\" \"phase:1,nolog,pass,id:%d,ctl:ruleRemoveTargetByTag=%s;%s\"\n", tuple[:uri], get_ruleid(params), escape_tag(tag), tuple[:parameter]
					end
				end
				str += "\n"

                          end

			end
		end
	end

	return str

end

def display_report(events, params)
  # Purpose: display report
  # Input  : events array
  # Output : report via stdout
  # Return : none
  # Remarks: none

  str = ""

  vprint("Displaying report ...", params)

  ids = Array.new
  extids = Array.new
  dprint("Building list of relevant ids (that is the ids we will be displaying, this is not the same as the list of events):", params)
  events.each do |event|
    # only add id once for text output, but as many times as present for JSON
		if (ids.grep(event.id).length == 0 ||  params[:output_format] == OUTPUT_JSON) && 
			( event.id != "981176" && event.id != "981202" && event.id != "981203" && event.id != "981204" && event.id != "981205" && event.id != "980100" && event.id != "980110") 
			# 981203/4/5 are the rules checking anomaly score in the end on CRS2. Ignoring those
			# 980100ff are the rules checking anomaly score in the end on CRS3. Ignoring those
			# FIXME: They should be handled by advisories
			dprint("  Adding event id #{event.id}", params)
			ids << event.id
			extids << { :id => event.id, :timestamp => event.timestamp }
		else
			# id is already part of id list
			dprint("  Ignoring event id #{event.id}", params)
		end
  end
  
  if params[:output_format] == OUTPUT_TEXT
    nil 
  elsif params[:output_format] == OUTPUT_JSON
    str += "{\"items\":["
  else
    puts_error("Output format unknown. This is fatal. Aborting.")
    exit 1
  end

  extids.each do |ext|
        id = ext[:id]
        dprint("\nLoop over event ids (id = #{id}):", params)
        event = events.find {|e| e.id == id and e.timestamp = ext[:timestamp]}

        
        unless event.advisory.nil?

          if params[:output_format] == OUTPUT_JSON
            if str[-1] == "}"
              str += ","
            end
            str += { type: "advisory", parsed_event: event.to_hash }.to_json
          else
            str += event.advisory
          end

        else

          mystr = ""
          case params[:sr]
          when MODE_STARTTIME
    	      case params[:rt] 
    	      when RTMODE_RULE
    		      case params[:ruleselector]
    		      when BY_ID
    			      # SecRuleRemoveById
    
    			      mystr += display_rule_exclusion_startup_rule_byid(id, event, events, params)
    
    		      when BY_TAG
    			      # SecRuleRemoveByTag"
    
    			      mystr += display_rule_exclusion_startup_rule_bytag(id, event, events, params)
    
    		      end
    
    	      when RTMODE_TARGET
    		      case params[:ruleselector]
    		      when BY_ID
    			      # SecRuleUpdateTargetById
    
    			      mystr += display_rule_exclusion_startup_target_byid(id, event, events, params)
    
    		      when BY_TAG
    			      # SecRuleUpdateTargetByTag
    
    			      mystr += display_rule_exclusion_startup_target_bytag(id, event, events, params)
    
    		      end
    	      end
          when MODE_RUNTIME
    	      case params[:rt] 
    	      when RTMODE_RULE
    		      case params[:ruleselector]
    		      when BY_ID
    			      # SecRule ... ctl:ruleRemoveById
    
    			      mystr += display_rule_exclusion_runtime_rule_byid(id, event, events, params)
    
    		      when BY_TAG
    			      
    			      # SecRule .... ctl:ruleRemoveByTag
    
    			      mystr += display_rule_exclusion_runtime_rule_bytag(id, event, events, params)
    
    		      end
    
    	      when RTMODE_TARGET
    		      case params[:ruleselector]
    		      when BY_ID
    			      # SecRule ... ctl:ruleRemoveTargetById
    
    			      mystr += display_rule_exclusion_runtime_target_byid(id, event, events, params)
    
    		      when BY_TAG
    			      # SecRule ... ctl:ruleRemoveTargetByTag
    
    			      mystr += display_rule_exclusion_runtime_target_bytag(id, event, events, params)
    
    		      end
    	      end
          end

          if params[:output_format] == OUTPUT_TEXT
            str += mystr
          elsif params[:output_format] == OUTPUT_JSON
            if str[-1] == "}"
              str += ","
            end
            str += { type: "exclusion", exclusion: mystr.rstrip, parsed_event: event.to_hash }.to_json
          end

      end

  end

  

  if params[:output_format] == OUTPUT_TEXT
    nil 
  elsif params[:output_format] == OUTPUT_JSON
    str += "]}"
    # hashes = events.collect{ |e| e.to_hash }
    # str = { type: "exclusion", exclusion: str.rstrip, parsed_event: hashes[0] }.to_json
  else
    puts_error("Output format unknown. This is fatal. Aborting.")
    exit 1
  end

  return str

end

def escape_tag(item)
  # Purpose: Escape the "/" character in tags
  # Input  : string
  # Output : string
  # Return : none
  # Remarks: none
  
  return item.gsub(/\//, "\\/")

end

def escape_msg(item)
  # Purpose: Replace space chars with dots
  # Input  : string
  # Output : string
  # Return : none
  # Remarks: none
  
  return item.gsub(/\//, "\\/").gsub(/\ /, ".")

end

def get_ruleid(params)
  # Purpose: Determine the ruleid for a rule, save id in ruleid file (if any)
  # Input  : none
  # Output : none
  # Return : string
  # Remarks: The ruleid is incremented
  #          The ruleid is saved into the ruleid file if ruleid file is passed
  
  ruleid = params[:ruleid].to_s
  params[:ruleid] += 1

  if params[:ruleid_file]
    begin
      File.open(params[:ruleid_file], "w") do |file|
        file.write(params[:ruleid].to_s + "\n")
      end
    rescue Errno::EACCES
      $stderr.puts "Could not write ruleid to file #{params[:ruleid_file]} due to a permission problem. Ignoring."
    rescue
      $stderr.puts "Could not write ruleid to file #{params[:ruleid_file]} due to an unknown problem. Ignoring."
    end
  end

  return ruleid

end


def check_integer(s)
  # Purpose: Check if string is positive integer
  # Input  : string
  # Output : Error messages (if any)
  # Return : true: error, false: ok
  # Remarks: None

  if s.to_i.to_s != s
    return true
  end

  unless s.to_i > 0
    return true
  end

  return false

end


def get_base_ruleid(params)
  # Purpose: Determine the initial ruleid
  # Input  : parameter hash
  # Output : none
  # Return : integer
  # Remarks: Determine ruleid:
  #          Priority 1: user submitted base id
  #                      Is either a filename pointing to a custom file with an integer value in it
  #                      Or an integer value
  #          Priority 2: ENV variable
  #          Priority 3: stored value in default file on disk
  #          Priority 4: RULEID_DEFAULT
  #          Scenarios:
  #           - User does not submit anything, but default rule file exists
  #               Resolution: Check for existence of file, check value in file, use it,
  #                 raise integer in file
  #           - User does not submit anything, but default rule file does not exist
  #               Resolution: Take RULEID_DEFAULT value
  #           - User does not aubmit anyhting, but ENV variable is set
  #               Resolution: Check env variable, use it
  #           - User submits rule id
  #               Resolution: Check rule id parameter, use it
  #           - User submits filename
  #               Resolution: Check for existence of file, check value in file, use it,
  #                 raise integer in file
  # FIXME: Write tests for this function.

  err = 0
  ruleid = nil
  file = nil

  if params.has_key?(:ruleid_cli)
    # Priority 1 - User submitted base id on command line

    if File.exist?(params[:ruleid_cli])

      file = params[:ruleid_cli]

      n = File.read(file).strip

      if check_integer(n)

        $stderr.puts "Error in ruleid parameter file (#{file}). Has to contain an integer above 0. This is fatal. Aborting."
        err = 1

      else

        ruleid = n.to_i

      end

    else
      # parameter is not a file name, so has to be an integer value

      if check_integer(params[:ruleid_cli])

        $stderr.puts "Error in ruleid parameter. Has to contain an integer above 0. This is fatal. Aborting."
        err = 1

      else

        ruleid = params[:ruleid_cli].to_i 

      end

    end

  elsif ENV['RULEID']
    # Priority 2 - ENV variable

    n = ENV['RULEID']

    if check_integer(n)

        $stderr.puts "Error in env variable RULEID (#{n}). Has to contain an integer above 0. This is fatal. Aborting."
        err = 1

    else

      ruleid = n.to_i

    end

  elsif File.exist?(params[:ruleid_file])
    # Priority 3 - Stored value in default file on disk

      file = params[:ruleid_file]

      n = File.read(file).strip

      if check_integer(n)

        $stderr.puts "Error in ruleid parameter file (#{file}). Has to contain an integer above 0. This is fatal. Aborting."
        err = 1

      else

        ruleid = n.to_i

      end

  else
      # Priority 4 - DEFAULT VALUE

      ruleid = RULEID_DEFAULT

  end

  return err, ruleid, file

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
  
  str = "\n"
  str += "Parameter overview\n"
  str += "------------------\n"
  str += "verbose    : #{params[:verbose]}\n"
  str += "debug      : #{params[:debug]}\n"
  unless check_stdin()
  	str += "files           : #{params[:filenames].each do |x| x ; end}\n"
  else
  	str += "files      : [STDIN]\n"
  	str += "startup/runtime : #{params[:sr]}\n"
  	str += "rule/target     : #{params[:rt]}\n"
  	str += "byid/tag/msg    : #{params[:ruleselector]}\n"
  	str += "Output format   : #{params[:output_format]}\n"
  end
  str += "\n\n"

  return str

end

def vprint(text, params)
  # Purpose: output text if global variable $verbose is set.
  # Input  : String input
  # Output : stdout
  # Remarks: none

  if params[:verbose]
    puts text
  end

end

def dprint(text, params)
  # Purpose: output text if global variable $debug is set.
  # Input  : String input
  # Output : stdout
  # Remarks: none
  
  if params[:debug]
    puts text
  end

end

def check_stdin ()
  # Purpose: Check for access to STDIN
  # Input  : none
  # Output : bool
  # Remarks: none

  if STDIN.tty? || STDIN.eof?
    # no stdin
    return false
  else
    # stdin
    return true
  end

end

def check_parameters(params)
  # Purpose: check parameters
  # Input  : global variable params
  # Output : stderr in case there is a problem with one of the parameters
  # Return : true if there is an error with one of the parameters; or false in absence of errors
  # Remarks: None

  err_status = false

  # Check parameter :ruleid_cli: It is either an integer or a filename
  # Step 0: Check if parameter is present
  # Step 1: Check if integer
  #   If yes: Check if above 0
  # Step 2: Check if filename (check by testing if it exists)
  #   If yes: Check if integer
  #   If yes: Check if above 0

  # Step 0
  if params.has_key?(:ruleid_cli)
    # Step 1
    if params[:ruleid_cli].to_i.to_s == params[:ruleid_cli]
      unless params[:ruleid_cli].to_i > 0
        $stderr.puts "Error in ruleid parameter (#{params[:ruleid_cli]}). Has to be an integer above 0 or an existing filename. This is fatal. Aborting."
        err_status = true
      end
    else
      # Step 2
      unless File.exist?(params[:ruleid_cli])
        $stderr.puts "Error in ruleid parameter (#{params[:ruleid_cli]}). Has to be an integer above 0 or an existing filename. This is fatal. Aborting."
        err_status = true
      else
        # file exists. Need to read and check if value is OK
        n = File.read(params[:ruleid_cli]).strip
        if n == n.to_i.to_s
          unless n.to_i > 0
            $stderr.puts "Error in ruleid parameter file (#{n}). The value stored in the file has to be an integer above 0. This is fatal. Aborting."
            err_status = true
          end
        else
          $stderr.puts "Error in ruleid parameter file (#{params[:ruleid_cli]}). Has to be an integer above 0. This is fatal. Aborting."
          err_status = true
        end
      end
    end
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

# -----------------------------------------------------------
# MAIN
# -----------------------------------------------------------

def main(params)

begin

parser = OptionParser.new do|opts|
  opts.banner = <<EOF
  
  #{File.basename(__FILE__)}

  A script that extracts ModSec alert messages out of an apache error log and
  proposes exclusion rules to make the supposed false positives disappear.

  The script is meant to be used together with the ModSecurity / Core Rule Set
  tuning methodology described at https://netnea.com. There is also a
  ModSecurity tuning cheatsheet at netnea.com that illustrates the
  various options of this script.

  Multiple options exist to tailor the exclusion rule proposals.
  These config snippets can then be included in the configuration
  in order to tune a modsecurity installation,

  Usage: #{__FILE__} [options]
EOF

  opts.banner.gsub!(/^\t/, "")

        opts.separator ""
        opts.separator "Options:"

  opts.on('-d', '--debug', 'Display debugging infos') do |none|
    params[:debug] = true;
  end

  opts.on('-v', '--verbose', 'Be verbose') do |none|
    params[:verbose] = true;
  end

  opts.on('-h', '--help', 'Displays Help') do
    puts opts
    exit
  end

  opts.on('-b', '--baseruleid RULEID', String, 'Base rule id to be used to enummerate the rules
                                     Can be either an integer above 0 or an existing filename
                                     containing an integer above 0') do |ruleid|
    params[:ruleid_cli] = ruleid
  end

  opts.on('-j', '--json', 'JSON output (default is text format)') do |none|
    params[:output_format] = OUTPUT_JSON
  end

  opts.on('-m', '--metainformation', 'Add metainformation about original alert(s) to
                                     rule exclusion output') do |none|
    params[:metainformation] = true
  end

  opts.on('-M', '--markdown', 'Print advisories in markdown instead of raw text
                                     which is the default') do |none|
    params[:advisory_format] = MARKDOWN
  end

  # START Mode Definition

  # Define startup time / runtime
  opts.on('-s', '--startup', 'Create startup time rule exclusion') do
	params[:sr] = MODE_STARTTIME
  end
  opts.on('-r', '--runtime', 'Create runtime rule exclusion') do
	params[:sr] = MODE_RUNTIME
  end

  # Define if a rule or a target of a rule will be excluded
  opts.on('-R', '--rule', 'Create rule exclusion for a complete rule') do
	params[:rt] = RTMODE_RULE
  end
  opts.on('-T', '--target', 'Create rule exclusion for an individual target of a rule') do
	params[:rt] = RTMODE_TARGET
  end
  
  # Define rule section by-id, by-tag or by-msg
  opts.on('-i', '--byid', "Select rule via rule id") do
    params[:ruleselector] = BY_ID
  end
  opts.on('-t', '--bytag [TAG]', "Select rule via tag 
                                     TAG is optional; omit to get exclusions for all tags") do |tag|
    params[:ruleselector] = BY_TAG
    params[:tag] = tag
  end

  # END Mode Definition


  # Usage notes (to be printed in help text after cli options) 
  notes = <<EOF

  Notes:

  The order of the exclusion rules matter a lot within a ModSecurity
  configuration. Startup time exxclusion rules need to be defined
  after the rule triggering the false positives is being defined
  (In case of the Core Rule Set, this means _after_ the CRS include).
  Runtime rule exclusions on the other hand need to be configured
  _before_ the CRS include.

  The base rule id can be passed on the command line with the
  option --baseruleid. This can either be an integer above 0
  or the path to a file containing an integer above 0. The script
  does not accept empty or non-existing filenames.

  Alternatively, the script will look for an environment variable
  RULEID and if that variable is not existing, then for a file
  at $HOME/.ruleid. Finally, a default rule id is taken as base rule
  id. 

  If a file is used to read the rule id from, then the new base rule
  id will be written back into the file.

  There is a cheatsheet explaining the various options
  (startup time / runtime, rule / target, by id / by tag, by message)
  The cheatsheet can be downloaded from the netnea.com website
  on the page about ModSecurity tutorials.

  This script is (c) 2010-2021 by Christian Folini, netnea.com
  It has been released under the GPLv3 license.
  Contact: mailto:christian.folini@netnea.com
  
EOF

  notes.gsub!(/^\t/, "")
  
  opts.on_tail(notes)
end

parser.parse!

ARGV.each do|f|  
  params[:filenames] << f
end

# Mandatory Argument Check
# if params[:man].nil?
#       $stderr.puts "Argument missing in call. This is fatal. Aborting."
#       exit 1
# end

rescue OptionParser::InvalidOption => detail
  puts_error("Invalid Option in command line parameter extraction. This is fatal. Aborting.", detail)
  exit 1
rescue => detail
  puts_error("Unknown error in command line parameter extraction. This is fatal. Aborting.", detail)
  exit 1
end

vprint("Starting parameter checking.", params)

	exit 1 if (check_parameters(params))

        err, params[:ruleid], params[:ruleid_file] = get_base_ruleid(params)

        exit 1 if err != 0

	puts dump_parameters(params) if params[:verbose] or params[:debug]

        vprint("Starting main program.", params)

	events = import_files(params[:filenames], params)

        vprint("Starting display routine.", params)

	puts display_report(events, params)

	vprint("Finishing main program. Bailing out.", params)

end

if __FILE__==$0
	main(params)
end

