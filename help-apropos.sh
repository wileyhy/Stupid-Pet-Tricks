#!/bin/bash
## help-apropos.sh
##   A re-implementation written in bash of `help -s`, which is `apropos`
#+ for bash's help builtin. Where bash's `help` builtin performs bash's
#+ internal Pattern Matching syntax, this script accepts awk regular
#+ expressions. This difference in functionality was an accidental design
#+ flaw in this script. However, as a result, searching for `alias` will 
#+ also return `unalias`.
##   Tested on a virtualized instance of Fedora 40.


## Debug
#set -euxo pipefail

## Variables
LC_ALL=C
FF=~/.bash_help_topics
if [ $# -ne 0 ]; then
	strings=("$@")
## A list of search strings for demonstration purposes.
else
	strings=(builtins echo info ls man type which)
fi

## Remove dead temp directories
#+ Get a list of directories
mapfile -d "" -t dirs < <(find ~ -type d -name '*_mkhelp.sh_*' -print0)

#+ if any are found
if [ "${#dirs[@]}" -gt 0 ]; then
	#+ for each dir name
	for DD in "${dirs[@]}"; do
		#+ get the embedded value of $$, ie, the PID of the
		#+ invoking shell
		AA=${DD##*_}

		#+ then look to see whether the PID of the found dir is
		#+ still active
		BB=$(ps aux | awk -v dd="$AA" '$2 ~ dd')

		#+ If the PID is still active, then continue to the next
		#+ found dir
		if [ -n "$BB" ]; then
			continue
		fi

		#+ or, if the found dir is not from some active script,
                #+ then remove said found dir
		rm -fr "$DD" || exit "$LINENO"
	done
fi

## Does a valid help_topics file exist?
mapfile -d "" -t EE < <(
    find ~ -maxdepth 1 -type f -name "*${FF##*/}*" -print0)

case ${#EE[@]} in
	#+ If not, then create one.
	0)	#+ Temporary working directory
		CC=$(date | sum | tr -d ' \t')
		DD="$HOME/.tmp_mkhelp.sh_${CC}_$$"

		mkdir -p "$DD" || exit "$LINENO"

		## Parsing data
		COLUMNS=256 help | grep ^" " > "$DD/list_help_as-is"

		cut -c   -128      "$DD/list_help_as-is" > "$DD/list_col-1"
		cut -c $((128+1))- "$DD/list_help_as-is" > "$DD/list_col-2"

		sort "$DD/list_col-1" "$DD/list_col-2" > "$DD/list_col-0"

		#+ Remove leading spaces
		sed -i 's/[ \t]*$//' "$DD/list_col-0"
		# Note, for older OS X, per stackoverflow; untested
		#sed -i '' -E 's/[ '$'\t'']+$//' "$DD/list_col-0"

		## Creating durable file
		mv "$DD/list_col-0" "$FF" || exit "$LINENO"

		: Topics file created.

		## Remove working directory
		rm -fr "$DD" || exit "$LINENO"
		;;
	## Note, Thompson-style comment; readable when xtrace is enabled.
	1)	: Topics file exists.
		;;
	## Multiple files
	[2-9]|[1-9][0-9]+)
		echo Multiple topics files exist. Exiting.
		ls -la "${EE[@]}"
		exit "$LINENO"
		;;
	*)	echo Error. Exiting.
		exit "$LINENO"
		;;
esac

## Print info from the topics file (Note, using awk regex rather than 
#+ bash's pattern matching syntax. 
for HH in "${strings[@]}"; do
	awk -v regex="$HH" '$1 ~ regex { print $0 }' "$FF"
done | sort -u

exit 00
