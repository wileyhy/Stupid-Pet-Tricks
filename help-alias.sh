#!/bin/bash
#!
#! Version 1.0
#!
#!   A re-implementation of `help -s`, `apropos` for bash's help builtin,
#! written in bash 5.2.
#!
#!   There is an additional option added: '-l', for listing help topics.
#! Lists can be printed vertically ('-l','-lv') or horizontally ('-lh').
#!
#!   Where bash's `help` builtin performs bash's internal Pattern Matching
#! syntax, this script accepts awk regular expressions. This difference
#! in functionality was an accidental design flaw in this script.
#!
#!   SPDX-FileCopyrightText: 2024 Wiley Young
#!   SPDX-License-Identifier: GPL-3.0-or-later
#!
#    shellcheck disable=SC2059,SC2317

	#set -x #<>



:;: '#########  Section A  ######### '

:;: '## Variables, etc.'
#! Note, \:\ (colon) commands are Thompson-style comments.

script_name="help-alias.sh"
set -euo pipefail
shopt -s checkwinsize


:;: '## \COLUMNS has been inconsistently inherited from parent processes.'

LC_ALL=C
if 	[[ -z ${COLUMNS:=} ]]
then
	:;: "true" #<>
	COLUMNS=$(
		stty -a |
			tr ';' '\n' |
			awk '$1 ~ /columns/ { print $2 }'
	)
else	:;: "false" #<>
fi
export COLUMNS


:;: '## Executable \find\ should only return items that \USER can r/w/x.'
#! Note, make sure these options can only be changed one place.

script_find_args=( '(' -user "$UID" -o -group "$(id -g)" ')' )


:;: '## Define this rm command in just one place, to avoid any '
: '#+   inconsistencies.'

script_rm_cmd=( rm --one-file-system --preserve-root=all -f )


:;: '## Define TMPDIR.'
#! Note, defining directories with a trailing forward slash will effect
#!   whether \[[\, \test\, \[\ and \stat\ dereference symlinks. However,
#!   \realpath -e\ will still resolve such strings correctly.


:;: '## From a list of possible values of TMPDIR, ordered by preference...'
#! Note, this list will be used later as search paths for \find\

AA_UU=(/tmp /var/tmp /usr/tmp /usr/local/tmp "$HOME/tmp" /dev/shm "$HOME")


:;: '## From this list, above, generate a list of known temporary '
: '#+   directories.'
#! Note, Using the ':?' parameter expansion on an undefined variable 
#!   triggers the EXIT trap. If the EXIT trap isn't caught and handled,
#!   ie, with `trap`, then using ':?' will halt the script.  Hence
#!   the use of `: "${Halt:?}" throughout the script.
#! Note, the syntax, '<>', is a local convention which indicates that 
#!   commands on that line are for debugging. This practice makes it 
#!   easier to remove all of the debugging commands at once with a 
#!   simple grep. The symbols appear in comments sometimes or usually 
#!   at the ends of lines.

	#<>
	#declare -p AA_UU #<>

for 	AA_WW in "${AA_UU[@]}"
do

	:;: '## Get a reliable absolute path.'

	if 	AA_VV=$( realpath -e "${AA_WW}" 2>/dev/null )
	then

		:;: '## If the output of \realpath\ is a writeable '
		: '#+   directory and not a symlink.'
		#! Note, for a Thompson comment within an if-fi 
		#!   structure to print correctly when xtrace is 
		#!   enabled, the comment must be included within 
		#!   the \then\, \else\, etc. blocks, ie., after
		#!   the keywords and not before them as with regular
		#!   hashtag-style Bourne comments.

		if	[[ -n ${AA_VV} ]] &&
			[[ -d ${AA_VV} ]] &&
			[[ -w ${AA_VV} ]] &&
			! [[ -h ${AA_VV} ]]
		then

			:;: '## Begin by assuming all values will be '
			: '#+   added.'

			AA_ZZ=yes

			for 	AA_TT in "${script_temp_dirs[@]}"
			do

				:;: '## Does the new directory match an '
				: '#+   existing directory?'

				if 	[[ ${AA_VV} == "${AA_TT}" ]]
				then

					:;: '## If yes, do not add that '
					: '#+   value.'

					AA_ZZ=no
				else

					:;: '## If no, keep iterating.'

					continue
				fi
			done


			:;: '## If the entire list has iterated without '
			: '#+   finding a match, then add it to the list.'

			if 	[[ ${AA_ZZ} == yes ]]
			then
				script_temp_dirs+=( "${AA_VV}" )
			fi
		fi
	fi
