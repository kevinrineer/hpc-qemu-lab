#!/usr/bin/env bash
set -e

TEMP=$(getopt --options "v:t:h" --longoptions "verbose:,test,help" --name "$0" -- "$@")

eval set -- "$TEMP"

while true; do
	case "$1" in
		-v|--verbose)
			verbose=true
			echo "Verbose mode enabled"
			shift
			;;
		-t|--test)
			shift
			echo "Nice test" 
			;;
		-h|--help)
			echo "Usage: $0 [--verbose <value>] [--help]"
			exit 0
			;;
		--)
			shift
			break
			;;
		*)
			echo "Internal error!" >&2
			exit 1
			;;
	esac
done

# Access remaining positional arguments after options
echo "Remaining arguments: $*"
