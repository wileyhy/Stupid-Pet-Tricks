#!/bin/bash
#+
#+
#+ DESCRIPTION
#+
#! help-alias.sh, Version 2.0
#!
#!   For bash\s help builtin, written in bash 5.2, there is an additional
#! option added: \-l\, for listing help topics. Lists can be printed
#! vertically (\-l\) or horizontally (\-L\).
#!
#!   Where bash\s `help` builtin performs bash\s internal Pattern Matching
#! syntax, this script accepts awk regular expressions. This difference
#! in functionality was an accidental design flaw in this script.
#!
#!   SPDX-FileCopyrightText: 2024 Wiley Young
#!   SPDX-License-Identifier: GPL-3.0-or-later
#!
#!   The default options for bash builtin \help\, in order of precedence:
#!
#!     --help   Help text of builtin \help\
#!     --       Help text
#!                      (If the \--\ string is the first argument,
#!                       otherwise ignored.)
#!     -d       Description
#!     -m       Man page
#!     -s       Summary

#    shellcheck disable=SC2059,SC2317
	#set -x # <>



## SCRIPT

## Builtin \help\ must exist.
#! 	Question, when was the \help\ builtin introduced? ~v.2, per AI
#! Note, due to errexit, it\s infeasible to use a function
#!   for this recurring \type | grep\ pipeline.

if 	! type -a help |
		grep -q " is a shell builtin"$
then
	printf "The %bhelp%b builtin is required by this" '\x60' '\x60'
	printf ' script. Exiting.\n'
fi



:;:;: '## Enablement of Enhancements.';:
#! Note, Uncomment any individual enhancement to alter program behavior.

  	enable=( [0]="_any_enhancements_" )
  	enable+=( [1]="_manual_per_execution_data_directories_" )

  	enable+=( [2]="_semi_persistent_data_file_" )
  	enable+=( [3]="_manual_identify_help_topics_" )

  #	enable+=( []="_option_short_l_" )
  #	enable+=( []="_option_short_L_" )
  #	enable+=( []="_option_long_list_" )
  #	enable+=( []="_option_short_h_" )
  #	enable+=( []="_option_short_H_" )
  #	enable+=( []="_option_short_question_mark_" )
  #	enable+=( []="_option_long_summary_" )
  #	enable+=( []="_option_long_description_" )
  #	enable+=( []="_option_long_manpg_" )
  #	enable+=( []="_input_processing_options_" )
  #	enable+=( []="_input_processing_operands_" )
  #	enable+=( []="_input_complex_trings_" )
  #	enable+=( []="_input_validation_" )
  #	enable+=( []="_output_format_more_e_" )
  #	enable+=( []="_output_format_remove_suggestions_punctuation_" )
  #	enable+=( []="_output_format_remove_suggestions_single_char_" )
  #	enable+=( []="_output_format_remove_suggestions_double_char_" )
  #	enable+=( []="_output_format_add_suggestions_for_newbies_" )
  #	enable+=( []="_output_format_reminder_quote_strings_" )
  #	enable+=( []="_output_format_whitespace_delimiters_" )
  #	enable+=( "_all_enhancements_" )



:;:;: '## Enhancement Zero: Any';:

if 	[[ -z ${enable[0]:-} ]]
then
	builtin help "$@"
	exit "$?"
fi



## Shell settings and options.

set -e # <>
set -u # <>
set -o pipefail # <>
shopt -s checkwinsize



## Variables, etc.

## \COLUMNS has been inconsistently inherited from parent processes.
LC_ALL=C
export LC_ALL
if      [[ -z ${COLUMNS:=} ]]
then
        : "true" #<>
        COLUMNS=$(
                stty -a |
                        tr ";" '\n' |
                        awk '$1 ~ /columns/ { print $2 }'
        )
else    : "false" #<>
fi
export COLUMNS

