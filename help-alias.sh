#!/bin/bash
#! Version 0.7
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

: '## Variables, etc.'
#! Note, \:\ (colon) commands are Thompson-style comments.
script_name="help-alias.sh"
#set -x
set -euo pipefail
shopt -s checkwinsize

: '#+ \COLUMNS has been inconsistently inherited from parent processes.'
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

: '#+ Executable \find\ should only return items that \USER can r/w/x.'
#! Note, make sure these options can only be changed one place.
script_find_args=( '(' -user "$UID" -o -group "$(id -g)" ')' )

: '#+ Define this rm command in just one place, to avoid any inconsistencies.'
script_rm_cmd=( rm --one-file-system --preserve-root=all -f )

: '## Define TMPDIR.'
#! Note, defining directories with a trailing forward slash will effect
#!   whether \[[\, \test\, \[\ and \stat\ dereference symlinks. However,
#!   \realpath -e\ will still resolve such strings correctly.
: '#+ From a list of possible values of TMPDIR, ordered by preference...'
AA_UU=(
	/tmp
	/var/tmp
	/usr/tmp
	/usr/local/tmp
	"$HOME/tmp"
	/dev/shm
	"$HOME"
)

: '#+ From this list, above, generate a list of known temporary directories'
#! Note, this list will be used later as search paths for \find\
for 	AA_WW in "${AA_UU[@]}"
do
	: '#+ Get a reliable absolute path'
	if 	AA_VV=$( realpath -e "${AA_WW}" 2>/dev/null )
	then
		: '#+ If the output of \realpath\ is a writeable'
		: '#+ directory and not a symlink'
		if	[[ -n ${AA_VV} ]] &&
			[[ -d ${AA_VV} ]] &&
			[[ -w ${AA_VV} ]] &&
			! [[ -h ${AA_VV} ]]
		then
			: '#+ Begin by assuming all values will be added.'
			AA_ZZ=yes

			for 	AA_TT in "${script_temp_dirs[@]}"
			do
				: '#+ Does the new directory match an'
				: '#+ existing directory?'
				if 	[[ ${AA_VV} == "${AA_TT}" ]]
				then
					: '#+ If yes, do not add that value'
					AA_ZZ=no
				else
					: '#+ If no, keep iterating'
					continue
				fi
			done

			: '#+ If the entire list has iterated without'
			: '#+ finding a match, then add it to the list'
			if 	[[ ${AA_ZZ} == yes ]]
			then
				script_temp_dirs+=( "${AA_VV}" )
			fi
		fi
	fi
done
unset AA_TT AA_UU AA_VV AA_WW AA_ZZ

	#declare -p script_temp_dirs #<>
	#echo "${Halt:?}" #<>

