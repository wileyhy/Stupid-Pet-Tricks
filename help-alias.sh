#!/bin/bash
#! Version 0.5
#!   A re-implementation of `help -s`, `apropos` for bash's help builtin,
#! written in bash 5.2.
#!   There is an additional option added: '-l', for listing help topics.
#! Lists can be printed vertically ('-l','-lv') or horizontally ('-lh').
#!   Where bash's `help` builtin performs bash's internal Pattern Matching
#! syntax, this script accepts awk regular expressions. This difference
#! in functionality was an accidental design flaw in this script.
#!   SPDX-FileCopyrightText: 2024 Wiley Young
#!   SPDX-License-Identifier: GPL-3.0-or-later
#    shellcheck disable=SC2059,SC2317

: '#########  Section A  #########'

: '## Variables, etc'
: '## Note, commands starting with \:\ (colons) are Thompson-style comments'
script_name="help-alias.sh"
#set -x
set -euo pipefail
shopt -s checkwinsize

: '#+ \COLUMNS has been inconsistently inherited from parent processes'
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

: '#+ Define TMPDIR'
script_poss_temp_dirs=(
	/tmp/
	/var/tmp/
	/usr/tmp/
	/usr/local/tmp/
	"$HOME/tmp/"
	"$HOME/"
)

for 	AA_XX in "${script_poss_temp_dirs[@]}"
do
	if 	[[ -d ${AA_XX} ]] &&
		[[ -w $AA_XX ]]
	then
		: '#+ Note, if \TMPDIR is defined, it will stay the same'
		TMPDIR="${TMPDIR:=$AA_XX}"
		break
	else
		continue
	fi
done

: '#+ Executable \find\ should only returns items that \USER can r/w/x'
: '#+ Note, make sure these options can only be changed one place'
script_find_args=( '(' -user "$UID" -a -group "$(id -g)" ')' )

: '## Define traps'
script_traps_1=( SIG{INT,QUIT,STOP,USR{1,2}} )
script_traps_2=( EXIT SIGTERM )

