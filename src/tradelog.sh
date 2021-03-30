#!/bin/bash

POSIXLY_CORRECT=yes

readonly SHELL_ERROR=1
readonly ARG_ERROR=2

# Script name
readonly SCRIPT="$(basename "$0")"

# Check if the Bash Shell is really used
if [ "$SHELL" != "/bin/bash" ]; then
  exit $SHELL_ERROR
fi

########################################################################################################################

# Writes script usage
# Stdout: script usage to the stdout
function write_help() {
  cat << EOF
Usage: $SCRIPT [-h|--help] [FILTER]... [COMMAND] [LOG_FILE]...
Stock exchange trading logs analyzer

You can use one of these commands:
  list-tick      shows the list of contained tickers
  profit         counts total profit from closed positions
  pos            shows values of currently owned positions ordered by value
                   descending (the biggest first)
  last-price     shows the last-know price for each ticker
  hist-ord       shows a histogram with number of transaction for each ticker
  graph-pos      shows a graph of the owned tickers' values

There are these filters available to use:
  -a DATETIME    uses records after DATETIME only (excludes DATETIME)
                   more occurrences mean their intersection
  -b DATETIME    uses records before DATETIME only (excludes DATETIME)
                   more occurrences mean their intersection
  -t TICKER      uses only records with selected ticker(s) - could be used
                   multiple times

Other options are:
  -w WIDTH       sets size of the graphs' width
  -h, --help     show this usage information

DATETIME is in the format YYYY-mm-dd HH:MM:SS, where YYYY is the full year
(e.g., 2021), mm is the two digits month (e.g., 03 for March), dd is
the two digits day of month (e.g., 01), HH is the hour in 24-hour format
(00..23), MM are minutes with leading zero (e.g., 03) and SS are seconds
with leading zero (e.g., 09).

TICKER is the name of stock exchange ticker (symbol) - unique
identification of tradable item (e.g., APPL for Apple, a.s.).

WIDTH is the maximum number of characters to be written in graph.
The biggest number will have WIDTH characters (# or !) and smaller
numbers will have proportional number of character according its
value compared to the biggest one.
EOF
}

# Counts intersection of two datetime values
# Args:
#  - first datetime
#  - second datetime
# Stdout: intersection of provided datetime values in format YYYY-mm-dd HH:MM:SS (see usage)
# Stderr: invalid date (from date command)
function datetime_intersect() {
  local first second intersect

  first=$(date -d "$1" "+%s")
  second=$(date -d "$2" "+%s")

  intersect=$(( (first + second) / 2 ))
  date -d "@$intersect" "+%Y-%m-%d %H:%M:%S"
}

# Filters logs for tickers set by -t switches (from arg_tickers, respectively)
# Stdin: log files content to be filtered
# Stdout: logs contains tickers set by -t switches
function ticker_filter() {
  if [ -n "$arg_tickers" ]; then
    # Regex checks, if the line starts with datetime and in the second cell is exactly one of the tickers
    cat | grep -E "^[0-9 -:]*;(${arg_tickers// /|});"
  else
    cat
  fi
}

# Filters input with rules from script's input arguments
# Stdin: concatenated content of log files (or outer stdin)
# Stdout: filtered logs using rules set up by script's switches
# TODO: Add Stderr if some output goes there
function filter_input() {
  eval "cat | ticker_filter"
}

# Applies command on the provided logs
# Stdin: logs to provide command on
# Stdout: Output of the command
# TODO: Add Stderr if some output goes there
function apply_command() {
  # TODO: list-tick: cut -d ";" -f 2 | sort | uniq
  cat
}

########################################################################################################################

# Reformat arguments to stable format
opts=$(getopt -o ha:b:t:w:v -l help: -n "$SCRIPT" -s bash -- "$@") || exit $ARG_ERROR
eval set -- "$opts"

# Parse input arguments
while [ "$1" != "" ] ; do
  case $1 in
  # Show usage
  -h | --help)
    write_help
    exit 0
    ;;
  # Filter after DATETIME
  -a)
    shift # Move to the next argument (value of this switch)

    if ! date --date="$1" > /dev/null 2>&1 ; then
      echo "Invalid datetime in switch -a" >&2
      exit $ARG_ERROR
    fi

    if [ -z "$arg_after" ]; then
      arg_after=$1
    else
      # Count intersect of last and new datetime
      arg_after=$(datetime_intersect "$arg_after" "$1")
    fi
    ;;
  # Filter before DATETIME
  -b)
    shift # Move to the next argument (value of this switch)

    if ! date --date="$1" > /dev/null 2>&1 ; then
      echo "Invalid datetime in switch -b" >&2
      exit $ARG_ERROR
    fi

    if [ -z "$arg_before" ]; then
      arg_before=$1
    else
      # Count intersect of last and new datetime
      arg_before=$(datetime_intersect "$arg_before" "$1")
    fi
    ;;
  # Filter TICKER
  -t)
    shift # Move to the next argument (value of this switch)
    arg_tickers+=${arg_tickers+ } # Add space before second and every next item
    arg_tickers+="$1"
    ;;
  # Width of graph
  -w)
    if [ -n "$arg_width" ]; then
      echo "-w can be used only once" >&2
      exit $ARG_ERROR
    fi

    shift # Move to the next argument (value of this switch)
    readonly arg_width=$1
    ;;
  # Setup verbose information logging
  -v)
    readonly arg_verbose=true
    ;;
  # Separator of switches and other arguments (commands and files)
  --)
    # Only skip this "mark argument"
    ;;
  # Command to apply
  list-tick | profit | pos | last-price | hist-ord | graph-pos)
    if [ -n "$arg_command" ]; then
      echo "$SCRIPT: Only one command can be specified for each run of the script" >&2
      exit $ARG_ERROR
    fi
    readonly arg_command=$1
    ;;
  # Input files
  *)
    if [ ! -f "$1" ]; then
      echo "File '$1' doesn't exist" >&2
      exit $ARG_ERROR
    fi

    # Construct subshell commands in format ( cat file1 ; cat file2 ; gunzip -c file3.gz ; ... )
    if [ -z "$input" ]; then
      input+="( "
    else
      input+=" ; "
    fi

    if [[ "$1" =~ \.gz$ ]] ; then
      input+="gunzip -c $1"
    else
      input+="cat $1"
    fi
    ;;
  esac

  # Move to the next argument ($1 <-- $2)
  shift
done

# Close input subshell commands or set using of stdin if no file has been provided
if [ -n "$input" ]; then
  input+=" )"
else
  input="cat /dev/stdin"
fi

# Debug information after processing arguments
if [ -n "$arg_verbose" ]; then
  echo "Command : $arg_command" >&2
  echo "After   : $arg_after" >&2
  echo "Before  : $arg_before" >&2
  echo "Ticker  : $arg_tickers" >&2
  echo "Width   : $arg_width" >&2
fi

# Apply filtering and data processing (filters and command, respectively)
eval "$input | filter_input | apply_command"