done
unset AA_TT AA_UU AA_VV AA_WW AA_ZZ

	#<> Debugging commands
	#declare -p script_temp_dirs #<>
	#: "${Halt:?}" #<>


:;: '## Finally define TMPDIR.'

if	[[ ${#script_temp_dirs[@]} -ne 0 ]]
then
	TMPDIR="${TMPDIR:="${script_temp_dirs[0]}"}"
else
	echo Error
	exit "$LINENO"
fi

	#declare -p TMPDIR #<>
	#: "${Halt:?}" #<>
	#set -x # <>


:;: '## Define temporary directory.'
#! Note, format serves as a positive lock mechanism

#! Bug? this lock string is too complicated. Re-write it
#!   based on /dev/urandom?

AA_hash=$(
	date |
		sum |
		tr -d ' \t'
)
script_tmpdr="${TMPDIR}/.temp_${script_name}_hash-${AA_hash}_pid-$$.d"
declare -rx script_tmpdr AA_hash


:;: '## Create the temporary directory (used for "time file," etc.).'

mkdir "$script_tmpdr" ||
	exit "$LINENO"


:;: '## Define temporary data file.'

script_tmpfl="$TMPDIR/.bash_help_topics"


:;: '## Define groups of traps to be caught and handled.'

script_traps_1=( SIG{INT,QUIT,STOP,TERM,USR{1,2}} )
script_traps_2=( EXIT )


:;: '## Define \function_trap()\.'
#! Note, defining functions is not visible in xtrace.

function_trap()
{
	#local -; set -x #<>


	:;: '## Reset traps.'

	trap - "${script_traps_1[@]}" "${script_traps_2[@]}"


	:;: '## Remove any & all leftover temporary directories.'

	local -a TR_list

		#declare -p AA_UU script_find_args #<>
		#declare -p script_name #<>


	:;: '## Get a list of directories.'

	mapfile -d "" -t TR_list < <(
		find "${script_temp_dirs[@]}" "${script_find_args[@]}" \
			-type d -name '*temp_'"${script_name}"'_*.d' \
			-print0 2>/dev/null
	)

		#: "${Halt:?}" #<>
		#declare -p TR_list #<>


	:;: '## If any are found...'

	if 	(( "${#TR_list[@]}" > 0 ))
	then

		:;: '## For each directory name.'

		local TR_XX TR_YY

		for TR_XX in "${TR_list[@]}"
		do

			:;: '## If the directory is clearly from this '
			: '#+   run of this script, then delete the '
			: '#+   directory.'

			if 	grep -qe "${script_tmpdr}" \
					-e "hash-${AA_hash}" \
					<<< "${TR_XX}"
			then
				"${script_rm_cmd[@]}" -r -- "${TR_XX}" ||
					exit "${LINENO}"
				continue

			elif

				:;: '## If the directory is clearly a '
				: '#+   previous run of this script, then '
				: '#+   delete the directory.'

				grep -qE 'hash-[0-9]{5,7}_pid-[0-9]{3,9}' \
					<<< "${TR_XX}"
			then
				"${script_rm_cmd[@]}" -r -- "${TR_XX}" ||
					exit "${LINENO}"
				continue

			elif

				:;: '## Get a certain substring if it '
				: '#+   exists.'
				#! Note, of the shell that invoked \mkdir\.

				TR_YY=${TR_XX#*_}
				TR_YY=${TR_YY%.d}
				TR_YY=${TR_YY#*_pid-}


				:;: '## If the substring TR_YY could '
				: '#+   be a PID.'

				[[ -n ${TR_YY} ]] &&
				[[ ${TR_YY} == [0-9]* ]] &&
				(( TR_YY > 300 )) &&
				(( TR_YY < 2**22 ))
			then

				:;: '## Then delete the directory.'

				"${script_rm_cmd[@]}" -r -- "${TR_XX}" ||
					exit "${LINENO}"
				continue

			else

				:;: '## Otherwise, ask the user.'

				printf '\nThis other directory was found:'
				printf '\n\t%s\n' "${TR_XX}"
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


:;: '## Define traps.'

trap 'function_trap; kill -s SIGINT $$' "${script_traps_1[@]}"
#trap 'function_trap; exit 0' 		"${script_traps_2[@]}"

	#kill -s sigint "$$" #<>
	set -x # <>


:;: '## Identify / define script input.'

if 	(( $# > 0 ))
then
	:;: "true" #<>

	script_strings=("$@")

else	:;: "false" #<>

	script_strings=(echo builtin type info ls man which) #<>
fi
export script_strings


	#! Bug, \compgen\ can be compiled out of bash, so you cannot
	#!   depend on its availability.


:;: '## Get the current list of help topics from bash.'

	##! Note, \sort -u\ removes lines from output of \compgen\ in
	##!   this case.
	#mapfile -t script_all_topix < <(
		#compgen -A helptopic |
			#sort -d
	#)
	#export script_all_topix


:;: '## Create a new data file.'
#! Note, integers 128 and 129 are indeed correct. Setting
#!   \COLUMNS to 512 doesn\t help.

COLUMNS=256 builtin help |
	grep '^ ' > "$script_tmpdr/10_help-out"

#! Bug, some of the help strings are longer than 128c.
#!   It would be necc to loop over \builtin help STRING\
#!   and append to an output file in order to gather all
#!   of the available information.

cut -c -128 "$script_tmpdr/10_help-out"	> "$script_tmpdr/20_col-1"
cut -c 129- "$script_tmpdr/10_help-out" > "$script_tmpdr/30_col-2"


:;: '## Sort into dictionary order.'

sort -d "$script_tmpdr/20_col-1" "$script_tmpdr/30_col-2" \
	> "$script_tmpdr/40_col-all"


:;: '## Remove leading and trailing spaces.'

awk '{ $1 = $1; print }' < "$script_tmpdr/40_col-all" \
	> "$script_tmpdr/50_trimmed"

	ls -alhFi "$script_tmpdr/50_trimmed" #<>



:;: '## Get the full list of help topics. ...somehow....'
#! Note, in a loop, measure the number of duplicate leading
#!   substrings in the output of \builtin help\ by counting
#!   the number unique lines that print when a reducing number
#!   of record fields are printed.


:;: '## Get the total number of records.'

BB_line_count_all=$( wc -l < "$script_tmpdr/50_trimmed" )

	#<> Alternate cmd
	#awk 'END { print NR }' #<>


:;: '## Get the total number of horizontal (awk) fields from '
: '#+   among all records.'

BB_field_count_all=$(
	awk '{ if (NF > max) max = NF } END { print max }' \
		"$script_tmpdr/50_trimmed"
)

	set -x # <>


:;: '## Define a function for a frequently used set of commands.'

unset -f _get_uniq_c
_get_uniq_c(){
	awk "$*" "$script_tmpdr/50_trimmed" |
		uniq -c
}

	#declare -F _get_uniq_c #<>


:;: '## Loop: find any duplicated leading substrings from output of '
: '#+   \help\. Beginning with the maximum number of (awk) fields from '
: '#+   among all records...'

for 	(( BB_MW=BB_field_count_all; BB_MW >= 0 ; BB_MW-- ))
do
	#! Note, I prefer to avoid using bash\s Field
	#!   Splitting facilities whenever possible: hence
	#!   the array \numbs.

		:;: "BB_MW: $BB_MW" #<>


	:;: '## Get an index number for each field to be referenced in '
	: '#+   this iteration of this for loop.'

	numbs=()
	mapfile -O 1 -t numbs < <(
		seq 1 "$BB_MW"
	)

		:;: "count, numbs: ${#numbs[@]}" #<>


	:;: '## Does variable \awk_prog_str must have a non-zero length?'

	if	[[ -n ${awk_prog_str[*]:0:8} ]]
	then
		:;: "true" #<>

		:;: '## If so, then define variable \prev_awk_prg_str.'

		prev_awk_prg_str=( "${awk_prog_str[@]}" )

	else 	:;: "false" #<>
	fi


	:;: '## (Re-)define variable \awk_prog_str.'
	#! Note, In this block, an awk program is built character
	#!   by character and saved as an (bash) indexed array, using
	#!   the array of indices, \numbs, as it is defined in this
	#!   iteration of thios for loop, above. The purpose is to print
	#!   a diminishing number of (awk) record fields per each
	#!   iteration of the (bash) loop.

	unset awk_prog_str
	mapfile -d ' ' -t awk_prog_str < <(
		printf '{ print'
		printf ' $%d ' "${numbs[@]}" |
			sed 's/  /, /g'
		printf '}'
	)

		#<>
		:;: "begin, awk_prog_str:   <${awk_prog_str[0]}" \
			"${awk_prog_str[1]} ${awk_prog_str[2]}>" #<>
		:;: "end, awk_prog_str:   <${awk_prog_str[-3]}" \
			"${awk_prog_str[-2]} ${awk_prog_str[-1]}>" #<>


	:;: '## Get the number of records that print when the '
	: '#+   current number \BB_MW of fields is printed.'
	#! Note, do this by creating an indirect scalar parameter,
	#!   \BB_line_count_[0-9]{1,2}. Reference that parameter
	#!   using a nameref variable, \lines. Define \lines by using
	#!   the combination of two tools constructed above, namely,
	#!   the function \_get_uniq_c()\ and the indexed array
	#!   \awk_prog_str, which is input for said function. The
	#!   function will execute the (awk) program from the function\s
	#!   STDIN, ie, the function\s positional parameters, and awk
	#!   will process a hard-coded file, named above. The function
	#!   produces output from `uniq -c`. This means that, for any
	#!   number of fields printed, 20, 19, 18, etc., that, if
	#!   `uniq -c` finds any duplicate truncated lines, then
	#!   the line count of output from `uniq -c` will decrease,
	#!   which would indicate the presence of fully or partially
	#!   duplicated (awk) records, which are actually lines of
	#!   output from `builtin help`.

	unset lines
	declare -n lines="BB_line_count_${BB_MW}"
	printf -v "lines" '%d' "$(
		_get_uniq_c "${awk_prog_str[*]}" |
			wc -l
	)"

		:;: "lines: $lines" #<>


	:;: '## Is the number of lines not equal to the full file\s '
	: '#+   total line count?'

	if 	(( lines != BB_line_count_all ))
	then
		:;: 'True.' #<>

		:;: '## If so, then break out of this loop.'

		break

	else	:;: 'False.' #<>
		:;: '## Otherwise, go to the next iteration.' #<>
	fi

done

	:;:;: #<>
	#declare -p BB_line_count_all BB_MW numbs #<>
	#declare -p awk_prog_str prev_awk_prg_str #<>
	#declare -f _get_uniq_c #<>
	#declare -p lines #<>
	#echo "lines: $lines" #<>
	#: "${Halt:?}" #<>

#! Note, the '== "2"' awk string constant below is dependent
#!   upon the number of records that were printing at the most
#!   recent iteration where BB_line_count_?? waas equivalent
#!   to BB_line_count_all. Similarly with the '== "1"' awk
#!   string constant farther below, since each iteration of
#!   the (pending future) loop decrements the field count by
#!   just 1.


:;: '## There could be multiple records where the 1st field has '
: '#+   some duplicates, so use an array. Also, remove any '
: '#+   leading or trailing whitespace.'

_get_uniq_c "${awk_prog_str[*]}" |
	awk '{ $1 = $1; print }' > "$script_tmpdr/60_uniq-c"

	#less "$script_tmpdr/60_uniq-c" #<>
	#: "${Halt:?}" #<>

unset dup_strs #<>
mapfile -t dup_strs < <(
	awk -v bb_wm=$((BB_MW + 1)) \
		'$1 == bb_wm { print $2 }' \
		"$script_tmpdr/60_uniq-c"
)

	declare -p dup_strs
	#: "${Halt:?}" #<>

#! Note, this \awk | uniq -c\ sub-pipeline above is the same
#!   compound (sub-)command as at BB_line_count_1 above, as
#!   well as at the "print records of 1 fields\ length"
#!   comment below. Possibly the data should be stored in a
#!   separate array (in bash), which is as yet unwritten.


:;: '## Iterate through array of strings which have duplicates '
: '#+   at field depth \BB_MW.'

for XX in "${dup_strs[@]}"
do
	#! Note, The input file for this awk command should
	#!   be "50_trimmed" - confirmed.


	:;: '## Print records of \BB_MW + 1\ fields\ record '
	: '#+   length into new file.'

	awk -v xx="@/^${XX}$/" \
		"\$1 ~ xx ${prev_awk_prg_str[*]}" \
		"$script_tmpdr/50_trimmed" \
		> "$script_tmpdr/70_unique-strings"
done

	head "$script_tmpdr/70_unique-strings" #<>
	#: "${Halt:?}" #<>
	#declare -p prev_awk_prg_str script_tmpdr BB_MW #<>

#! Note, still use the \prev_awk_prg_str array. Even though
#!   the information sought is from one less field level,
#!   \uniq -c\ prepends a field to each record.


:;: '## Print records of \BB_MW fields\ length and append to file.'

awk -v bb_wx="@/^${BB_MW}$/" '$1 ~ bb_wx {print $2}' \
	"$script_tmpdr/60_uniq-c" \
	>> "$script_tmpdr/70_unique-strings"

	#head "$script_tmpdr/70_unique-strings" #<>
	#: "${Halt:?}" #<>

#! Note, in theory, the current field depth could be 3 or 4,
#!   and there could be lower levels o dups which this script,
#!   in its current state, would fail to process correctly.


:;: '## Massage some problematic data.'

sed 's,job_spec,%,' "$script_tmpdr/70_unique-strings" \
	> "$script_tmpdr/80_massaged"


:;: '## Sort new file.'

sort "$script_tmpdr/80_massaged" \
	> "$script_tmpdr/90_sort"


:;: '## Remove all capitalized words.'

sed 's/\<[[:upper:]]\{2,\}\>//g' "$script_tmpdr/90_sort" \
	> "$script_tmpdr/100_no-cap-words"


:;: '## Remove leading and trailing whitespace.'

awk '{ $1 = $1; print }' "$script_tmpdr/100_no-cap-words" \
	> "$script_tmpdr/110_no-spaces"

	#: "${Halt:?}" #<>


:;: '## Write a somewhat durable file.'

cp -a "$script_tmpdr/110_no-spaces" "$script_tmpfl"

	#declare -p script_strings #<>
	set -x #<>
	: "${Halt:?}"




:;: '## Match for an option flag: '
: '#+   \-s\   			-- Section B '
: '#+   \-l*\  			-- Section C '
: '#+   Neither \-s\ nor \-l*\	-- Section D '

if 	[[ ${script_strings[0]:-""} = "-s" ]]
then

	:;: '#########  Section B  ######### '

	:;: '## List short descriptions of specified builtins.'
	:;: '## Remove \-s\ from the array of \script_strings.'

	unset "script_strings[0]"
	script_strings=("${script_strings[@]}")


	:;: '## Search for help_topics files.'

	mapfile -d "" -t BB_htopx_files < <(
		find "${script_temp_dirs[@]}" -maxdepth 1 \
			"${script_find_args[@]}" -type f \
			-name "*${script_tmpfl##*/}*" -print0 2>/dev/null
	)

		#declare -p BB_htopx_files
		#: "${Halt:?}"


	:;: '## Remove any out of date help topics files.'

	if 	(( ${#BB_htopx_files[@]} > 0 ))
	then
		:;: 'True.' #<>

		:;: '## Configurable validity time frame.'
		#! Note, validity of any help topics file should be a
                #!   configurable time period, and should be an operand
		#!   to \date -d\.

		BB_time="yesterday"

			#BB_time="last year" #<>
                	#BB_time="2 fortnights ago" #<>
                	#BB_time="1 month ago" #<>
                	#BB_time="@1721718000" #<>
                	#BB_time="-2 fortnights ago" #<>

		BB_file="${script_tmpdr}/${BB_time}"
		touch -mt "$( date -d "${BB_time}" +%Y%m%d%H%M.%S )" \
			"${BB_file}"


		:;: '## Begin a list of files to be removed.'

		BB_list=( "$BB_file" )

			#:;: #<>
			#stat "$BB_file" #<>
			#: "${Halt:?}" #<>


		:;: '## For each found help topics file.'
		#! Note, unset each deleted file so that \case\ statement
		#!   below is accurate

		for BB_XX in "${!BB_htopx_files[@]}"
		do

			:;: '## If the file\s older than the time frame...'

			if ! [[ ${BB_htopx_files[BB_XX]} -nt "$BB_file" ]]
			then

					:;: "older";: #<>

				:;: '## Add it to the removal list.'

				BB_list+=("${BB_htopx_files[BB_XX]}")
				unset "BB_htopx_files[BB_XX]"

			else 	:;: "false" #<>
			fi
		done


		:;: '## Delete each file on the list of files to '
		: '#+   be removed.'

		"${script_rm_cmd[@]}" -- "${BB_list[@]}" ||
			exit "${LINENO}"

		unset BB_time BB_file BB_list

	else 	:;: 'False.' #<>
	fi

		:;: "number, BB_htopx_files: ${#BB_htopx_files[@]}" #<>


	:;: '## How many help topics files remain?'

	if 	(( ${#BB_htopx_files[@]} == 1 ))
	then
		:;: 'True.' #<>

		:;: '## One file exists.'

		script_tmpfl="${BB_htopx_files[*]}"

	else
		:;: 'False.' #<>
		:;: '## If multiple files exist, delete them.'

		:;: '## Test number of existing files.'

		if 	(( ${#BB_htopx_files[@]} > 1 ))
		then
			:;: 'True.' #<>

			"${script_rm_cmd[@]}" -- "${BB_htopx_files[@]}" ||
				exit "${LINENO}"
		else	:;: 'False.' #<>
		fi

#:;: start
#! Note, this is where in this script the tempfile was previously created.
#:;: end

		#+ Add to listing array

		BB_htopx_files+=( "$script_tmpfl" )
	fi

		declare -p BB_htopx_files #<>
		: "${Halt:?}" #<>


	:;: '## Print info from the topics file and exit.'
	#! Note, using awk regex rather than bash\s pattern matching
	#!   syntax.

	if 	(( ${#script_strings[@]} == 0 ))
	then
		more -e "$script_tmpfl"
	else

		#! Bug, this section had read from \script_tmpfl, in
		#!   order to show full usage descriptions.


		:;: '## If the string appears in the first column or '
		: '#+   at the beginning of \script_tmpfl, then print '
		: '#+   that line.'

			#set -x # <>
			#declare -p script_strings #<>

		#! Bug, if the search string is NA in the topics file, then
		#!   there s/b a 'NA' message output from the \help\ builtin

		for BB_YY in "${script_strings[@]}"
		do

		    	if [[ $BB_YY == @($|%|^|\(|\(\(|.|\[|\[\[|\{|\\|\|) ]]
			then
				#! Note, bash parameter expansions do
				#!   not support sed\s \&\ back references
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

				#! Note, '||:' below is there because of
				#!   errexit
				#! Note, deleted: case/esac with hex codes
				#!   of ASCII chars

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

	:;: '#########  Section C  ######### '

	:;: '## Additional option: \-l\ for \list;\ \-lh\ and \-lv\ '
	: '#+   for horizontal and vertical lists, respectively. '
	: '#+   Defaults to vertical.'

	unset "script_strings[0]"
	script_strings=("${script_strings[@]}")


	:;: '## Initialize to zero...'
	: '#+   ...Carriage Return Index.'

	cr_indx=0

	: '#+   ...Topic Index.'

	tpc_indx=0


	:;: '## Posparm \2 can be a filter. If empty, let it be any char.'

	if 	[[ -z ${script_strings[1]:-} ]]
	then
		set -- "${script_strings[0]:=}" '.*'
	fi

	#! Bug, reduce the length of the list according to 
	#!   posparms, eg, \ex\ or \sh\.


	:;: '## Get total Number of Help Topics for this run of this '
	: '#+   script.'

	ht_count=${#script_all_topix[@]}


	:;: '## Define Maximum String Length of Topics.'

	strlen=$(
		printf '%s\n' "${script_all_topix[@]}" |
			awk '{if (x < length($0)) x = length($0)}
					END {print x}'
	)


	:;: '## Define Column Width.'

	col_width=$(( strlen + 3 ))
	printf_format_string=$(
		printf '%%-%ds' "${col_width}"
	)


	:;: '## Define maximum and total numbers of columns.'

	max_columns=$(( ${COLUMNS:-80} / col_width ))
	all_columns=$max_columns

	if 	(( max_columns > ht_count ))
	then
		:;: "true" #<>

		all_columns=$ht_count

	else	:;: "false" #<>
	fi


	:;: '## Print a list.'

	if 	[[ ${script_strings[0]} = "-lh" ]]
	then

		:;: '## Print a list favoring a horizontal sequence.'

		:;: '## For each index of the list of topics.'

		for tpc_indx in "${!script_all_topix[@]}"
		do
			:;: '## If the ...'

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

		:;: '## Print a list favoring a vertical sequence.'

		:;: '## Get the Number of Full Rows.'

		full_rows=$(( ht_count / all_columns ))


		:;: '## Get the number of topics in any partial row (modulo).'

		row_rem=$(( ht_count % all_columns ))


		:;: '## Record whether there is a Partial Row.'

		part_rows=0

		if	(( row_rem > 0 ))
		then
			:;: "true" #<>

			part_rows=1

		else	:;: "false" #<>
		fi


		:;: '## Get the total number of Rows.'

		all_rows=$(( full_rows + part_rows ))

		mapfile -d "" -t list_of_rows < <(
			CC_UU=$(( all_rows - 1 ))
			for 	(( CC_WW=0 ; CC_WW <= CC_UU ; ++CC_WW ))
			do
				printf '%s\0' "__row__${CC_WW}"
			done
			unset CC_UU
		)
		unset "${list_of_rows[@]}" CC_WW

			#declare -a "${list_of_rows[@]}" #<>

		CC_VV=$((${#script_all_topix[@]}-1))
		CC_XX=0

		for 	(( CC_YY=0; CC_YY <= CC_VV; ++CC_YY ))
		do
			printf -v "__row__${CC_XX}[${cr_indx}]" '%s' \
				"${script_all_topix[CC_YY]}"

			if 	(( CC_XX == $(( all_rows - 1 )) ))
			then
				CC_XX=0
				(( ++cr_indx ))
			else
				(( ++CC_XX ))
			fi
		done
		unset CC_VV CC_XX CC_YY

		function_print_elements()
		{
			local -a elements
			local -n array_name="$1"

			mapfile -d "" -t elements < <(
				printf '%s\0' "${array_name[@]}"
			)

				#declare -p elements #<>

			printf "$printf_format_string" "${elements[@]}"
			echo
		}

		#mapfile -t list_of_rows < <(
			#sort -hn

		for CC_ZZ in "${list_of_rows[@]}"
		do
			function_print_elements "$CC_ZZ"
		done
		unset CC_ZZ
	fi



else

	:;: '#########  Section D  ######### '

	:;: '##   If the script\s first operand is neither a \-s\ nor a '
	: '#+   \-l*\.'

		#set -x # <>


	:;: '## If the number of strings is greater than zero.'

	if 	(( ${#script_strings[@]} > 0 ))
	then

		for DD_XX in "${!script_strings[@]}"
		do
			grep_args+=("-e" "${script_strings[DD_XX]}")
		done
		unset DD_XX

		mapfile -d "" -t sublist_topics < <(
			for DD_YY in "${script_all_topix[@]}"
			do

				#! Note, '||:' below is there because of
				#!   errexit

				grep -F "${grep_args[@]}" <<< "$DD_YY" ||:
			done |
				tr '\n' '\0'
		)
		unset DD_YY

			#declare -p sublist_topics #<>
			#exit 101 #<>

		for DD_ZZ in "${!sublist_topics[@]}"
		do
			if 	(( "${#sublist_topics[@]}" > 1 ))
			then
				printf '######### %d of %d #########\n' \
					$(( DD_ZZ + 1 )) \
					"${#sublist_topics[@]}"
			fi
			builtin help "${sublist_topics[DD_ZZ]}"
			printf '\n'
		done |
			more -e
		unset DD_ZZ
	else
		builtin help |
			more -e
	fi
fi

exit 00