## Name of this script.
scr_name="help-alias.sh"
scr_name=${scr_name//[$'\t\n ']/}

## Make sure that certain parameters can only be changed one place.
scr_find_args=( "(" -user "${UID}" -o -group "$( id -g )" ")" )
scr_rm_cmd=( command -p rm --one-file-system --preserve-root=all --force )



:;:;: '## Enhancement One: Manual per-execution Data Directories';:

if 	[[ -n ${enable[1]:-} ]]
then
	## Define TMPDIR.
	#! Note, defining directories with a trailing forward slash will
	#!   effect whether \[[\, \test\, \[\ and \stat\ dereference
	#!   symlinks. However, \realpath -e\ will still resolve such
	#!   strings correctly.

	## From a list of possible values of TMPDIR, ordered by preference:
	#! Note, this list will be used later as search paths for \find\
	AA_UU=( "${TMPDIR:=""}"
        	"${TEMP:=""}"
        	"${TMP:=""}"
        	/tmp
        	/var/tmp
        	/dev/shm
        	/usr/tmp
        	"${XDG_RUNTIME_DIR:=""}/tmp"
        	/usr/local/tmp
        	"${HOME}/tmp"
        	"${HOME}"
	)

	## From this list, above, generate a list of known temporary
	#+   directories.
	for     AA_WW in "${!AA_UU[@]}"
	do
        	## Begin major loop: Get a reliable absolute path.
        	if      AA_VV=$( realpath -e "${AA_UU[AA_WW]}" 2>/dev/null )
        	then
                	: "true" #<>

                	## If the output of \realpath\ is a writeable
                	#+   directory and not a symlink.
                	if      [[ -n ${AA_VV} ]] &&
                        	[[ -d ${AA_VV} ]] &&
                        	[[ -w ${AA_VV} ]] &&
                        	! [[ -h ${AA_VV} ]]
                	then
                        	## Begin by assuming all values will be
                        	#+   added.
                        	AA_ZZ=yes

                        	## Begin minor loop: if an element from the
				#+   prior list is absent from the new list,
				#+   then add that element to the new list.
                        	for     AA_TT in "${scr_temp_dirs[@]}"
                        	do
                                	## Does the new directory match an
                                	#+   existing directory?
                                	if      [[ ${AA_VV} == "${AA_TT}" ]]
                                	then
                                        	## If yes, do not add that
                                        	#+   value, and end the
                                        	#+   minor loop.
                                        	AA_ZZ=no
                                        	break
                                	else
                                        	## If no, begin the next
                                        	#+   iteration of the minor
                                        	#+   loop.
                                        	continue
                                	fi
                        	## End minor loop.
                        	done

                        	## If the entire list has iterated without
                        	#+   finding a match, then add it to the
				#+   list.
                        	if      [[ ${AA_ZZ} == yes ]]
                        	then
                                	scr_temp_dirs+=( "${AA_VV}" )
                        	fi
                	fi

        	else
                	: "false" #<>

                	## If \realpath\ returns a zero length string,
                	#+   then unset the current index \AA_WW.
                	unset "AA_UU[AA_WW]"
                	continue
        	fi
	## End major loop.
	done
	unset AA_TT AA_UU AA_VV AA_WW AA_ZZ

	## Finally define TMPDIR.
	if      [[ ${#scr_temp_dirs[@]} -ne 0 ]]
	then
        	TMPDIR="${TMPDIR:="${scr_temp_dirs[0]}"}"
        	export TMPDIR
        	readonly TMPDIR
	else
        	echo Error
        	exit "${LINENO}"
	fi
        	#declare -p TMPDIR #<>
        	#: "${Halt:?}" #<>
        	#set -x # <>

	## Define groups of traps to be caught and handled.
	scr_fnct_traps_1=( SIG{INT,QUIT,STOP,TERM,USR{1,2}} )
	scr_fnct_traps_2=( EXIT )

	## Define \_fn-trap()\.
	_fn-trap ()
	{
		## Get the exit code of the previous command.
		#TR_ec=$?

		## Remove the line number from the positional parameters.
		#! Note, I attempted an alias addition of LINENO. Errexit
		#!   causes failure.
		#shift

        	## Reset traps.
        	trap - "${scr_fnct_traps_1[@]}" "${scr_fnct_traps_2[@]}"

        	## Get a list of existing temporary directories from
		#+   this an prior executions.
        	local -a TR_list
        	mapfile -d "" -t TR_list < <(
                	find "${scr_temp_dirs[@]}" \
                        	-type d "${scr_find_args[@]}" \
                        	-name "*${scr_name}*" \
                        	-print0 2> /dev/null
        	)

        	## Begin loop: Delete any existing temporary directories.
        	if      ((  "${#TR_list[@]}" > 0  ))
        	then
                	## If any are found, then for each directory name.
                	local TR_XX TR_YY TR_dir TR_rm

                	for TR_XX in "${!TR_list[@]}"
                	do
                        	## Define a usable variable name.
                        	TR_dir="${TR_list[TR_XX]}"

                        	## If the directory is clearly from some
                        	#+   run of this script, then add it to
                        	#+   the deletion list \TR_rm.
                        	if
				  [[ ${TR_dir} =~ _pid-[0-9]{3,9}.d$   ]] ||
                                  [[ ${TR_dir} =~ _ran-[a-zA-Z0-9]{8}_ ]] ||
                                  [[ ${TR_dir} =~ _hash-[0-9]{5,7}_    ]]
                        	then
                                	: "true" #<>

                                	## Add the dir to the list.
                                	mapfile -O "${TR_XX}" -t TR_rm \
                                        	<<< "${TR_dir}"

                                	## Restart loop.
                                	continue
                        	else    : "false" #<>
                        	fi

                        	## Otherwise, get a PID substring if one
                        	#+   exists.
                        	TR_YY=${TR_dir##*_pid-}
                        	TR_YY=${TR_YY%.d}

                        	## Is there a PID substring in \{TR_dir}\?
                        	if      [[ -n ${TR_YY}        ]] &&
                                	[[ ${TR_YY} == [0-9]* ]] &&
                                	((  TR_YY > 300       )) &&
                                	((  TR_YY < 2**22     ))
                        	then
                                	: "true" #<>

                                	## Then add the directory to the
                                	#+   deletion list.
                                	mapfile -O "${TR_XX}" -t TR_rm \
                                        	<<< "${TR_dir}"
                        	else    : "false" #<>
                        	fi
                        	## Restart loop.
                	## End loop.
                	done

                	## If any found directories passed the filters, then
                	#+   remove them.
                	if      ((  ${#TR_rm[@]} > 0  ))
                	then
					ls -alhFi "${TR_rm[@]}" #<>

                        	"${scr_rm_cmd[@]}" --recursive --verbose -- \
					"${TR_rm[@]}" || exit "${LINENO}"
                	fi
        	fi

			: "BASHPID: ${BASHPID}" #<>

        	## Kill the parent process with signal \interrupt\.
        	#kill -s sigint "${BASHPID}"
	}

	## Define traps.
	trap '_fn-trap; kill -s INT "${BASHPID}"' "${scr_fnct_traps_1[@]}"
	#trap '_fn-trap; exit 0'                   "${scr_fnct_traps_2[@]}"

	## Alias: \_fn-trap\.
	#! Note, this alias lets \LINENO be expanded correctly.
	#grep -q expand_aliases <<< "${BASHOPTS}" || shopt -s expand_aliases

	#! Bug, with single quotes, this \LINENO expansion prints as
	#!   line number "1." I think I already figured out the fox
	#!   for this, in one of the debugging research scripts?
	#! Bug, however, with double quotes, xtrace prints this
	#!   alias expansion as
	#!	+ set -v
	#!	+ _fn-trap f

	#alias _fn-trap="_fn-trap '[line-number:${LINENO}]'"
		#! alias _fn-trap='_fn-trap '\''[line-number:349]'\'''
		#! + _fn-trap '[line-number:349]'

	#alias _fn-trap='_fn-trap [line-number:${LINENO}]'
		#! alias _fn-trap='_fn-trap [line-number:${LINENO}]'
		#! + _fn-trap f

	#alias _fn-trap='_fn-trap [line-number:"${LINENO}"]'
		#! alias _fn-trap='_fn-trap [line-number:"${LINENO}"]'
		#! + _fn-trap f

	#alias _fn-trap='_fn-trap line-number:${LINENO}'
		#! alias _fn-trap='_fn-trap line-number:${LINENO}'
		#! + _fn-trap line-number:1

	#alias _fn-trap="_fn-trap line-number:${LINENO}"
		#! alias _fn-trap='_fn-trap line-number:349'
		#! + _fn-trap line-number:349

	#alias _fn-trap="_fn-trap 'line-number:${LINENO}'"
		#! alias _fn-trap='_fn-trap '\''line-number:369'\'''
		#! + _fn-trap line-number:369

	#alias _fn-trap='_fn-trap "line-number:${LINENO}"'
		#! alias _fn-trap='_fn-trap "line-number:${LINENO}"'
		#! _fn-trap line-number:1

	#alias _fn-trap=': "line-number:${LINENO}"; _fn-trap'
		#! alias _fn-trap='_fn-trap "line-number:${LINENO}"'
		#! _fn-trap line-number:1

	#! Note, this command string works, but errexit isn\t involved.
	#alias _help-exit='_help-exit "[line-number:${LINENO}]"'

	#! Question: Post this question on help-bash?

	#! Note, it is not possible to get a line number from bash while
	#!   errexit is in effect for the line where the error occurred.
	#!   Using \trap\, if \false\ is executed, then, using an alias
	#!   to expand A.S.A.P. any string - which usually places \LINENO
	#!   into the correct context in the script - the line number that
	#!   is printed is "1," which is probably the LINENO for the
	#!   beginning of the command list executed from within \trap\.
	#! One option might be to use a purely functional programming
	#!   style, however, Bash really wasn\t designed with type of
	#!   use in mind.

		#alias
		#: "${Halt:?}" #<>
        	#set +x # <>
		#:;: "lineno: ${LINENO}";: #<>

	## Define temporary directory.
	#! Note, using a `foo=$( ... )` syntax for assigning \AA_rad was
	#!   causing errexit to halt the script with an exit code of
	#!   141 because "subshells from a command substitution unset
	#!   set -e." Hence the use of \read\.

	unset scr_tmpdr AA_rad
	unset r0 r1 r2 r3 r4 r5 wkgf
	unset r_str r_grep1 r_grep2 r_td r_hedc

	r0=${RANDOM}
	r1=$((  2**29  ))
	r2=$((  r0 + r1  ))
	r3=${PPID:-$((  r2  ))}
	r4=${BASHPID:-$((  r2 + 1  ))}
	r5=$((  r2 + 2  ))
	wkgf="${TMPDIR:-${HOME:-$PWD}}"/.rnd_${r3}-${r4}-${r5}.txt

		#set -x #<>
		#declare -p wkgf #<>
		set +x; printf '\n\t...\n\n' #<>

	## Gather some nearly actually random data.
	#! Note, 128 bits is the minimum, or read could error from
	#!   receiving fewer than 8 characters.
	dd bs=128 count=1 if=/dev/urandom of="${wkgf}" 2> /dev/null

		#ls -alFi "${wkgf}" #<>

	r_str=$( strings -n1 "${wkgf}" )
	"${scr_rm_cmd[@]:?}" -- "${wkgf:?}" || exit "${LINENO}"

	r_grep1=$( grep -vE "[[:punct:]]" <<< "${r_str}" )
	r_grep2=$( grep -oE "[[:alnum:]]" <<< "${r_grep1}" )
	r_td=$( tr -d "\n\t " <<< "${r_grep2}" )
	r_hedc=$( head -c 8 <<< "${r_td}" )
	read -rN8 -t1 AA_rad <<< "${r_hedc}"

		#: "r_td, length: ${#r_td}" #<>
		#: "${Halt:?}" #<>

	unset r0 r1 r2 r3 r4 r5 wkgf
	unset r_str r_grep1 r_grep2 r_td r_hedc

		#set -x #<>
		#declare -p AA_rad #<>

	scr_tmpdr="${TMPDIR:?}/.temp_${scr_name:?}_ran-${AA_rad:?}_pid-$$.d"
	export scr_tmpdr AA_rad
	readonly scr_tmpdr AA_rad

		#declare -p scr_tmpdr AA_rad #<>
		#declare -p opt_strings operands #<>
		#exit "${LINENO}" #<>

	## Create the temporary directory (used for "time file," etc.).
	mkdir "${scr_tmpdr}" || exit "${LINENO}"
fi
	#set -x #<>


:;:;: '## Enhancement Two: Semi-persistent Data File.';:

if 	[[ -n ${enable[2]:-} ]]
then
	## Define temporary data file.
	scr_tmpfl="${TMPDIR}/.bash_help_topics"
	export scr_tmpfl

	## Search for help_topics files.
	mapfile -d "" -t BB_ff < <(
		find "${scr_temp_dirs[@]}" -maxdepth 1 \
			"${scr_find_args[@]}" -type f \
			-name "*${scr_tmpfl##*/}*" -print0 2> /dev/null
	)
		#declare -p BB_ff #<>
		#: "${Halt:?}" #<>

	## Remove any out-of-date help topics files.
	if      ((  ${#BB_ff[@]} > 0  ))
	then
		: "true" #<>

		## Configurable validity time frame.
		BB_time=yesterday

			#BB_time="1 month ago" #<>
			#BB_time="@1721718000" #<>

		BB_file=${scr_tmpdr}/${BB_time}
		BB_date=$( date -d "${BB_time}" +%Y%m%d%H%M.%S )
		touch -mt "${BB_date}" "${BB_file}"

		## Begin a list of files to be removed.
		BB_list=( "${BB_file}" )

			#:;: #<>
			#stat "${BB_file}" #<>
			#: "${Halt:?}" #<>

		## For each found help topics file.
		for BB_XX in "${!BB_ff[@]}"
		do
			## If the file\s older than the time frame...
			if ! [[ ${BB_ff[BB_XX]} -nt "${BB_file}" ]]
			then
					:;: "older";: #<>

				## Add it to the removal list.
				BB_list+=("${BB_ff[BB_XX]}")
				unset "BB_ff[BB_XX]"

			else    : "false" #<>
			fi
		done

		## Delete each file on the list of out-of-date files to
		#+   be removed.
		"${scr_rm_cmd[@]}" -- "${BB_list[@]}" || exit "${LINENO}"

		unset BB_time BB_file BB_list

	else    : "false" #<>
	fi
		#:;: "number, BB_ff: ${#BB_ff[@]}" #<>

	## How many help topics files remain?
	if      ((  ${#BB_ff[@]} == 1  ))
	then
		: "true" #<>

		## If there\s just one, then use that one.
		scr_tmpfl="${BB_ff[*]}"

	else
		: "false" #<>

		## If multiple valid files remain, delete each of these
		#+   files in order to write a new one (below).

		## Test number of existing files.
		if      ((  ${#BB_ff[@]} > 1  ))
		then
			: "true" #<>

			"${scr_rm_cmd[@]}" -- "${BB_ff[@]}" || exit "${LINENO}"

		else    : "false" #<>
		fi

		#+ Add to listing array
		BB_ff+=( "${scr_tmpfl}" )
	fi
		#declare -p BB_ff #<>
		#: "${Halt:?}" #<>

	touch "${scr_tmpfl}"
fi
	#set -x #<>
	#:;: "lineno: ${LINENO}";: #<>


:;:;: '## Enhancement Three: Manually Identify Help Topics.';:

	enable -n compgen #<>

if 	[[ -n ${enable[3]:-} ]]
then
	:;: '## Is builtin \compgen\ available (it can be compiled out)?'
	if 	type -a compgen 2>&1 |
				grep -q " is a shell builtin"$
	then
		: "true" #<>

		## Then get the list of help topics.
		mapfile -t scr_all_topix < <(
			compgen -A helptopic )

	else
		: "false" #<>

		## If \compgen\ is NA, then get the current list of
		#+   help topics from builtin \help\ manually.


		:;: '## Are per-execution data directories in use?'
		if 	[[ -n ${enable[1]:-} ]]
		then
			: "true" #<>

			: '#+   Define function _tee as binary \tee\.'
			_tee ()
			{
				tee "$@" #2>&1 > /dev/null
			}
		else
			: "false" #<>

			: '#+   Define function _tee as binary \cat\.'
			_tee ()
			{
				cat "$@" > /dev/null
			}
		fi
			:;:;: #<>

		## Create a new data file.
		printf -v help_o00 '%s' "$(
			COLUMNS=256 \
        		builtin help |
                		_tee "${scr_tmpdr}"/00_help-as-is
		)"
			:;:;: #<>

		printf -v help_o10 '%s' "$(
			grep "^ " 2>&1 \
				<<< "${help_o00}" |
        			_tee "${scr_tmpdr}"/10_help-out
		)"

			:;:;: #<>

		printf -v help_o20 '%s' "$(
			cut -c -128 \
				<<< "${help_o10}" |
        			_tee "${scr_tmpdr}"/20_col-1
		)"

			:;:;: #<>

		printf -v help_o30 '%s' "$(
			cut -c 129- \
				<<< "${help_o10}" |
        			_tee "${scr_tmpdr}"/30_col-2
		)"

			:;:;: #<>

		## Remove spaces, fix problematic data and sort.
		printf -v help_o40 '%s' "$(
			printf '%s\n' "${help_o20}" "${help_o30}" |
				awk '{ $1 = $1; print }' |
        			_tee "${scr_tmpdr}"/40_col-all-trimmed
		)"

		# shellcheck disable=2001
		printf -v help_o50 '%s' "$(
			sed "s,^job_spec,%," <<< "${help_o40}" |
        			_tee "${scr_tmpdr}"/50_massaged

		)"

			:;:;: #<>

		printf -v help_o60 '%s' "$(
			sort -d \
        			<<< "${help_o50}" |
        			_tee "${scr_tmpdr}"/60_srtd
		)"

		## Get the list of \uniq -c\ counted unique fields at a
		#+   depth of x1 awk field.
		printf -v help_o70 '%s' "$(
			awk '{ print $1 }' <<< "${help_o60}" |
        			uniq -c |
        			sort -rn |
			       	_tee "${scr_tmpdr}"/70_f1-uniq-sort
		)"

			set -x #<>
			:;: "lineno: ${LINENO}";: #<>

			#:;: DEBUG 1;: #<>
			#printf '%s\n' "${help_o70}" #<>
			#:;: DEBUG 2;: #<>
			#head -v -n 200 "${scr_tmpdr}"/70_f1-uniq-sort #<>
			#:;: DEBUG 3;: #<>
			#: "${Halt:?}" #<>

			#declare -p help_o00 help_o10 help_o20 help_o30 #<>
			#declare -p help_o40 help_o50 help_o60 help_o70 #<>
			#ls -alhFi "${scr_tmpdr}" #<>
			#exit "${LINENO}" #<>

		## Get the list of counted multiple occurrances, ie, x3
		#+   occurrances of "foo", x2 occurrances of "bar", etc.
		mapfile -t help_o75 < <(
        		awk '{ printf "%d\n", $1 }' <<< "${help_o70}" |
                		sort -u |
				_tee "${scr_tmpdr}"/75_counts-occurrances
		)
			#declare -p help_o75 #<>
			#exit "${LINENO}" #<>

			:;: "lineno: ${LINENO}";: #<>


		## For loop
		#! Note, process from low to high values, ie, 1 then
		#+   2 then 3, etc.
		unset AA
		for     AA in "${help_o75[@]}"
		do
			## Get the list of unique initial substrings,
			#+   left to right.
        		if      ((  AA == 1  ))
        		then
                		: "true" #<>

                		## For a field depth of one, the command
				#+   is trivial.
				# shellcheck disable=SC2034
				mapfile -t help_o80_L1 < <(
					awk '{ print $1 }' \
						<<< "${help_o60}" |
                        		    uniq -c |
                        		    sort -n |
                        		    awk '$1 == "1" { print $2 }' |
					    _tee -a \
					        "${scr_tmpdr}"/80_L1-substr
				)
                			#declare -p help_o80_L1 #<>
					#: "${Halt:?}" #<>

				continue

        		else    : "false" #<>
        		fi

        		## For field depths greater than one.

			## Get the list of strings for which \uniq -c\
			#+   counted AA instances at field depth 1.
			#! Note, \-a\ option to \tee\ might be extra, in
			#!   both of these instances below.

				#declare -p AA #<>

        		mapfile -t "level_${AA}" < <(
                		awk -v aa="${AA}" \
				    -e '$1 == aa { printf "%s\n", $2 }' \
				    <<< "${help_o70}" |
				_tee -a "${scr_tmpdr}/77_f1-substr-L${AA}"
        		)

				#<> Print array \level_2
				declare -p "level_${AA}" #<>
				#: "${Halt:?}"
				:;: "lineno: ${LINENO}";: #<>

        		## Nameref for array
        		unset -n array_nameref
        		declare -n array_nameref
        		array_nameref="level_${AA}"

				#declare -p array_nameref  #<>
				#: "${Halt:?}" #<>

        		## Build awk program
        		# shellcheck disable=SC2016
        		mapfile -d " " -t awk_prg < <(
				{
					printf '$1 == xx { print'
                			printf ' $%s ' $( seq 1 "${AA}" ) |
                        			sed "s/  /, /g"
                			printf "}"
				} |
					_tee -a \
					  "${scr_tmpdr}/78_awk_L${AA}"
        		)
				declare -p awk_prg #<>
				#: "${Halt:?}" #<>
				:;: "lineno: ${LINENO}";: #<>

        		##
        		unset XX
        		for XX in "${array_nameref[@]}"
        		do
					declare -p XX #<>
					#: "${Halt:?}" #<>

                		## Execute awk program and sed
				sed_prg='s/([A-Z]{3,}|[A-Za-z]{3,}$).*//g'
					#declare -p sed_prg #<>

				mapfile -t "help_o80_L${AA}" < <(
				  awk -v xx="${XX}" "${awk_prg[*]}" \
				      <<< "${help_o60}" |
                        	    sed -E "${sed_prg}" |
                        	    awk '{ $1 = $1 ; print }' |
                            	      _tee "${scr_tmpdr}/80_L${AA}"-substr
				)
        		done
                            	declare -p "help_o80_L${AA}"
				ls -alhFi "${scr_tmpdr}/80_L${AA}"-s* #<>
                            	head -vn99 "${scr_tmpdr}/80_L${AA}"-s* #<>
				#: "${Halt:?}" #<>
				:;: "lineno: ${LINENO}";: #<>
		## End for loop
		done
		unset AA XX
			#: "${Halt:?}" #<>

		## COMMENT

			#! Bug, this expansion prints strnagely in xtrace.
			#!   + : 'help_o80_L*, PE: help_o80_L1' help_o80_L2
			: "help_o80_L*, PE: ${!help_o80_L@}" #<> KEEP

		o80_arrays=( "${!help_o80_L@}" )

			declare -p o80_arrays
			#: "${Halt:?}" #<>

		#mapfile -O 1 -t scr_all_topix < <(
				for VV in "${!o80_arrays[@]}"
				do
					declare -p VV #<>
					declare -p "${o80_arrays[VV]}" #<>
					: "${Halt:?}" #<>

			# AJAX :: depend on function _tee
					printf '%s\n' "${o80_arrays[VV]}"
				done
		#)
			#{
			#} |
				#sort -d |
        			  #_tee -a "${scr_tmpdr}/90_all-substrings"

        		declare -p scr_all_topix #<>
			ls -alFi "${scr_tmpdr}/90_all-substrings"
			head -vn99 "${scr_tmpdr}/90_all-substrings"
			: "${Halt:?}" #<>
	fi
		set -x #<>
		:;: "lineno: ${LINENO}";: #<>

	:;: '## If a semi-persistent data file is available, then use it.'
	if 	[[ -f "${scr_tmpfl}" ]]
	then
		printf '%s\n' "${scr_all_topix[@]}" > "${scr_tmpfl}"
	fi
fi
	echo "LINENO: ${LINENO}" #<>
	#false #<>

exit 00
