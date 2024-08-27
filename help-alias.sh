#!/bin/bash
#+   A re-implementation of `help -s`, `apropos` for bash's help builtin, 
#+ written in bash 5.2. 
#+   There is an additional option added: '-l', for listing help topics. 
#+ Lists can be printed vertically ('-l','-lv') or horizontally ('-lh').
#+   Where bash's `help` builtin performs bash's internal Pattern Matching 
#+ syntax, this script accepts awk regular expressions. This difference 
#+ in functionality was an accidental design flaw in this script.
#+
#+   SPDX-FileCopyrightText: 2024 Wiley Young
#+   SPDX-License-Identifier: GPL-3.0-or-later
#    shellcheck disable=SC2059,SC2317
#+   Version 0.4
script_name="help-alias.sh"


## Section A
#+   Variables, etc
#set -x
set -euo pipefail
shopt -s checkwinsize

#+ \COLUMNS has been inconsistently inherited from parent processes
LC_ALL=C
if 	[[ -z ${COLUMNS:=} ]]
then
	COLUMNS=$(
		stty -a |
			tr ';' '\n' |
			awk '$1 ~ /columns/ { print $2 }'
	)
fi
export COLUMNS

## Define TMPDIR
script_poss_temp_dirs=(
	/tmp/ 
	/var/tmp/ 
	/usr/local/tmp/ 
	"$HOME/tmp/" 
	"$HOME" 
	/dev/shm
	"/run/user/$USER"
	"/proc/$$/fd"
)

for 	AA_XX in "${script_poss_temp_dirs[@]}"
do
	if	[[ -d ${AA_XX} ]] &&
		[[ -w $AA_XX ]]
	then
		## Note, if \TMPDIR is already defined, then it will not
		#+ change
		TMPDIR="${TMPDIR:=$AA_XX}"
		break
	else
		continue
	fi
done

## Make sure `find` only returns items that \USER can r/w/x, 
#+ and that any future changes to user ID can only occur in 
#+ one place
script_find_args=( '(' -user "$UID" -a -group "$(id -g)" ')' )

## Define traps
script_traps_1=( SIG{INT,QUIT,STOP,USR{1,2}} )
script_traps_2=( EXIT SIGTERM )

