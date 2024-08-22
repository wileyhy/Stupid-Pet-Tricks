#!/bin/bash

## help-alias.sh, version 0.2
#+   A re-implementation written in bash 5.2 of `help -s`, which is
#+ `apropos` for bash's help builtin, with an additional option added: '-l',
#+ for listing help topics. 
#+   Lists can be printed horizontally ('-lh') or vertically ('-l','-lv').
#+   Where bash's `help` builtin performs bash's internal Pattern Matching 
#+ syntax, this script accepts awk regular expressions. This difference 
#+ in functionality was an accidental design flaw in this script.
#+
#+   SPDX-FileCopyrightText: 2024 Wiley Young
#+   SPDX-License-Identifier: GPL-3.0-or-later


## Variables, etc: define a list of search \strings, either from the CLI
#+ or by default for demonstration purposes; \FF is a durable file name
#  shellcheck disable=SC2059
set -euo pipefail
LC_ALL=C
declare -n L=LINENO
if (( $# != 0 ))
then
	strings=("$@")
else
	strings=(echo builtin type info ls man which)
fi
export strings
FF=~/.bash_help_topics

#+ Get a list of topics
#+   Note, `sort -u` removes lines from output of `compgen` in this case
mapfile -t all_topix < <(
	compgen -A helptopic |
		sort -d |
		uniq
)
export all_topix

#+ \COLUMNS has been inconsistently inherited from parent processes
shopt -s checkwinsize
if [[ -z ${COLUMNS:=} ]]
then
	COLUMNS=$(
		stty -a |
			tr ';' '\n' |
			awk '$1 ~ /columns/ { print $2 }'
	)
fi
export COLUMNS

## Remove any "dead" temporary directories: get a list of
#+ directories
mapfile -d "" -t dirs < <(
	find ~ -type d -name '*_mkhelp.sh_*' -print0
)

#+ If any are found
:;: "Directory count, line $L"
if (( "${#dirs[@]}" > 0 ))
then
	#+ For each directory name
	ps_o=$( ps aux 2>&1 )
	for DD in "${dirs[@]}"
	do
		#+ Get the embedded value of $$, ie, the PID of the
		#+ invoking shell, then look to see whether the PID
		#+ from the found directory is still active
		AA=${DD##*_}

		#+ If an active PID is found, then continue to the
		#+ next found directory, ie, the next loop
		BB=$( awk -v aa="$AA" '$2 == aa' <<< "$ps_o" )
		if [[ -n "${BB:0:8}" ]]
		then
			continue
		fi

		#+ Remove said found directory
		rm -fr "$DD" ||
			exit "$L"
	done
fi



## List short descriptions of specified builtins
if [[ ${strings[0]:-""} = "-s" ]]
then
	unset "strings[0]"
	strings=("${strings[@]}")

	## Does a valid help_topics file exist?
	mapfile -d "" -t EE < <(
		find ~ -maxdepth 1 -mtime -7 -type f -name "*${FF##*/}*" \
			-print0
	)

	case ${#EE[@]} in
		#+ If no files exist then create one. Use a new temporary
		#+ working directory with a unique hash based on the time
		(0)  	CC=$(
				date |
					sum |
					tr -d ' \t'
			)
			DD="$HOME/.tmp_mkhelp.sh_${CC}_$$"
			mkdir "$DD" ||
				exit "$L"

			## Parse data
			COLUMNS=256 builtin help |
				grep ^" " > "$DD/o"
			cut -c -128 "$DD/o" > "$DD/c1"
			cut -c $((128+1))- "$DD/o" > "$DD/c2"
			sort -d "$DD/c1" "$DD/c2" | 
				uniq > "$DD/c0"

			## Remove leading and trailing spaces
			sed -ie 's,^[[:space:]]*,,g; s,[[:space:]]*$,,g' \
				"$DD/c0"

			## Make a durable file.
			cp -a "$DD/c0" "$FF"

		       	## Remove working directory.
			rm -fr "$DD" ||
				exit "$L"
			;;#

		#+ If one file exists (Thompson-style comment)
		(1)  	: Topics file exists.
			;;#

		#+ If multiple files exist
		(*) 	echo Multiple topics files exist. Exiting.
			ls -la "${EE[@]}"
			exit "$L"
			;;#
	esac

	## Print info from the topics file and exit. (Note, using awk regex
	#+ rather than bash's pattern matching syntax.)
	if (( ${#strings[@]} == 0 ))
	then
		builtin help -s |
			more -e
	else
		## Bug, this section had read from FF, in order to show
		#+ full usage descriptions. 

		## Note, awk RE fails on some special characters

		## If the string appears in the first column / at the
		#+ beginning of \FF, then print that line

		set -x

		for KK in "${strings[@]}"
		do
			if [[ $KK == @(%|\(\(|.|:|\[|\[\[|{) ]]
			then 
				printf -v YY '[%s]' "$KK"
			else
				YY="$KK"
			fi

			if [[ $YY == "[%]" ]]
			then 
				YY='job_spec'
			fi

			awk -v yy="$YY" '$1 ~ yy { print " " $0 }' "$FF"
		done |
			sort -d |
			uniq |
			cut -c "-$(( COLUMNS - 5 ))" |
			more -e
		unset KK
	fi

## Additional option: '-l' for "list;" '-lh' and '-lv' for horizontal
#+ and vertical lists, respectively. Defaults to vertical.
elif
	[[ ${strings[0]:-} = @(-l|-lh|-lv) ]]
then
	unset "strings[0]"
	strings=("${strings[@]}")

	:;: 'Initialize to zero...'
	: '...Carriage Return Index'
	cr_indx=0
	: '...Topic Index'
	tpc_indx=0

	:;: 'Posparm \2 can be a filter. If empty, then let it be any char'
	if [[ -z ${2:-} ]]
	then
		set -- "$1" '.*'
	fi

	## Bug, reduce the length of the list according to posparms, eg,
	#+ 'ex' or 'sh'

	:;: 'Get total Number of Help Topics for this run of this script'
	ht_count=${#all_topix[@]}

	:;: 'Define Maximum String Length of Topics'
	strlen=$(
		printf '%s\n' "${all_topix[@]}" |
			awk '{if (x < length($0)) x = length($0)}
					END {print x}'
	)

	:;: 'Define Column Width'
	col_width=$(( strlen + 3 ))
	printf_format_string=$(
		printf '%%-%ds' "${col_width}"
	)

	:;: 'Define maximum and total numbers of columns'
	max_columns=$(( ${COLUMNS:-80} / col_width ))
	all_columns=$max_columns
	(( max_columns > ht_count )) &&
		all_columns=$ht_count



	:;: 'Print a list favoring a horizontal sequence'
	if [[ $1 = "-lh" ]]
	then
		## For each index of the list of topics
		for tpc_indx in "${!all_topix[@]}"
		do
			## If the
			if (( cr_indx == all_columns ))
			then
				echo
				cr_indx=0
			fi
			printf "${printf_format_string}" \
				"${all_topix[tpc_indx]}"
			unset "all_topix[tpc_indx]"
			(( ++cr_indx ))
		done
		printf '\n'



	elif
		:;: 'Print a list favoring a vertical sequence'
		[[ $1 = @(-l|-lv) ]]
	then
		:;: 'Get the Number of Full Rows'
		full_rows=$(( ht_count / all_columns ))

		:;: 'Get the number of topics in any partial row (modulo)'
		row_rem=$(( ht_count % all_columns ))

		:;: 'Record whether there is a Partial Row'
		part_rows=0
		(( row_rem > 0 )) &&
			part_rows=1

		:;: 'Get the total number of Rows'
		all_rows=$(( full_rows + part_rows ))

		mapfile -d "" -t list_of_rows < <(
			for (( II=0; II<=$((all_rows-1)); ++II ))
			do
				printf '%s\0' __row__${II}
			done
		)
		unset "${list_of_rows[@]}"
		declare -a "${list_of_rows[@]}"

		HH=0
		for (( II=0; II <= $(( ${#all_topix[@]} - 1 )); ++II ))
		do
			printf -v "__row__${HH}[${cr_indx}]" '%s' \
				"${all_topix[II]}"

			if (( HH == $(( all_rows - 1 )) ))
			then
				HH=0
				(( ++cr_indx ))
			else
				(( ++HH ))
			fi
		done

		_print_elements()
		{

			local -a elements
			local -n array="$1"

			mapfile -d "" -t elements < <(
				printf '%s\0' "${array[@]}"
			)
				#declare -p elements
			printf "$printf_format_string" "${elements[@]}"
			echo
		}

		#mapfile -t list_of_rows < <(
			#sort -hn

		for JJ in "${list_of_rows[@]}"
		do
			_print_elements "$JJ"
		done
	fi



## If the script's first operand is neither a '-s' nor a '-l*'
else
		#set -x

	: 'If the number of strings is greater than zero'
	if (( ${#strings[@]} > 0 ))
	then
		
		for ZZ in "${!strings[@]}"
		do
			grep_args+=("-e" "${strings[ZZ]}")
		done

		mapfile -d "" -t sublist_topics < <(
			for UU in "${all_topix[@]}"
			do 
				grep -F "${grep_args[@]}" <<< "$UU" ||:
			done |
				tr '\n' '\0' 
		)

			#declare -p sublist_topics
			#exit 101

		for YY in "${!sublist_topics[@]}"
		do
			if 	(( "${#sublist_topics[@]}" > 1 ))
			then
				printf '######### %d of %d #########\n' \
					$(( YY + 1 )) \
					"${#sublist_topics[@]}"
			fi
			builtin help "${sublist_topics[YY]}"
			printf '\n'
		done |
			more -e
	else
		builtin help |
			more -e
	fi
fi

exit 00
