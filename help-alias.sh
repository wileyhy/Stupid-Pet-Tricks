#!/bin/bash
#!
#! Version 1.1
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

	#set -x # <>



:;: '#########  Section A  ######### '

:;: '## Variables, etc.'
#! Note, \:\ (colon) commands are Thompson-style comments; they\re
#!   readable in xtrace output.
#! Note, whitespace is removed from the variable \script_name
#! Note, \set -e\, a.k.a. errexit, is _In_-_Sane_! To wit:
#!     https://mywiki.wooledge.org/BashFAQ/105
#!   But, people use it, and some unfortunate souls could even require
#!   its use, sadly enough.

script_name="help-alias.sh"
script_name=${script_name//[$'\t\n ']/}
set -e # BAD
set -u
set -o pipefail
shopt -s checkwinsize


:;: '## \COLUMNS has been inconsistently inherited from parent processes.'

LC_ALL=C
export LC_ALL

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


:;: '## Identify / define script input.'
#! Note, for debugging, if there aren\t any positional parameters,
#!   then create some.

if 	(( $# > 0 ))
then
	:;: "true" #<>

	script_strings=("$@")

else	:;: "false" #<>

	script_strings=(echo builtin type info ls man which) #<>
fi
export script_strings


:;: '## Executable \find\ should only return items that \USER can r/w/x.'
#! Note, make sure these options can only be changed one place.

script_find_args=( '(' -user "$UID" -o -group "$(id -g)" ')' )


:;: '## Define one consistent \rm\ command.'

script_rm_cmd=( rm --one-file-system --preserve-root=all --force
	--verbose )


:;: '## Define TMPDIR.'
#! Note, defining directories with a trailing forward slash will effect
#!   whether \[[\, \test\, \[\ and \stat\ dereference symlinks. However,
#!   \realpath -e\ will still resolve such strings correctly.


:;: '## From a list of possible values of TMPDIR, ordered by preference...'
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

	#declare -p AA_UU #<>
	#set -x # <>

for 	AA_WW in "${!AA_UU[@]}"
do
	:;: '## Begin major loop: Get a reliable absolute path.'
	#! Note, if \realpath\ returns with an output of zero length,
	#!   then the assignment to \AA_VV will fail and, since this
	#!   if-fi structure spans the entire for loop, the loop's
	#!   next iteration will begin.

	if 	AA_VV=$( realpath -e "${AA_UU[AA_WW]}" 2> /dev/null )
	then
		: "true" #<>

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


			:;: '## Begin minor loop, over the new list'
			#! Note, if an element from the prior list is
			#!   absent from the new list, then add that
			#!   element to the new list.

			for 	AA_TT in "${script_temp_dirs[@]}"
			do

				:;: '## Does the new directory match an '
				: '#+   existing directory?'

				if 	[[ ${AA_VV} == "${AA_TT}" ]]
				then

					:;: '## If yes, do not add that '
					: '#+   value, and end the minor '
					: '#+   loop.'

					AA_ZZ=no
					break
				else

					:;: '## If no, begin the next '
					: '#+   iteration of the minor '
					: '#+   loop.'

					continue
				fi
			done

			:;: '## End minor loop.'


			:;: '## If the entire list has iterated without '
			: '#+   finding a match, then add it to the list.'

			if 	[[ ${AA_ZZ} == yes ]]
			then
				script_temp_dirs+=( "${AA_VV}" )
			fi
		fi

	else
		: "false" #<>

		:;: '## If \realpath\ returns a zero length string, '
		: '#+   then unset the current index \AA_WW.'

		unset 'AA_UU[AA_WW]'
		continue
	fi
done

:;: '## End major loop.'
unset AA_TT AA_UU AA_VV AA_WW AA_ZZ

	#<> Debugging commands
	#declare -p script_temp_dirs #<>
	#: "${Halt:?}" #<>
	#set -x # <>


:;: '## Finally define TMPDIR.'

if	[[ ${#script_temp_dirs[@]} -ne 0 ]]
then
	TMPDIR="${TMPDIR:="${script_temp_dirs[0]}"}"
	declare -rx TMPDIR
else
	echo Error
	exit "$LINENO"
fi

	#declare -p TMPDIR #<>
	#: "${Halt:?}" #<>
	#set -x # <>


:;: '## Define temporary directory.'
#! Note, format of name of temporary directory serves as a
#!   probable per-execution identifier.
#! Note, using a `foo=$( ... )` syntax for assigning \AA_rand was
#!   causing errexit to halt the script with an exit code of
#!   141 because "subshells from a command substitution unset
#!   set -e." Hence the use of \read\.

read -rN8 -t1 AA_rand < <(
	strings -n1 /dev/urandom |
		grep -vE '[[:punct:]]' |
		grep -oE '[[:alnum:]]' |
		tr -d '\n\t ' |
		head -c 8
)

script_tmpdr="${TMPDIR}/.temp_${script_name}_rand-${AA_rand}_pid-$$.d"
declare -rx script_tmpdr AA_rand


:;: '## Define temporary data file.'

script_tmpfl="$TMPDIR/.bash_help_topics"
declare -rx script_tmpfl

	#declare -p AA_rand script_tmpdr script_tmpfl #<>
	#: "${Halt:?}" #<>
	#set -x # <>


:;: '## Define groups of traps to be caught and handled.'

script_traps_1=( SIG{INT,QUIT,STOP,TERM,USR{1,2}} )
script_traps_2=( EXIT )


:;: '## Define \function_trap()\.'
#! Note, defining functions is not visible in xtrace.

function_trap()
{
	#local - #<>
	#set -x # <>


	:;: '## Reset traps.'

	trap - "${script_traps_1[@]}" "${script_traps_2[@]}"

		#declare -p script_find_args #<>
		#declare -p script_temp_dirs #<>
		#declare -p script_name #<>


	:;: '## Get a list of directories.'

	local -a TR_list
	mapfile -d "" -t TR_list < <(
		find "${script_temp_dirs[@]}" \
			-type d "${script_find_args[@]}" \
			-name "*${script_name}*" \
			-print0 2> /dev/null
	)

		#declare -p TR_list #<>
		#: "${Halt:?}" #<>
		#set -x # <>


	:;: '## Begin loop: Delete any existing temporary directories.'

	if 	(( "${#TR_list[@]}" > 0 ))
	then

		:;: '## If any are found, then for each directory name.'
		#! Note, Array indices are used in this for loop in
		#!   order to create like indices in the new deletion
		#!   list

		local TR_XX TR_YY TR_dir TR_rm

		for TR_XX in "${!TR_list[@]}"
		do
			:;: '## Define a usable variable name.'

			TR_dir="${TR_list[TR_XX]}"

				#: 'TR_dir:' "$TR_dir" #<>

			:;: '## If the directory is clearly from some '
			: '#+   run of this script, then add it to '
			: '#+   the deletion list \TR_rm.'

			if	[[ $TR_dir =~ _pid-[0-9]{3,9}.d$    ]] ||
				[[ $TR_dir =~ _rand-[a-zA-Z0-9]{8}_ ]] ||
				[[ $TR_dir =~ _hash-[0-9]{5,7}_     ]]

			then
				: "true" #<>

				:;: '## Add the dir to the list.';:

				mapfile -O "$TR_XX" -t TR_rm \
					<<< "${TR_dir}"

					#:; declare -p TR_rm #<>


				:;: '## Restart loop.';:

				continue

			else	: "false" #<>
			fi

			:;: '## Otherwise, get a PID substring if one '
			: '#+   exists.'
			#! Note, of the shell that invoked \mkdir\.

			TR_YY=${TR_dir##*_pid-}
			TR_YY=${TR_YY%.d}

			:;: '## Is there a PID substring in \{TR_dir} ?'

			if 	[[ -n ${TR_YY}        ]] &&
				[[ ${TR_YY} == [0-9]* ]] &&
				(( TR_YY > 300        )) &&
				(( TR_YY < 2**22      ))
			then
				: "true" #<>

				:;: '## Then add the directory to the '
				: '#+   deletion list.'

				mapfile -O "$TR_XX" -t TR_rm \
					<<< "${TR_dir}"

			else 	: "false" #<>
			fi

				#declare -p TR_rm #<>

			:;: '## Restart loop.';:
		done

		:;: '## End loop.';:

			#declare -p TR_rm #<>


		:;: '## If any found directories passed the filters, then '
		: '#+   remove them.'

		if 	(( ${#TR_rm[@]} > 0 ))
		then
			command -p "${script_rm_cmd[@]}" --recursive \
					-- "${TR_rm[@]}" ||
				exit "${LINENO}"
		fi
	fi


	:;: '## Kill the parent process with signal \interrupt\.'

	kill -s sigint "$$"
}


:;: '## Define traps.'
#! Note, The trap on EXIT is disabled during debugging in order to
#!   allow \Halt:?\ to stop execution.

trap 'function_trap; kill -s SIGINT "$$"' "${script_traps_1[@]}"
#trap 'function_trap; exit 0'              "${script_traps_2[@]}"

	#: "${Halt:?}" #<>
	#set -x # <>


:;: '## Create the temporary directory (used for "time file," etc.).'

mkdir "$script_tmpdr" ||
	exit "$LINENO"




:;: '## Get the current list of help topics from bash.'

#! Bug, \compgen\ can be compiled out of bash, so you cannot
#!   depend on its availability.
#! Note, \sort -u\ removes lines from output of \compgen\ in this case.

#! Bug, some of the help strings are longer than 128c.
#!   It would be necc to loop over \builtin help STRING\
#!   and append to an output file in order to gather all
#!   of the available information.

:;: '## Create a new data file.'
#! Note, integers 128 and 129 are indeed correct. Setting
#!   \COLUMNS to 512 doesn\t help.
#! Note, I\m using disk files in order to be abel to more clearly
#!   track down any problems during debugging.

COLUMNS=256 \
	builtin help \
		> "$script_tmpdr/00_help-as-is"

grep '^ ' 2>&1 \
	< "$script_tmpdr/00_help-as-is" \
	> "$script_tmpdr/10_help-out"

cut -c -128 \
	< "$script_tmpdr/10_help-out" \
	> "$script_tmpdr/20_col-1"

cut -c 129- \
	< "$script_tmpdr/10_help-out" \
	> "$script_tmpdr/30_col-2"


:;: '## Remove spaces, fix problematic data and sort.'

awk '{ $1 = $1; print }' \
	  "$script_tmpdr/20_col-1" \
	  "$script_tmpdr/30_col-2" \
	> "$script_tmpdr/40_col-all-trimmed"

sed 's,job_spec,%,' \
	< "$script_tmpdr/40_col-all-trimmed" \
	> "$script_tmpdr/50_massaged"

sort -d \
	< "$script_tmpdr/50_massaged" \
	> "$script_tmpdr/60_sorted"

	#ls -alhFi "$script_tmpdr/60_sorted" #<>
	#: "${Halt:?}" #<>
	set -x # <>


	#<> Debugging code
	#ln -sT /tmp/bash-65_sorted "$script_tmpdr/60_sorted"


:;: '## Define a function for a frequently used set of commands.'

_awk_uniq_c(){
	awk "$*" "$script_tmpdr/60_sorted" |
		uniq -c
}

: "$( declare -F _awk_uniq_c )" #<>










## Get the list of \uniq -c\ counted unique fields at a depth of
#+   x1 awk field.
#! Note, this subsection was written as a separate script and implanted in.

awk '{ print $1 }' "$script_tmpdr/60_sorted" |
	uniq -c |
	sort -rn > "$script_tmpdr/70_f1-uniq-sort"

	#head -v "$script_tmpdr/70_f1-uniq-sort" | cat -Aen #<>
	#exit "$LINENO" #<>
	#set -x # <>


## Get the list of counted multiple occurrances, ie, x3
#+   occurrances of "foo",
#+   x2 occurrances of "bar", etc.

mapfile -d "" -t counts_of_occurrances < <(
	awk '{ printf "%d\0", $1 }' "$script_tmpdr/70_f1-uniq-sort" |
		sort -uz
)

	#declare -p counts_of_occurrances #<>
	#exit "$LINENO" #<>
	set -x # <>


## For loop
#! Note, process from low to high values, ie, 1 then 2 then 3, etc.

unset AA
for	AA in "${counts_of_occurrances[@]}"
do
		#declare -p AA #<>


	## Get the list of unique initial substrings, left to right.

	if 	(( AA == 1 ))
	then
		: "true";:; #<>


		## For field depth one, the command is trivial.

		awk '{ print $1 }' "$script_tmpdr/60_sorted" |
			uniq -c |
			sort -n |
			awk '$1 == "1" { print $2 }' \
				> "$script_tmpdr/80_level-1-substrings"

			#head -v "$script_tmpdr/80_level-1-substrings" #<>
			#cat -Aen "$script_tmpdr/80_level-1-substrings" #<>
			#wc -l "$script_tmpdr/80_level-1-substrings" #<>
			#exit "$LINENO" #<>

		continue

	else	: "false";: #<>
	fi


	## For field depths greater than one.

	mapfile -d "" -t "level_${AA}" < <(
		awk -v aa="${AA}" '$1 == aa { printf "%s\0", $2 }' \
			"$script_tmpdr/70_f1-uniq-sort"
	)

		#declare -p "level_${AA}" #<>
		#exit "$LINENO" #<>
		#set -x # <>


	## Nameref for array

	unset -n array_nameref
	declare -n array_nameref
	array_nameref="level_${AA}"

		#declare -p array_nameref #<>
		#exit "$LINENO" #<>
		#set -x # <>


	## Build awk program
	# shellcheck disable=SC2016

	mapfile -d " " -t awk_prg < <(
		printf '$1 == xx { print'
		printf ' $%s ' $( seq 1 "${AA}" ) |
			sed 's/  /, /g'
		printf '}'
	)

		#declare -p awk_prg #<>
		: 'awk_prg:' "${awk_prg[*]}" #<>
		#: ${Halt:?} #<>
		#exit "$LINENO" #<>
		#set -x # <>


	## COMMENT.

	unset XX
	for 	XX in "${array_nameref[@]}"
	do
			#declare -p XX #<>
			#: ${Halt:?} #<>
			#exit "$LINENO" #<>

		## Execute awk program

		awk -v xx="$XX" "${awk_prg[*]}" "$script_tmpdr/60_sorted" |
			sed -E 's/([A-Z]{3,}|[A-Za-z]{3,}$).*//g' |
			awk '{ $1 = $1 ; print }' \
			    >> "$script_tmpdr/80_level-${AA}-substrings"

			#head -v "$script_tmpdr/80_level-${AA}-substrings" #<>
			#cat -Aen "$script_tmpdr/80_level-${AA}-substrings" #<>
			#: ${Halt:?} #<>
			#exit "$LINENO" #<>
			#set -x # <>
	done
		#head -v "$script_tmpdr/80_level-${AA}-substrings"|cat -Aen #<>
		#exit "$LINENO" #<>
		#set -x # <>

## End for loop
done
unset AA XX


sort -d \
	"$script_tmpdr"/80_level-*-substrings \
	> "$script_tmpdr/90_all-substrings"

	#cat -Aen "$script_tmpdr/90_all-substrings" | head #<>


mapfile -O 1 -t script_all_topix < "$script_tmpdr/90_all-substrings"

	declare -p script_all_topix #<>


mapfile -O 1 -t outputs < <(
	for XX in "${script_all_topix[@]}"
	do
		builtin help -s "$XX"
	done
)

	declare -p outputs #<>


printf '%s\n' "${outputs[@]}" > "$script_tmpdr/100_help-s-correct"

	ls "$script_tmpdr/100_help-s-correct" #<>
	: "${Halt:?}" #<>
	set -x # <>









	#:;: '## Get the full list of help topics. ...somehow....'
	##! Note, in a loop, measure the number of duplicate leading
	##!   substrings in the output of \builtin help\ by counting
	##!   the number unique lines that print when a reducing number
	##!   of record fields are printed.
	#:;: '## Get the total number of records and the total number of '
	#: '#+   horizontal (awk) fields from among all records.'
	#BB_line_count_all=$( wc -l < "$script_tmpdr/60_sorted" )
	##BB_field_count_all=$(
	##awk '{ if (NF > max) max = NF } END { print max }' \
		##"$script_tmpdr/60_sorted"
	##)
		##declare -p BB_line_count_all BB_field_count_all
		##: "${Halt:?}" #<>
		##set -x # <>
	#:;: '## Loop: get information from help output data on how many '
	#: '#+   unique awk records print depending on how many awk fields '
	#: '#+   are printed.'
	#BB_MW=0
	#function _set_lin_ct_vars(){
		#unset "BB_line_count_${BB_MW}"
		#local -g "BB_line_count_${BB_MW}"
		#printf -v "BB_line_count_${BB_MW}" '%s' 0
		#
		#unset -n line_ct
		#local -gn line_ct
		#line_ct="BB_line_count_${BB_MW}"
		#
		#:;: "End of function, _set_lin_ct_vars()";:
	#}
	#declare -F  _set_lin_ct_vars
	#_set_lin_ct_vars
		##declare -p BB_MW "${!BB_line_count_@}" line_ct #<>
		##: "${Halt:?}" #<>
	#:;: '## Get a list of field numbers from 1 to the field number where '
	#: '#+   the number of records is equal to the total number of records.'
	#for 	(( BB_MW=1; line_ct < BB_line_count_all; BB_MW++ ))
	#do
		##! Note, I prefer to avoid using bash\s Field Splitting
		##!   facilities whenever possible: hence the array \numbs
		##!   for keeping track of (awk) fields.
			#:;: "BB_MW: $BB_MW" #<>
		#:;: '## Get an index number for each (awk) field to be '
		#: '#+   referenced in the current iteration.'
		##numbs=() #<>
		#mapfile -O 1 -t numbs < <(
			#seq 1 "$BB_MW"
		#)
			##:;: "count, numbs: ${#numbs[@]}" #<>
			#declare -p numbs #<>
		#:;: '## If possible, create array \prev_awk_prg_str.'
		#if	:;: '## Does \awk_prog_str have a non-zero length?'
			#[[ -n ${awk_prog_str[*]:0:1} ]]
		#then
			#: "true" #<>
			#:;: '## If so, then define variable \prev_awk_prg_str.'
			#prev_awk_prg_str=( "${awk_prog_str[@]}" )
		#else 	: "false" #<>
		#fi
		#:;: '## (Re-)Define variable \awk_prog_str.'
		##! Note, In this block, an awk program is built character
		##!   by character and saved as an (bash) indexed array, using
		##!   the array of indices, \numbs, as it is defined in this
		##!   iteration of this for loop, above. The purpose is to print
		##!   a diminishing number of (awk) record fields per each
		##!   iteration of the (bash) loop.
		#unset awk_prog_str
		#mapfile -d ' ' -t awk_prog_str < <(
			#printf '{ print'
			#printf ' $%d ' "${numbs[@]}" |
				#sed 's/  /, /g'
			#printf '}'
		#)
			##<> Debugging
			##:;: $'begin, awk_prog_str:\t'   "${awk_prog_str[0]}"  "${awk_prog_str[1]}"   "${awk_prog_str[2]}" #<>
			##:;: $'end,   awk_prog_str:\t'   "${awk_prog_str[-3]}" "${awk_prog_str[-2]}" "${awk_prog_str[-1]}" #<>
		#:;: '## Get the number of records that print when the '
		#: '#+   current number, \BB_MW, of fields is printed.';:
		##! Note, do this by creating an indirect scalar parameter,
		##!   \BB_line_count_[0-9]{1,2}. Reference that parameter
		##!   using a nameref variable, \line_ct. Define \line_ct by using
		##!   the combination of two tools constructed above, namely,
		##!   the function \_awk_uniq_c()\ and the indexed array
		##!   \awk_prog_str, which is input for said function. The
		##!   function will execute the (awk) program from the function\s
		##!   STDIN, ie, the function\s positional parameters, and awk
		##!   will process a hard-coded file, named above. The function
		##!   produces output from `uniq -c`. This means that, for any
		##!   number of fields printed, 20, 19, 18, etc., if
		##!   `uniq -c` finds any duplicate truncated lines, then
		##!   the line count of output from `uniq -c` will decrease,
		##!   which would indicate the presence of fully or partially
		##!   duplicated (awk) records, which are actually lines of
		##!   output from `builtin help`.
		#_set_lin_ct_vars
		#printf -v "line_ct" '%d' "$(
			#_awk_uniq_c "${awk_prog_str[*]}" |
				#wc -l
		#)"
			##:;: "line_ct: $line_ct" #<>
		#:;: '## Construct array.'
		#array_line_by_field+=( ["${BB_MW}"]="$line_ct" )
			##declare -p "BB_line_count_${BB_MW}" #<>
			#declare -p array_line_by_field #<>
			##exit 101 #<>
		#:;: 'Begin next iteration';:
	#done
	#:;: 'End loop'
	##unset -n line_ct
	##unset "${!BB_line_count_@}"
	##unset BB_line_count_all BB_MW numbs
		##:;:;: #<>
		##declare -p BB_line_count_all BB_MW numbs #<>
		##declare -p awk_prog_str prev_awk_prg_str #<>
		##declare -p line_ct #<>
		##echo "line_ct: $line_ct" #<>
		##declare -p array_line_by_field #<>
		##declare -p "${!BB_line_count_@}" #<>
	#:;: '## Get a reversed list of indices for \array_line_by_field.'
		#echo indices: "${!array_line_by_field[@]}" #<>
		#declare -p array_line_by_field #<>
		##: "${Halt:?}" #<>
	#mapfile -d "" -t rvs_indics < <(
		#printf '%d\0' "${!array_line_by_field[@]}" |
			#sort -rz
	#)
		#declare -p rvs_indics
	##! Bug / Question, due to how the above loop is constructed,
	##!   will the break point always be at "${array_line_by_field[-2]}" ?
	##!   ...seems to be.
	##! Bug / Question, alternately, what about grepping the output of
	##!   \uniq -c\ and printing all strings that occur just once into
	##!   a 'unique strings' file, in one loop. And removing those
	##!   unique strings from the source file during that loop. then
	##!   incrementing for the next loop?
	##!
	##! At field level 1:
	##$ awk '{ print $1 }' /tmp/bash-65_sorted |
	##	uniq -c |
	##	wc -l
	## 76
	##$ awk '{ print $1 }' /tmp/bash-65_sorted |
	##	uniq -c |
	##	sort -nr |
	##	head -n5
	##      3 quux
	##      2 for
	##      1 while
	##      1 wait
	##      1 variables
	##! grep out all unique strings.
	##$ awk '{ print $1 }' /tmp/bash-65_sorted | uniq -c | sort -nr | awk '$1 == 1 { print $2 }' | head -n5
	## while
	## wait
	## variables
	## until
	## unset
	##! remove the unique strings from the source data pool ??
	##$ awk '{ print $1 }' /tmp/bash-65_sorted |
	##	uniq -c |
	##	sort -nr |
	##	grep -v '^\s*1 '
	##      3 quux
	##      2 for
	##! ...or just increment the field number, which is acting as a filter
	##$ awk '{ print $1 }' /tmp/bash-65_sorted |
	##	uniq -c |
	##	sort -nr |
	##	awk '$1 == 2 { print $2 }' |
	##	head -n5
	## for
	#:;: '## Find where in \array_line_by_field the line count begins '
	#: '#+   to decrease.'
	#for BB_JJ in "${rvs_indics[@]}"
	#do
		#if 	(( array_line_by_field[BB_JJ] < BB_line_count_all ))
		#then
			#break_point="$BB_JJ"
			#break
		#fi
	#done
	#unset BB_JJ
		#declare -p break_point #<>
		#: "${Halt:?}" #<>
		##set -x # <>
	##!   Super Old Note.
	##! Note, the '== "2"' awk string constant below is dependent
	##!   upon the number of records that were printing at the most
	##!   recent iteration where BB_line_count_?? was equivalent
	##!   to BB_line_count_all. Similarly with the '== "1"' awk
	##!   string constant farther below, since each iteration of
	##!   the (pending future) loop decrements the field count by
	##!   just 1.
	#:;: '## There could be multiple records where the 1st field has '
	#: '#+   some duplicates, so use an array. Also, remove any '
	#: '#+   leading or trailing whitespace using awk.'
	#_awk_uniq_c "${prev_awk_prg_str[*]}" |
		#awk '{ $1 = $1; print }' > "$script_tmpdr/70_uniq-c"
		##less "$script_tmpdr/70_uniq-c" #<>
		##: "${Halt:?}" #<>
	#:;: '## COMMENT.'
	#mapfile -t dup_strs < <(
		#awk -v bb_wm=$((break_point + 1)) \
			#'$1 == bb_wm { print $2 }' \
			#"$script_tmpdr/70_uniq-c"
	#)
		##declare -p dup_strs
		##: "${Halt:?}" #<>
		##set -x # <>
	##! Note, this \awk | uniq -c\ sub-pipeline above is the same
	##!   compound (sub-)command as at BB_line_count_1 above, as
	##!   well as at the "print records of 1 fields\ length"
	##!   comment below. Possibly the data should be stored in a
	##!   separate array (in bash), which is as yet unwritten.
	#:;: '## Iterate through array of strings which have duplicates '
	#: '#+   at field depth \break_point.'
	#for XX in "${dup_strs[@]}"
	#do
			##declare -p XX dup_strs prev_awk_prg_str awk_prog_str #<>
		#:;: '## Print records of \break_point + 1\ fields\ record '
		#: '#+   length into new file.'
		##! Note, The input file for this awk command should
		##!   be "60_sorted" - confirmed.
		#awk -v xx="@/^${XX}$/" "\$1 ~ xx ${awk_prog_str[*]}" \
			#"$script_tmpdr/60_sorted" \
			#> "$script_tmpdr/80_unique-strings"
	#done
		##cat -Aen "$script_tmpdr/80_unique-strings" #<>
		##declare -p break_point #<>
		##: "${Halt:?}" #<>
		#set -x # <>
	##! Note, still use the \prev_awk_prg_str array. Even though
	##!   the information sought is from one less field level,
	##!   \uniq -c\ prepends a field to each record.
	#:;: '## Remove all capitalized words.'
	#sed 's/\<[[:upper:]]\{2,\}\>//g' "$script_tmpdr/80_unique-strings" \
		#> "$script_tmpdr/90_no-cap-words"
		##cat -Aen "$script_tmpdr"/90_* #<>
		##: "${Halt:?}" #<>
	#cat 	< "$script_tmpdr/90_no-cap-words" \
		#> "$script_tmpdr/100_unique-help-topics"
		##cat -Aen "$script_tmpdr"/100_* #<>
		##: "${Halt:?}" #<>
	#:;: '## Print records of \break_point+1\ fields\ length; append to file.'
	#awk -v bb_wx="@/^$(( break_point + 1 ))$/" '$1 !~ bb_wx {print $2}' \
		#"$script_tmpdr/70_uniq-c" \
		#> "$script_tmpdr/90_non-dup-topics"
	#cat 	< "$script_tmpdr/90_non-dup-topics" \
		#>> "$script_tmpdr/100_unique-help-topics"
		#cat -Aen "$script_tmpdr"/100_* #<>
		#: "${Halt:?}" #<>
	##! Note, in theory, the current field depth could be 3 or 4,
	##!   and there could be lower levels o dups which this script,
	##!   in its current state, would fail to process correctly.
	#:;: '## Sort new file.'
	#sort "$script_tmpdr/100_unique-help-topics" \
		#> "$script_tmpdr/110_sort"
		##head -n100 "$script_tmpdr"/{6,7,8,9,10}0_*| cat -Aen| more -e #<>
		#head -n100 "$script_tmpdr"/1{0,1}0_* | cat -Aen | more -e #<>
		#: "${Halt:?}" #<>
		#### AJAX ###
	#:;: '## Write a somewhat durable file.'
	#cp -a "$script_tmpdr/110_no-spaces" "$script_tmpfl"
		#declare -p script_strings #<>
		#set -x # <>
		#: "${Halt:?}"


















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
			-name "*${script_tmpfl##*/}*" -print0 2> /dev/null
	)

		declare -p BB_htopx_files #<>
		: "${Halt:?}" #<>


	:;: '## Remove any out of date help topics files.'

	if 	(( ${#BB_htopx_files[@]} > 0 ))
	then
		:;: 'True.' #<>

		:;: '## Configurable validity time frame.'
		#! Note, validity of any help topics file should be a
                #!   configurable time period, and should be an operand
		#!   to \date -d\.

		BB_time="yesterday"

			BB_time="last year" #<>
                	BB_time="2 fortnights ago" #<>
                	BB_time="1 month ago" #<>
                	BB_time="@1721718000" #<>
                	BB_time="-2 fortnights ago" #<>

		BB_file="${script_tmpdr}/${BB_time}"
		touch -mt "$( date -d "${BB_time}" +%Y%m%d%H%M.%S )" \
			"${BB_file}"


		:;: '## Begin a list of files to be removed.'

		BB_list=( "$BB_file" )

			:;: #<>
			stat "$BB_file" #<>
			: "${Halt:?}" #<>


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

			set -x # <>
			declare -p script_strings #<>

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

				#! Note, '||:' below is there because
				#!   errexit is the work of the devil.
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

		: "${Halt:?}" # <>



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

			declare -a "${list_of_rows[@]}" #<>

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

				declare -p elements #<>

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

		set -x # <>


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

				grep -F "${grep_args[@]}" <<< "$DD_YY" ||:
			done |
				tr '\n' '\0'
		)
		unset DD_YY

			declare -p sublist_topics #<>
			exit 101 #<>

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
