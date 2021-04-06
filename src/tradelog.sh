#!/usr/bin/env bash
# Stock exchange trading logs analyzer
# Author: Michal Šmahel (xsmahe01)
# Date: March-April 2021

export POSIXLY_CORRECT=yes
export LC_ALL=C

readonly SHELL_ERROR=1
readonly ARG_ERROR=2

# Script name
readonly SCRIPT="$(basename "$0")"

# Check if the Bash Shell is really used
if [ -z "$BASH_VERSION" ] ; then
  echo "You are using bad Shell. This script has been written for Bash" >&2
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

# Checks if the datetime input from switches "-a" and "-b" is valid
# Args:
#  - datetime string (YYYY-mm-dd HH:MM:SS)
#  - name of the switch providing this input argument
# Stderr: invalid date
function check_datetime() {
  # New versions of date doesn't know -j switch used in old versions of the program
  date -j > /dev/null 2>&1
  if [ $? == 1 ]; then
    # New version of date
    date -d "$1" > /dev/null 2>&1
  else
    # Old versions of date
    date -j -f "%Y-%m-%d %H:%M:%S" "$1" > /dev/null 2>&1
  fi

  if [ $? == 1 ]; then
    echo "Invalid datetime in switch $2" >&2
    exit $ARG_ERROR
  fi
}

# Counts intersection of two datetime values
# Args:
#  - first datetime
#  - second datetime
# Stdout: intersection of provided datetime values in format YYYY-mm-dd HH:MM:SS (see usage)
function datetime_intersect() {
  local first second intersect

  # New versions of date doesn't know -j switch used in old versions of the program
  date -j > /dev/null 2>&1
  if [ $? == 1 ]; then
    # New version of date
    first=$(date -d "$1" "+%s")
    second=$(date -d "$2" "+%s")

    intersect=$(( (first + second) / 2 ))
    date -d "@$intersect" "+%Y-%m-%d %H:%M:%S"
  else
    # Old versions of date
    first=$(date -j -f "%Y-%m-%d %H:%M:%S" "$1" "+%s")
    second=$(date -j -f "%Y-%m-%d %H:%M:%S" "$2" "+%s")

    intersect=$(( (first + second) / 2 ))
    date -j -f "%s" "$intersect" "+%Y-%m-%d %H:%M:%S"
  fi
}

# ----------------------------------------------------------------------------------------------------------------------
# Filters:

# Filters logs for tickers set by -t switches (from arg_tickers, respectively)
# Stdin: log files content to be filtered
# Stdout: logs contains tickers set by -t switches
function ticker_filter() {
  if [ -n "$arg_tickers" ]; then
    # Regex checks, if the line starts with datetime and in the second cell is exactly one of the tickers
    grep -E "^[0-9 -:]*;(${arg_tickers// /|});"
  else
    cat
  fi
}

# Filters logs for records with datetime after set limit (in arg_after)
# Stdin: log files content to be filtered
# Stdout: logs with datetime after one set by -a switch(es)
function after_filter() {
  if [ -n "$arg_after" ]; then
    awk -F ";" '{ if($1 > arg_after) { print } }' "arg_after=$arg_after"
  else
    cat
  fi
}

# Filters logs for records with datetime before set limit (in arg_before)
# Stdin: log files content to be filtered
# Stdout: logs with datetime before one set by -b switch(es)
function before_filter() {
  if [ -n "$arg_before" ]; then
    awk -F ";" '{ if($1 < arg_before) { print } }' "arg_before=$arg_before"
  else
    cat
  fi
}

# Filters input with rules from script's input arguments
# Stdin: concatenated content of log files (or outer stdin)
# Stdout: filtered logs using rules set up by script's switches
function filter_input() {
  ticker_filter | after_filter | before_filter
}

# ----------------------------------------------------------------------------------------------------------------------
# Commands:

# Applies list-tick command
# Stdin: log files content to apply command to
# Stdout: unique list of tickers ordered by name alphabetically
function list_tick_command() {
  cut -d ";" -f 2 | sort -u
}

# Applies profit command
# Stdin: log files content to apply command to
# Stdout: final profit from closed transactions
function profit_command() {
  # Profit is sum of sell transaction values (unit price * volume) - sum of buy transaction values
  awk -F ";" '{ if($3 == "sell") { profit+=$4*$6 } else { profit-=$4*$6 } } END { printf "%.2f\n", profit }'
}