function_trap()
{
	## Reset traps
	trap - "${script_traps_1[@]}" "${script_traps_2[@]}"

	## Remove any & all leftover temporary directories
	#+   Get a list of directories
	local -a BB_VV
	
	mapfile -d "" -t BB_VV < <(
		find "${script_poss_temp_dirs[@]}" "${script_find_args[@]}" -type d -name '*_'"${script_name}"'_*' -print0 2>/dev/null
	)

	#+ If any are found
	:
	: "Directory count, line $LINENO"
	if 	(( "${#BB_VV[@]}" > 0 ))
	then
		#+ For each directory name
		local BB_WW BB_YY BB_ZZ BB_XX
		BB_WW=$( COLUMNS=127 ps aux 2>&1 )

		for 	BB_XX in "${BB_VV[@]}"
		do
			#+ Get the embedded value of the PID of the shell 
			#+ that invoked `mkdir`
			BB_YY=${BB_XX##*_}
		
			#+ then look to see whether that PID is still active.
			#+ If an active PID is found, then get the process's
			#+ user
			BB_ZZ=$( 
				awk -v aa="$BB_YY" '$2 == aa { print $1 }' \
					<<< "$BB_WW" 
			)

			#+ If the found process's user is the same as the 
			#+ user that invoked this script, and if the found 
			#+ PID is not the PID for this script, then another 
			#+ process of this script exists, so skip it. 
			if	[[ $BB_ZZ == "$USER" ]] &&
				! [[ $BB_YY == "$$" ]] 
			then
				continue
			fi

			#+ Remove said found directory
			rm --one-file-system --preserve-root=all -fvr -- "$BB_XX" ||
				exit "$LINENO"
		done
	fi
}
trap 'function_trap; kill -s SIGINT $$' "${script_traps_1[@]}"
#trap 'function_trap; exit 0' 		"${script_traps_2[@]}"

## Define a list of search \script_strings, either from the CLI
#+ or by default for demonstration purposes
if 	(( $# != 0 ))
then
	script_strings=("$@")
else
	script_strings=(echo builtin type info ls man which)
fi
export script_strings

#+ Get the current list of help topics from bash
#+   Note, `sort -u` removes lines from output of `compgen` in this case
mapfile -t script_all_topix < <(
	compgen -A helptopic |
		sort -d |
		uniq
)
export script_all_topix

## Define temporary directory
AA_YY=$( 
	date |
		sum |
		tr -d ' \t'
)
AA_ZZ="${TMPDIR:?}/.temp_${script_name}_${AA_YY}_$$"

## Define temporary data file
CC_AA="$TMPDIR/.bash_help_topics"
unset AA_XX AA_YY



## Section B
#+   List short descriptions of specified builtins
if 	[[ ${script_strings[0]:-""} = "-s" ]]
then
	unset "script_strings[0]"
	script_strings=("${script_strings[@]}")

	## Does a valid help_topics file exist?
	mapfile -d "" -t CC_WW < <(
		find "${script_poss_temp_dirs[@]}" -maxdepth 1 "${script_find_args[@]}" -type f -name "*${CC_AA##*/}*" -print0 2>/dev/null
	)

	## Create the temporary directory
	mkdir "$AA_ZZ" ||
		exit "$LINENO"

	## Any help topics file should be at most one day old.
	if	(( ${#CC_WW[@]} > 0 ))
	then
		timefile="$AA_ZZ/.t"
		touch -mt "$( date -d yesterday +%Y%m%d%H%M.%S )" "$timefile"
		
		for	CC_XX in "${CC_WW[@]}"
		do
			if	! [[ $CC_XX -nt "$timefile" ]]
			then
				rm --one-file-system --preserve-root=all -fv -- "$CC_XX"
			fi
		done
		rm --one-file-system --preserve-root=all -fv -- "$timefile"
		unset timefile
	fi

	## Depending on the number of files found and remaining...
	case ${#CC_WW[@]} in
		#+ If no files exist then create one. Parse data
		(0)  	COLUMNS=256 builtin help |
				grep ^" " 		> "$AA_ZZ/o"
			cut -c -128 "$AA_ZZ/o" 		> "$AA_ZZ/c1"
			cut -c $((128+1))- "$AA_ZZ/o" 	> "$AA_ZZ/c2"
			sort -d "$AA_ZZ/c1" "$AA_ZZ/c2" | 
				uniq 			> "$AA_ZZ/c0"

			## Remove leading and trailing spaces
			sed -ie 's,^[[:space:]]*,,g; s,[[:space:]]*$,,g' \
				"$AA_ZZ/c0"

			## Make a durable file.
			cp -a "$AA_ZZ/c0" "$CC_AA"
			;;#

		#+ If one file exists (Thompson-style comments)
		(1)  	:
			: Topics file exists.
			CC_AA="${CC_WW[*]}"
			:
			;;#

		#+ If multiple files exist
		(*) 	echo Removing multiple topics files, and exiting.
			rm --one-file-system --preserve-root=all -fv -- "${CC_WW[@]}"
			exit "$LINENO"
			;;#
	esac

	## Print info from the topics file and exit. (Note, using awk regex
	#+ rather than bash's pattern matching syntax.)
	if 	(( ${#script_strings[@]} == 0 ))
	then
		builtin help -s |
			more -e
	else
		## Bug, this section had read from CC_AA, in order to show
		#+ full usage descriptions. 

		## Note, awk RE fails on some special characters

		## If the string appears in the first column / at the
		#+ beginning of \CC_AA, then print that line

			#set -x
			#declare -p script_strings

		for 	CC_YY in "${script_strings[@]}"
		do
			if 	[[ $CC_YY == @($|%|^|\(|\(\(|.|\[|\[\[|\{|\\|\|) ]]
			then 
				CC_ZZ=$( sed 's,.,\\\\&,g' <<< "$CC_YY" )
			else
				CC_ZZ="$CC_YY"
			fi

			if 	[[ $CC_ZZ == \\\\% ]]
			then 
				CC_ZZ='job_spec'
			fi
				declare -p CC_ZZ script_strings

			awk -v yy="$CC_ZZ" '$1 ~ yy { print " " $0 }' "$CC_AA"
		done |
			sort -d |
			uniq |
			cut -c "-$(( COLUMNS - 5 ))" |
			more -e
	fi
	unset CC_AA CC_WW CC_YY CC_ZZ

		echo
		echo ${Halt:?}



## Section C
#+   Additional option: '-l' for "list;" '-lh' and '-lv' for horizontal
#+ and vertical lists, respectively. Defaults to vertical.
elif	
	[[ ${script_strings[0]:-} = @(-l|-lh|-lv) ]]
then
	unset "script_strings[0]"
	script_strings=("${script_strings[@]}")
	:
	: 'Initialize to zero...'
	: '...Carriage Return Index'
	cr_indx=0
	: '...Topic Index'
	tpc_indx=0
	:
	: 'Posparm \2 can be a filter. If empty, then let it be any char'
	if 	[[ -z ${2:-} ]]
	then
		set -- "$1" '.*'
	fi

	## Bug, reduce the length of the list according to posparms, eg,
	#+ 'ex' or 'sh'
	:
	: 'Get total Number of Help Topics for this run of this script'
	ht_count=${#script_all_topix[@]}
	:
	: 'Define Maximum String Length of Topics'
	strlen=$(
		printf '%s\n' "${script_all_topix[@]}" |
			awk '{if (x < length($0)) x = length($0)}
					END {print x}'
	)
	:
	: 'Define Column Width'
	col_width=$(( strlen + 3 ))
	printf_format_string=$(
		printf '%%-%ds' "${col_width}"
	)
	:
	: 'Define maximum and total numbers of columns'
	max_columns=$(( ${COLUMNS:-80} / col_width ))
	all_columns=$max_columns
	(( max_columns > ht_count )) &&
		all_columns=$ht_count



	:
	: 'Print a list favoring a horizontal sequence'
	if 	[[ $1 = "-lh" ]]
	then
		## For each index of the list of topics
		for 	tpc_indx in "${!script_all_topix[@]}"
		do
			## If the
			if 	(( cr_indx == all_columns ))
			then
				echo
				cr_indx=0
			fi

			printf "${printf_format_string}" \
				"${script_all_topix[tpc_indx]}"
			unset "script_all_topix[tpc_indx]"
			(( ++cr_indx ))
		done
		printf '\n'



	elif	:
		: 'Print a list favoring a vertical sequence'
		[[ $1 = @(-l|-lv) ]]
	then	:
		: 'Get the Number of Full Rows'
		full_rows=$(( ht_count / all_columns ))
		:
		: 'Get the number of topics in any partial row (modulo)'
		row_rem=$(( ht_count % all_columns ))
		:
		: 'Record whether there is a Partial Row'
		part_rows=0
		(( row_rem > 0 )) &&
			part_rows=1
		:
		: 'Get the total number of Rows'
		all_rows=$(( full_rows + part_rows ))

		mapfile -d "" -t list_of_rows < <(
			for 	(( DD_WW=0; DD_WW<=$((all_rows-1)); ++DD_WW ))
			do
				printf '%s\0' __row__${DD_WW}
			done
		)
		unset "${list_of_rows[@]}" DD_WW
		declare -a "${list_of_rows[@]}"

		DD_XX=0
		for 	((DD_YY=0;DD_YY<=$((${#script_all_topix[@]}-1));++DD_YY))
		do
			printf -v "__row__${DD_XX}[${cr_indx}]" '%s' \
				"${script_all_topix[DD_YY]}"

			if 	(( DD_XX == $(( all_rows - 1 )) ))
			then
				DD_XX=0
				(( ++cr_indx ))
			else
				(( ++DD_XX ))
			fi
		done
		unset DD_XX DD_YY

		function_print_elements()
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

		for DD_ZZ in "${list_of_rows[@]}"
		do
			function_print_elements "$DD_ZZ"
		done
		unset DD_ZZ
	fi



## Section D
#+   If the script's first operand is neither a '-s' nor a '-l*'
else
		#set -x

	: 'If the number of strings is greater than zero'
	if 	(( ${#script_strings[@]} > 0 ))
	then
		
		for 	EE_XX in "${!script_strings[@]}"
		do
			grep_args+=("-e" "${script_strings[EE_XX]}")
		done
		unset EE_XX

		mapfile -d "" -t sublist_topics < <(
			for 	EE_YY in "${script_all_topix[@]}"
			do 
				grep -F "${grep_args[@]}" <<< "$EE_YY" ||:
			done |
				tr '\n' '\0' 
		)
		unset EE_YY

			#declare -p sublist_topics
			#exit 101

		for 	EE_ZZ in "${!sublist_topics[@]}"
		do
			if 	(( "${#sublist_topics[@]}" > 1 ))
			then
				printf '######### %d of %d #########\n' \
					$(( EE_ZZ + 1 )) \
					"${#sublist_topics[@]}"
			fi
			builtin help "${sublist_topics[EE_ZZ]}"
			printf '\n'
		done |
			more -e
		unset EE_ZZ
	else
		builtin help |
			more -e
	fi
fi

exit 00