: '#+ Finally define TMPDIR.'
if	[[ ${#script_temp_dirs[@]} -ne 0 ]]
then
	TMPDIR="${TMPDIR:="${script_temp_dirs[0]}"}"
else
	echo Error
	exit "$LINENO"
fi
	#declare -p TMPDIR #<>
	#echo "${Halt:?}" #<>
	#set -x #<>

: '## Define temporary directory'
#! Note, format serves as a positive lock mechanism
AA_hash=$(
	date |
		sum |
		tr -d ' \t'
)
script_tmpdr="${TMPDIR}/.temp_${script_name}_hash-${AA_hash}_pid-$$.d"
declare -rx script_tmpdr AA_hash


: '#+ Create the temporary directory (used for "time file," etc.)'
mkdir "$script_tmpdr" ||
	exit "$LINENO"

: '## Define temporary data file'
script_tmpfl="$TMPDIR/.bash_help_topics"

: '## Define traps.'
script_traps_1=( SIG{INT,QUIT,STOP,TERM,USR{1,2}} )
script_traps_2=( EXIT )

: '#+ Define \function_trap()\.'
#! Note, definition of functions is not visible in xtrace.
function_trap()
{
	#local -; set -x #<>

	: '## Reset traps.'
	trap - "${script_traps_1[@]}" "${script_traps_2[@]}"

	: '## Remove any & all leftover temporary directories.'
	local -a TR_list

		#declare -p AA_UU script_find_args #<>
		#declare -p script_name #<>

	: '#+ Get a list of directories.'
	mapfile -d "" -t TR_list < <(
		find "${script_temp_dirs[@]}" "${script_find_args[@]}" \
			-type d -name '*temp_'"${script_name}"'_*.d' \
			-print0 2>/dev/null
	)

		#echo "${Halt:?}" #<>
		#declare -p TR_list

	: '#+ If any are found...'

	: "#+ Directory count (line $LINENO)."
	if 	(( "${#TR_list[@]}" > 0 ))
	then
		: '#+ For each directory name'
		local TR_XX TR_YY

		for TR_XX in "${TR_list[@]}"
		do
			: '#+ If the directory is clearly from this run of'
			: '#+ this script, then delete the directory.'
			if 	grep -qe "${script_tmpdr}" \
					-e "hash-${AA_hash}" \
					<<< "${TR_XX}"
			then
				"${script_rm_cmd[@]}" -r -- "${TR_XX}" ||
					exit "${LINENO}"
				continue

			elif
				: '#+ If the directory is clearly a'
				: '#+ previous run of this script, then'
				: '#+ delete the directory.'
				grep -qEe 'hash-[0-9]{5,7}_pid-[0-9]{3,9}' \
					<<< "${TR_XX}"
			then
				"${script_rm_cmd[@]}" -r -- "${TR_XX}" ||
					exit "${LINENO}"
				continue

			elif
				: '#+ Get a certain substring if it exists.'
				#! Note, of the shell that invoked \mkdir\.
				TR_YY=${TR_XX#*_}
				TR_YY=${TR_YY%.d}
				TR_YY=${TR_YY#*_pid-}

				: '#+ If the substring TR_YY could be a PID'
				[[ -n ${TR_YY} ]] &&
				[[ ${TR_YY} == [0-9]* ]] &&
				(( TR_YY > 300 )) &&
				(( TR_YY < 2**22 ))
			then
				: '#+ Then delete the directory.'
				"${script_rm_cmd[@]}" -r -- "${TR_XX}" ||
					exit "${LINENO}"
				continue

			else
				: '#+ Otherwise, ask the user.'
				printf '\nThis other directory was found:\n'
				printf '\t%s\n' "${TR_XX}"
				printf '\nDelete it? (Press a number.)\n'
				select AA_yn in yes no
				do
					if 	[[ -n $AA_yn ]] &&
						[[ $AA_yn == yes ]]
					then
						"${script_rm_cmd[@]}" -r \
							-- "${TR_XX}" ||
							exit "${LINENO}"
					fi
					break
				done
				unset AA_yn
			fi
		done
	fi
}
trap 'function_trap; kill -s SIGINT $$' "${script_traps_1[@]}"
#trap 'function_trap; exit 0' 		"${script_traps_2[@]}"

	#kill -s sigint "$$" #<>
	#set -x

: '## Identify / define script input'
if 	(( $# > 0 ))
then
	script_strings=("$@")
else
	script_strings=(echo builtin type info ls man which)
fi
export script_strings

: '## Get the current list of help topics from bash'
#! Note, \sort -u\ removes lines from output of \compgen\ in this case
mapfile -t script_all_topix < <(
	compgen -A helptopic |
		sort -d
)
export script_all_topix

	#declare -p script_strings #<>
	set -x #<>



: '## Match for an option flag:'
: '#+   \-s\   			-- Section B'
: '#+   \-l*\  			-- Section C'
: '#+   Neither \-s\ nor \-l*\	-- Section D'
: '#+'

if 	[[ ${script_strings[0]:-""} = "-s" ]]
then

	: '#########  Section B  #########'
	: '## List short descriptions of specified builtins'

	: '## Remove \-s\ from the array of \script_strings.'
	unset "script_strings[0]"
	script_strings=("${script_strings[@]}")

	: '## Search for help_topics files.'
	mapfile -d "" -t BB_htopx_files < <(
		find "${script_temp_dirs[@]}" -maxdepth 1 \
			"${script_find_args[@]}" -type f \
			-name "*${script_tmpfl##*/}*" -print0 2>/dev/null
	)
		#declare -p BB_htopx_files
		#echo "${Halt:?}"

	: '## Remove any out of date help topics files.'
	if 	(( ${#BB_htopx_files[@]} > 0 ))
	then
		: '#+ Configurable validity time frame'
		#! Note, validity of any help topics file should be a
                #! configurable time period, and should be an operand to
		#! \date -d\.
                BB_time="yesterday"

			#BB_time="last year" #<>
                	#BB_time="2 fortnights ago" #<>
                	#BB_time="1 month ago" #<>
                	#BB_time="@1721718000" #<>
                	#BB_time="-2 fortnights ago" #<>

		BB_file="${script_tmpdr}/${BB_time}"
		touch -mt "$( date -d "${BB_time}" +%Y%m%d%H%M.%S )" \
			"${BB_file}"

		: '#+ Begin a list of files to be removed.'
		BB_list=( "$BB_file" )

			#:;: #<>
			#stat "$BB_file" #<>
			#echo "${Halt:?}" #<>

		: '## For each found help topics file'
		#! Note, unset each deleted file so that \case\ statement
		#! below is accurate
		for BB_XX in "${!BB_htopx_files[@]}"
		do
			: '#+ If the file is older than the time frame...'
			if ! [[ ${BB_htopx_files[BB_XX]} -nt "$BB_file" ]]
			then
					: "older";: #<>

				: '#+ Add it to the removal list'
				BB_list+=("${BB_htopx_files[BB_XX]}")
				unset "BB_htopx_files[BB_XX]"
			else 	: "false" #<>
			fi
		done

		: '#+ Delete each file on the list of files to be removed.'
		"${script_rm_cmd[@]}" -- "${BB_list[@]}" ||
			exit "${LINENO}"

		unset BB_time BB_file BB_list
	fi

	: '#+ How many help topics files are known to exist?'

		: "number, BB_htopx_files: ${#BB_htopx_files[@]}" #<>

	#! Note, branches are '1', '0' and '*'.
	case ${#BB_htopx_files[@]} in
		1)
			: '#+ One file exists'
			script_tmpfl="${BB_htopx_files[*]}"
			;;#
		0)
			#! Bug, some descriptions are cut off in file col1;
			#! using 512 columns has no effect.

			: '#+ No files exist; create one and parse the data'
		  	COLUMNS=256 builtin help |
				grep ^" " > "$script_tmpdr/hlp"

			#! Note, integers 128 and 129 are indeed correct.
			cut -c -128 "$script_tmpdr/hlp"	> \
				"$script_tmpdr/col1"
			cut -c 129- "$script_tmpdr/hlp" > \
				"$script_tmpdr/col2"

			sort -d "$script_tmpdr/col1" "$script_tmpdr/col2" \
				> "$script_tmpdr/col0"

			: '#+ Remove leading and trailing spaces'
			awk '{ $1 = $1; print }' < "$script_tmpdr/col0" \
				> "$script_tmpdr/fin"

			: '#+ Write a somewhat durable file.'
			cp -a "$script_tmpdr/fin" "$script_tmpfl"
			;;#
		*)
			: '#+ Multiple files exist'
			echo Removing multiple topics files, and exiting.
			"${script_rm_cmd[@]}" -- "${BB_htopx_files[@]}" ||
				exit "${LINENO}"
			exit "$LINENO"
			;;#
	esac

		echo "${Halt:?}" #<>

	: '## Print info from the topics file and exit. '
	#! Note, using awk regex rather than bash\s pattern matching
	#! syntax.
	if 	(( ${#script_strings[@]} == 0 ))
	then
		more -e "$script_tmpfl"
	else
		: '## Bug, this section had read from \script_tmpfl, in'
		: '#+ order to show full usage descriptions. '

		: '## If the string appears in the first column or at the'
		: '#+ beginning of \script_tmpfl, then print that line'

			#set -x
			#declare -p script_strings

		## Bug, if the search string is NA in the topics file, then
		#+ there s/b a 'NA' message output from the \help\ builtin

		for BB_YY in "${script_strings[@]}"
		do
		      if [[ $BB_YY == @($|%|^|\(|\(\(|.|\[|\[\[|\{|\\|\|) ]]
			then
				#! Note, bash parameter expansions do
				#! not support sed\s \&\ back references
				# shellcheck disable=SC2001
				BB_ZZ=$( sed 's,.,\\\\&,g' <<< "$BB_YY" )
			else
				BB_ZZ="$BB_YY"
			fi

			if 	[[ $BB_ZZ == \\\\% ]]
			then
				BB_ZZ='job_spec'
			fi
				#declare -p BB_ZZ script_strings

			BB_XX=$(
			    awk -v yy="$BB_ZZ" '$1 ~ yy { print " " $0 }' \
					"$script_tmpfl"
			)

			if 	[[ -n ${BB_XX:0:8} ]]
			then
				printf '%s\n' "$BB_XX" |
					cut -c "-$(( COLUMNS - 5 ))"

			else
				#! Note, deleted: case/esac with hex codes
				#! of ASCII chars
				builtin help "$BB_YY" 2>&1 |
					awk -F 'help:' \
					    '{ print "  help:" $2 }' ||:
			fi
		done |
			sort -d |
			uniq |
			more -e
	fi
	unset BB_XX BB_YY BB_ZZ BB_htopx_files

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
		set -- "${script_strings[0]:=}" '.*'
	fi

	: '## Bug, reduce the length of the list according to posparms, eg,'
	: '#+ \ex\ or \sh\.'

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
	: '#+ \-l*\.'
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