# Applies pos command
# Stdin: log files content to apply command to
# Stdout: list of total values of currently owned positions
function pos_command() {
  awk -F ";" '
    {
      # Number of owned units
      if($3 == "buy") {
        units[$2]+=$6
      } else {
        units[$2]-=$6
      }

      # List of ticker values - new value replace old one, so at the end there is the newest (the last one)
      values[$2]=$4
      # List of ticker names
      tickers[$2]=$2
    } END {
      # Find the longest number
      for(ticker in tickers) {
        tmp = sprintf("%.2f", values[ticker] * units[ticker])

        if(length(tmp) > max) {
          max = length(tmp)
        }
      }

      for(ticker in tickers) {
        printf "%-10s: %*.2f\n", ticker, max, (values[ticker] * units[ticker])
      }
    }
  ' | sort -nrt ":" -k 2,2
}

# Applies last-price command
# Stdin: log files content to apply command to
# Stdout: list of last values of currently owned positions
function last_price_command() {
  awk -F ";" '
    {
      # List of ticker values - new value replace old one, so at the end there is the newest (the last one)
      values[$2]=$4
      # List of ticker names
      tickers[$2]=$2

      # Find the longest number
      if(length($4) > max) {
        max = length($4)
      }
    } END {
      for(ticker in tickers) {
        printf "%-10s: %*.2f\n", ticker, max, (values[ticker])
      }
    }
  ' | sort -t ":" -k 1,1
}

# Applies graph-pos command
# Stdin: log files content to apply command to
# Stdout: ASCII graph of total values of currently owned positions
function graph_pos_command() {
  pos_command | sed -r "s/-([0-9.]+)/\1-/" | sort -nrt ":" -k 2,2 | awk -F ":" '
    # Get maximum
    NR == 1 {
      max = $2
    } {
      # Is it negative number? (contains "-" char)
      negative = index($2, "-") != 0

      # Number of UNICODE chars to be displayed
      if(arg_width == "") {
        graph_size = int($2 / 1000)
      } else {
        graph_size = int(($2 * arg_width) / max)
      }

      # Print ticker name and other stuff exclude graph
      printf "%-10s:", $1

      # Print graph
      if(graph_size > 0) {
        printf " "
        for(i = 0; i < graph_size; i++) {
          if(negative) {
            printf "!"
          } else {
            printf "#"
          }
        }
      }
      printf "\n"
    }
  ' "arg_width=$arg_width" | sort -t ":" -k 1,1
}

# Applies hist-ord command
# Stdin: log files content to apply command to
# Stdout: ASCII histogram of number of transaction for currently owned positions
function hist_ord_command() {
  awk -F ";" '
    {
      # Counting number of transactions for each ticker
      transactions[$2]+=1
      # List of ticker names
      tickers[$2]=$2
    } END {
      # Find maximum number of transactions
      max = 0
      for(ticker in tickers) {
        if(transactions[ticker] > max) {
          max = transactions[ticker]
        }
      }

      for(ticker in tickers) {
        # Number of UNICODE chars to be displayed
        if(arg_width == "") {
          hist_size = transactions[ticker]
        } else {
          hist_size = int((transactions[ticker] * arg_width) / max)
        }

        # Print ticker name and other stuff exclude graph
        printf "%-10s:", ticker

        # Print graph
        if(hist_size > 0) {
          printf " "
          for(i = 0; i < hist_size; i++) {
            printf "#"
          }
        }
        printf "\n"
      }
    }
  ' "arg_width=$arg_width" | sort -t ":" -k 1,1
}

# Applies command on the provided logs
# Stdin: logs to provide command on
# Stdout: Output of the command
function apply_command() {
  # Command hasn't been set
  if [ -z "$arg_command" ]; then
      cat
  fi

  case $arg_command in
  list-tick)
    list_tick_command
    ;;
  profit)
    profit_command
    ;;
  pos)
    pos_command
    ;;
  last-price)
    last_price_command
    ;;
  hist-ord)
    hist_ord_command
    ;;
  graph-pos)
    graph_pos_command
    ;;
  esac
}

########################################################################################################################

# Reformat arguments to stable format
getopt -T > /dev/null 2>&1
if [ $? == 4 ]; then
  # General version for new versions of getopt program
  opts=$(getopt -o ha:b:t:w:v -l help: -n "$SCRIPT" -s bash -- "$@") || exit $ARG_ERROR
else
  # Compatibility mode for older version of getopt program
  opts=$(getopt ha:b:t:w:v "$@") || exit $ARG_ERROR
  opts=$(echo "$opts" | sed -Er "s/([0-9]{4}-[0-9]{2}-[0-9]{2}) ([0-9]{2}:[0-9]{2}:[0-9]{2})/'\1 \2'/g")
fi
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

    check_datetime "$1" "-a"

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

    check_datetime "$1" "-b"

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

# Apply filtering and data processing (filters and command, respectively)
eval "$input | filter_input | apply_command"
