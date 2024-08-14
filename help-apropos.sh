#!/bin/bash
## help-apropos.sh, version 0.1
#+   A re-implementation written in bash of `help -s`, which is `apropos`
#+ for bash's help builtin. Where bash's `help` builtin performs bash's
#+ internal Pattern Matching syntax, this script accepts awk regular
#+ expressions. This difference in functionality was an accidental design
#+ flaw in this script. However, as a result, searching for `alias` will 
#+ also return `unalias`.
#+   SPDX-FileCopyrightText: 2024 Wiley Young
#+   SPDX-License-Identifier: GPL-3.0-or-later

## Variables, etc
#+   A list of search strings, either from the CLI or by default for
#+ demonstration purposes.
#set -euxo pipefail
LC_ALL=C
if [ $# -ne 0 ]
then
	strings=("$@")
else
	strings=(builtins echo info ls man type which)
fi
FF=~/.bash_help_topics

## Remove dead temp directories: Get a list of directories
mapfile -d "" -t dirs < <(find ~ -type d -name '*_mkhelp.sh_*' -print0)

#+ If any are found
if [ "${#dirs[@]}" -gt 0 ]
then
	#+ For each dir name
	for DD in "${dirs[@]}"
        do
		#+ Get the embedded value of $$, ie, the PID of the
		#+ invoking shell, then look to see whether the PID of 
                #+ the found dir is still active
		AA=${DD##*_}
		BB=$(ps aux | awk -v dd="$AA" '$2 ~ dd')

		#+ If an active PID is found, then continue to the next
		#+ found dir, ie, the next loop, or, if the found dir is 
                #+ not from some active script, then remove said found dir
		if [ -n "$BB" ]
                then
			continue
		fi
		rm -fr "$DD" || exit "$LINENO"
	done
fi

## Does a valid help_topics file exist?
mapfile -d "" -t EE < <(
    find ~ -maxdepth 1 -type f -name "*${FF##*/}*" -print0)
case ${#EE[@]} in
	#+ If no files exist, then create one. Create a temporary working directory
	0)	CC=$(date | sum | tr -d ' \t')
		DD="$HOME/.tmp_mkhelp.sh_${CC}_$$"
		mkdir -p "$DD" || exit "$LINENO"

		## Parse data and remove leading spaces
		COLUMNS=256 help | grep ^" " > "$DD/list_help_as-is"
		cut -c -128 "$DD/list_help_as-is" > "$DD/list_col-1"
		cut -c $((128+1))- "$DD/list_help_as-is" > "$DD/list_col-2"
		sort "$DD/list_col-1" "$DD/list_col-2" > "$DD/list_col-0"
		sed -i 's/[ \t]*$//' "$DD/list_col-0"

		## Creating durable file
		mv "$DD/list_col-0" "$FF" || exit "$LINENO"
  
		## Note, Thompson-style comment; readable when xtrace is enabled.
                : Topics file created.

		## Remove working directory
		rm -fr "$DD" || exit "$LINENO"
		;;
	#+ If one file exists (Thompson-style comment)
	1)	: Topics file exists.
		;;
  
	#+ If multiple files exist
	[2-9]|[1-9][0-9]+)
		echo Multiple topics files exist. Exiting.
		ls -la "${EE[@]}"
		exit "$LINENO"
		;;

        #+ Catch any errors
	*)	echo Error. Exiting. 
                exit "$LINENO"
		;;
esac

## Print info from the topics file (Note, using awk regex rather than 
#+ bash's pattern matching syntax. 
for HH in "${strings[@]}"
do
	awk -v regex="$HH" '$1 ~ regex { print $0 }' "$FF"
done |
        sort -u

exit 00