: '#+ define function_trap()'
: '#+ Note, function definitions are not visible in xtrace'
function_trap()
{
	: '## Reset traps'
	trap - "${script_traps_1[@]}" "${script_traps_2[@]}"

	: '## Remove any & all leftover temporary directories'
	local -a BB_VV

	: '#+ Get a list of directories'
	mapfile -d "" -t BB_VV < <(
		find "${script_poss_temp_dirs[@]}" \
			"${script_find_args[@]}" -type d \
			-name '*_'"${script_name}"'_*' -print0 2>/dev/null
	)

	: '#+ If any are found...'

	: "#+ Directory count, line $LINENO"
	if 	(( "${#BB_VV[@]}" > 0 ))
	then
		: '#+ For each directory name'
		local BB_XX BB_WW BB_YY BB_ZZ
		BB_WW=$( COLUMNS=127 ps aux 2>&1 )

		for BB_XX in "${BB_VV[@]}"
		do
			: '#+ Get the embedded value of the PID'
			: '#+ ...of the shell that invoked \mkdir\...'
			BB_YY=${BB_XX##*_}

			: '#+ If a match is found, get the process\s user'
			BB_ZZ=$(
				awk -v aa="$BB_YY" '$2 == aa { print $1 }' \
					<<< "$BB_WW"
			)

			: '#+ When dup proc. of script is found, \continue'
			: '#+ If the \mkdir\ process\s user\s the same as'
			: '#+ user that invoked this script, and if found'
			: '#+ PID is not the PID for this script, then...'
			if 	[[ $BB_ZZ == "$USER" ]] &&
				! [[ $BB_YY == "$$" ]]
			then
				continue
			fi

			: '#+ Otherwise, remove said found directory'
			rm --one-file-system --preserve-root=all -fvr -- \
					"$BB_XX" ||
				exit "$LINENO"
		done
	fi
}
trap 'function_trap; kill -s SIGINT $$' "${script_traps_1[@]}"
#trap 'function_trap; exit 0' 		"${script_traps_2[@]}"

: '## Identify / define script input'
if 	(( $# != 0 ))
then
	script_strings=("$@")
else
	script_strings=(echo builtin type info ls man which)
fi
export script_strings

: '## Get the current list of help topics from bash'
: '#+ Note, \sort -u\ removes lines from output of \compgen\ in this case'
mapfile -t script_all_topix < <(
	compgen -A helptopic |
		sort -d |
		uniq
)
export script_all_topix

: '## Define temporary directory'
AA_YY=$(
	date |
		sum |
		tr -d ' \t'
)
AA_ZZ="${TMPDIR:?}/.temp_${script_name}_${AA_YY}_$$"

: '## Define temporary data file'
tmpfile="$TMPDIR/.bash_help_topics"
unset AA_XX AA_YY

	#declare -p script_strings
	set -x



: '## Match for an option flag, \-s\ or \-l*\...'
if 	[[ ${script_strings[0]:-""} = "-s" ]]
then
	: '#########  Section B  #########'

	: '## List short descriptions of specified builtins'
	unset "script_strings[0]"
	script_strings=("${script_strings[@]}")

	: '#+ Does a valid help_topics file exist?'
	mapfile -d "" -t help_topx_files < <(
		find "${script_poss_temp_dirs[@]}" -maxdepth 1 \
			"${script_find_args[@]}" -type f \
			-name "*${tmpfile##*/}*" -print0 2>/dev/null
	)
		#declare -p help_topx_files
		#echo "${Halt:?}"

	: '#+ Create the temporary directory (used for timefile)'
	mkdir "$AA_ZZ" ||
		exit "$LINENO"

	: '## Are there any help topics files lying about?'
	if 	(( ${#help_topx_files[@]} > 0 ))
	then
		: '#+ Any help topics file should be at most one day old.'
		timefile="$AA_ZZ/.t"
		touch -mt "$( date -d yesterday +%Y%m%d%H%M.%S )" \
			"$timefile"

			#stat "$timefile"

		for CC_XX in "${help_topx_files[@]}"
		do
			if 	! [[ $CC_XX -nt "$timefile" ]]
			then
				: '#+ Remove old help topics file'
				rm --one-file-system --preserve-root=all \
					-f -- "$CC_XX"
			fi
		done

		: '#+ Remove timefile'
		rm --one-file-system --preserve-root=all -f -- "$timefile"
		unset timefile
	fi

	: '#+ How many help topics files are known to exist?'
		: "number, help_topx_files: ${#help_topx_files[@]}"

	case ${#help_topx_files[@]} in
		1)
			: '#+ One file exists'
			tmpfile="${help_topx_files[*]}"

			;;#
		0)
			: '#+ No files exist; create one and parse the data'
		  	COLUMNS=256 builtin help |
				grep ^" " 		> "$AA_ZZ/o"
			cut -c -128 "$AA_ZZ/o" 		> "$AA_ZZ/c1"
			cut -c $((128+1))- "$AA_ZZ/o" 	> "$AA_ZZ/c2"
			sort -d "$AA_ZZ/c1" "$AA_ZZ/c2" |
				uniq 			> "$AA_ZZ/c0"

			: '#+ Remove leading and trailing spaces'
			sed -ie 's,^[[:space:]]*,,g; s,[[:space:]]*$,,g' \
				"$AA_ZZ/c0"

			: '#+ Write a somewhat durable file.'
			cp -a "$AA_ZZ/c0" "$tmpfile"
			;;#
		*)
			: '#+ Multiple files exist'
			echo Removing multiple topics files, and exiting.
			rm --one-file-system --preserve-root=all -f -- \
				"${help_topx_files[@]}"
			exit "$LINENO"
			;;#
	esac

	: '## Print info from the topics file and exit. '
	: '#+ Note, using awk regex rather than bash\s pattern matching'
	: '#+ syntax.'
	if 	(( ${#script_strings[@]} == 0 ))
	then
		
			more -e
	else
		: '## Bug, this section had read from tmpfile, in order to'
		: '#+ show full usage descriptions. '

		: '## If the string appears in the first column / at the'
		: '#+ beginning of \tmpfile, then print that line'

			#set -x
			#declare -p script_strings

		## Bug, if the search string is NA in the topics file, then
		#+ there s/b a 'NA' message output from the \help\ builtin

		for CC_YY in "${script_strings[@]}"
		do
		      if [[ $CC_YY == @($|%|^|\(|\(\(|.|\[|\[\[|\{|\\|\|) ]]
			then
				: '#+ Note, bash parameter expansions do'
				: '#+ not support sed\s \&\ back references'
				# shellcheck disable=SC2001
				CC_ZZ=$( sed 's,.,\\\\&,g' <<< "$CC_YY" )
			else
				CC_ZZ="$CC_YY"
			fi

			if 	[[ $CC_ZZ == \\\\% ]]
			then
				CC_ZZ='job_spec'
			fi
				#declare -p CC_ZZ script_strings

			CC_XX=$( 
			    awk -v yy="$CC_ZZ" '$1 ~ yy { print " " $0 }' \
					"$tmpfile"
			)

			if 	[[ -n $CC_XX ]]
			then
				printf '%s\n' "$CC_XX" |
					cut -c "-$(( COLUMNS - 5 ))"

			else
				# deleted: case / esac with hex codes of ASCII chars
				builtin help "$CC_YY"
			fi
		done |
			sort -d |
			uniq |
			more -e
	fi
	unset tmpfile help_topx_files CC_YY CC_ZZ

		#printf '%s\n\n' "${Halt:?}" # <>



elif
	[[ ${script_strings[0]:-} = @(-l|-lh|-lv) ]]
then
	: '#########  Section C  #########'

	: '##   Additional option: \-l\ for \list;\ \-lh\ and \-lv\ for'
	: '#+ horizontal and vertical lists, respectively. Defaults to'
	: '#+ vertical.'
	unset "script_strings[0]"
	script_strings=("${script_strings[@]}")

	: '#+ Initialize to zero...'
	: '#+ ...Carriage Return Index'
	cr_indx=0
	: '#+ ...Topic Index'
	tpc_indx=0

	: '#+ Posparm \2 can be a filter. If empty, let it be any char'
	if 	[[ -z ${script_strings[1]:-} ]]
	then
		set -- "${script_strings[0]}" '.*'
	fi

	: '## Bug, reduce the length of the list according to posparms, eg,'
	: '#+ \ex\ or \sh\...'

	: '#+ Get total Number of Help Topics for this run of this script'
	ht_count=${#script_all_topix[@]}
	: '#+ Define Maximum String Length of Topics'
	strlen=$(
		printf '%s\n' "${script_all_topix[@]}" |
			awk '{if (x < length($0)) x = length($0)}
					END {print x}'
	)
	: '#+ Define Column Width'
	col_width=$(( strlen + 3 ))
	printf_format_string=$(
		printf '%%-%ds' "${col_width}"
	)
	: '#+ Define maximum and total numbers of columns'
	max_columns=$(( ${COLUMNS:-80} / col_width ))
	all_columns=$max_columns
	(( max_columns > ht_count )) &&
		all_columns=$ht_count


	: '## Print a list'
	if 	[[ ${script_strings[0]} = "-lh" ]]
	then
		: '## Print a list favoring a horizontal sequence'

		: '#+ For each index of the list of topics'
		for tpc_indx in "${!script_all_topix[@]}"
		do
			: '## If the'
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



	elif
		[[ ${script_strings[0]} = @(-l|-lv) ]]
	then
		: '## Print a list favoring a vertical sequence'

		: '#+ Get the Number of Full Rows'
		full_rows=$(( ht_count / all_columns ))

		: '#+ Get the number of topics in any partial row (modulo)'
		row_rem=$(( ht_count % all_columns ))

		: '#+ Record whether there is a Partial Row'
		part_rows=0
		(( row_rem > 0 )) &&
			part_rows=1

		: '#+ Get the total number of Rows'
		all_rows=$(( full_rows + part_rows ))

		mapfile -d "" -t list_of_rows < <(
			DD_UU=$((all_rows-1))
			for (( DD_WW=0; DD_WW <= DD_UU; ++DD_WW ))
			do
				printf '%s\0' __row__${DD_WW}
			done
			unset DD_UU
		)
		unset "${list_of_rows[@]}" DD_WW
		#declare -a "${list_of_rows[@]}"

		DD_VV=$((${#script_all_topix[@]}-1))
		DD_XX=0
		for (( DD_YY=0; DD_YY <= DD_VV; ++DD_YY ))
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
		unset DD_VV DD_XX DD_YY

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



else
	: '#########  Section D  #########'

	: '##   If the script\s first operand is neither a \-s\ nor a'
	: '#+ \-l*\...'
		#set -x

	: '## If the number of strings is greater than zero'
	if 	(( ${#script_strings[@]} > 0 ))
	then

		for EE_XX in "${!script_strings[@]}"
		do
			grep_args+=("-e" "${script_strings[EE_XX]}")
		done
		unset EE_XX

		mapfile -d "" -t sublist_topics < <(
			for EE_YY in "${script_all_topix[@]}"
			do
				grep -F "${grep_args[@]}" <<< "$EE_YY" ||:
			done |
				tr '\n' '\0'
		)
		unset EE_YY

			#declare -p sublist_topics
			#exit 101

		for EE_ZZ in "${!sublist_topics[@]}"
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
