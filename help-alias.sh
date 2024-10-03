#!/bin/bash
#!
#! Version 1.2
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


#!   The default options, in order of precedence:
#!
#!     --help   Help text of builtin \help\
#!     --	Help text
#!			(If the \--\ string is the first argument,
#!			 otherwise ignored.)
#!     -d	Description
#!     -m	Man page
#!     -s	Summary
#!
#!   Known bugs:
#!     ) Identical info can print multiple times.
#!     ) The main help output page is not a beginner-friendly document.
#!     ) Many valid search terms are excluded from the information that
#!         is available by default, eg, ']', '!', '>>', '..', etc.

	set -x # <>



:;: '#########  Section A  ######### '

## Shell settings and options.
set -e # BAD #<>
set -u #<>
set -o pipefail #<>
shopt -s checkwinsize


## Builtin \help\ must exist.
if ! type -a help | grep -q 'shell builtin'
then
	printf 'The %bhelp%b builtin is required by this' '\x60' '\x60'
	printf ' script. Exiting.\n'
fi


:;: '## Variables, etc.'
#! Note, \:\ (colon) commands are Thompson-style comments; they\re
#!   readable in xtrace output.
#! Note, whitespace is removed from the variable \scr_name
#! Note, \set -e\, a.k.a. errexit, is _In_-_Sane_! To wit:
#!     https://mywiki.wooledge.org/BashFAQ/105
#!   But, people use it, and some unfortunate souls could even require
#!   its use, sadly enough.

:;: '## \COLUMNS has been inconsistently inherited from parent processes.'
LC_ALL=C
export LC_ALL

if      [[ -z ${COLUMNS:=} ]]
then
        :;: "true" #<>
        COLUMNS=$(
                stty -a |
                        tr ';' '\n' |
                        awk '$1 ~ /columns/ { print $2 }'
        )
else    :;: "false" #<>
fi
export COLUMNS


## Name of the script.
scr_name="help-alias.sh"
scr_name=${scr_name//[$'\t\n ']/}
printf '\n%s: For best results, enclose search strings ' "$scr_name"
printf 'within single quotes.\n'


## Each initial character of each help topic.
#! Note, October 2024
list_initial_chars='abcdefghijklmprstuvw%(.:[{'

unset BB CC tot arr
BB=${list_initial_chars}
tot=${#BB}

for (( CC=0; CC < tot; CC++ ))
do
	arr+=( "-${BB:0:1}" )
	BB=${BB:1}
done
	declare -p scr_strings BB CC tot arr #<>
	#exit "$LINENO" #<>

array_init_chars=( "${arr[@]}" )
readonly list_initial_chars array_init_chars 
unset BB CC tot arr


:;: '## Identify / define script input.'
orig_input=( "$@" )
readonly orig_input

scr_strings=( "${orig_input[@]}" )
export scr_strings

	## For debugging, if there aren\t any positional parameters, #<>
	#+   then create some. #<>
	#if (( ${#scr_strings[@]} == 0 )); then :;: "true" #<>
	        #scr_strings=(echo builtin type info ls man which) #<>
	#else    :;: "false" #<>
	#fi #<>
	#declare -p orig_input scr_strings
	#exit "$LINENO"


## Function: \_help-exit()\
_help-exit(){
	shift
	local -
	set +e

	local -a args
	args=( "$@" )

	## Additional help message, to be printed conditionally by awk.
	local -a msgs
	msgs=( 	[0]='\x60man --nh bash\x60'
		[1]='\x60man builtins\x60'
		[2]='\x60man --nh bash 2>&1 | grep -nF \x27'
		[3]='\x27\x60'
		[4]='\x60man grep\x60'
		[5]='\x60man man\x60'
		[6]='\x60info info\x60'
		[7]='\x60man locate\x60'
		[8]='\x60man find\x60'
	)

	## Readability.
	echo
	
	## Get the exit code.
	local exit_code
	builtin help "${args[@]}" 1> /dev/null 2>&1
	exit_code=$?

	## If a certain error statement is printed by default, then 
	#+   also print some additional suggestions.
	builtin help "${args[@]}" 2>&1 |
		awk 	-v scr_nm="$scr_name" \
			-v pp1="${args[0]:=}" \
			-v m0="${msgs[0]}" \
			-v m1="${msgs[1]}" \
			-v m2="${msgs[2]}" \
			-v m3="${msgs[3]}" \
			-v m4="${msgs[4]}" \
			-v m5="${msgs[5]}" \
			-v m6="${msgs[6]}" \
			-v m7="${msgs[7]}" \
			-v m8="${msgs[8]}" \
			-e '{ print }' \
			-e '$0 ~ @/no help topics match/ {
				  printf "\nSee also: \t%s, %s,\n", m0, m1
				  printf "\t\t%s%s%s and \n", m2, pp1, m3
				  printf "\t\t\t%s,\n", m4
				  printf "\t\t%s, %s,\n", m5, m6
				  printf "\t\t\t%s, or %s.\n", m7, m8
			  }'
	exit "$exit_code"
}

## Alias: \_help-exit\
#! Note, this method of using a shadowing alias allows
#!   \LINENO to be expanded correctly; for debugging.
shopt -s expand_aliases
alias _help-exit='_help-exit "[line-number:$LINENO]"'

        #set -x # <>


## Categorize input into option strings and operands.
fmt_help=n
fmt_manpgs=n
list_descriptions=n
list_summaries=n
list_topx=n
print_ver_info=n

if
	## If there is just one argument
	(( ${#scr_strings[@]} == 1 ))
then
	if
		## Count the null byte as an option string.
		[[ ${scr_strings[*]} == "" ]]
	then
		opt_strings+=( "${scr_strings[*]}" )
	fi
else
	## If there is more than argument.
	for LL in "${!scr_strings[@]}"
	do
		## Identify option strings.
		if
			## Anything that begins with a dash is an
			#+   option string.
			[[ ${scr_strings[LL]} =~ ^-+ ]]
		then
			opt_strings+=( "${scr_strings[LL]}" )
			unset "scr_strings[LL]"
			continue
		elif
			#! Bug, the \dms\ part of the \dHhLlmsVv\?\
			#!   string below should be a variable: it 
			#!   could change over time.

			## Otherwise, the string begins with exactly one
			#+   dash and is longer than one character.
			[[ ${scr_strings[LL]} =~ ^-[dHhLlmsVv\?]+ ]]
		then
			## Break the string down into single non-dash
			#+   characters and test each.
			unset MM NN tot arr
			MM=${scr_strings[LL]#-}
			tot=${#MM}

			for (( NN=0; NN < tot; NN++ ))
			do
				arr+=( "-${MM:0:1}" )
				MM=${MM:1}
			done
				declare -p scr_strings MM NN tot arr #<>
				#exit "$LINENO" #<>
			unset MM NN tot

			for OO in "${!arr[@]}"
			do
				## Add the processed input to the list
				#+   of option strings and \continue\.
				opt_strings+=( "${arr[OO]}" )
				unset "arr[OO]"
				continue
			done
			unset OO
		else
			## The list of option arguments is completed 
			#+   when the first non-option argument is
			#+   encountered.
			readonly opt_strings
			break
		fi

		#! Note, If the thread leaves the if-fi structure via
		#!   any route other than \else ... break\, then this 
		#!   \unset\ will be executed.
		unset "scr_strings[LL]"
	done
	unset LL

	if
		## Define the operands.
		(( ${#scr_strings[@]} > 0 ))
	then
		operands=( "${scr_strings[@]}" )
	else
		operands=()
	fi
	unset scr_strings

fi
	declare -p opt_strings operands orig_input list_topx #<>
	exit "$LINENO"



## Process the option strings and operands.

## For input of zero or one arguments.
if 	(( ${#orig_input[@]} == 0 ))
then
	_help-exit
elif
	(( ${#orig_input[@]} == 1 ))
then
	if
		[[ ${orig_input[*]} =~ ^$ ]] ||
		[[ ${orig_input[*]} =~ ^--help$ ]] ||
		[[ ${orig_input[*]} =~ ^-{1,}$ ]]
	then
		## Valid or invalid input possible.
		_help-exit "${orig_input[*]}"
	fi
fi

## For input of two or more arguments.
for MM in "${opt_strings[@]}"
do
	if 	[[ ${opt_strings[MM]} =~ ^-[Hh\?]$ ]]
	then
		fmt_help=y

	elif 	[[ ${opt_strings[MM]} =~ ^-m$ ]]
	then
		fmt_manpgs=y

	elif 	[[ ${opt_strings[MM]} =~ ^-d$ ]]
	then
		list_descriptions=y

	elif 	[[ ${opt_strings[MM]} =~ ^-s$ ]]
	then
		list_summaries=y

	elif 	[[ ${opt_strings[MM]} =~ ^-[Ll]$ ]]
	then
		list_topx=y

	elif 	[[ ${opt_strings[MM]} =~ ^-[Vv]$ ]]
	then
		print_vers_info=y

	elif 	[[ ${opt_strings[MM]} =~ ^-[[:alnum:]]$ ]]
	then
		## Errors.
		_help-exit "${orig_input[@]}"	
	fi
done
unset MM

for NN in "${operands[@]}"
do
	if
		[[ ${operands[NN]} =~ [${list_initial_chars}]+ ]]
	then
		fmt_help=y
	elif
		[[ ${operands[NN]} =~ .+ ]]
	then
		## Errors.
		_help-exit "${orig_input[@]}"
	fi
done
unset NN

	exit "$LINENO"

## formatting
help m v w | 
	awk 	'BEGIN { ii = 1 }
		 $0 ~ @/[[:graph:]]\w*:\s/ { 
		 	printf "\n#########  %d  #########\n", ii
			#ii++
		 }
		 { print }' | 
	more -e



## If the \List\ option is not used, then execute the original
#+   command line as-is.

if	[[ $list_topx == n ]]
then
	:;: 'true' #<>

	_help-exit "${orig_input}"

else 	:;: 'false' #<>
	## Otherwise, the list option is used. #<>
fi









:;: '#########  Section B  ######### '

## Make sure that certain parameters can only be changed one place.

scr_find_args=( '(' -user "$UID" -o -group "$(id -g)" ')' )
scr_rm_cmd=( rm --one-file-system --preserve-root=all --force --verbose )


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

for     AA_WW in "${!AA_UU[@]}"
do
        :;: '## Begin major loop: Get a reliable absolute path.'
        #! Note, if \realpath\ returns with an output of zero length,
        #!   then the assignment to \AA_VV will fail and, since this
        #!   if-fi structure spans the entire for loop, the loop's
        #!   next iteration will begin.

        if      AA_VV=$( realpath -e "${AA_UU[AA_WW]}" 2> /dev/null )
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

                if      [[ -n ${AA_VV} ]] &&
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

                        for     AA_TT in "${scr_temp_dirs[@]}"
                        do

                                :;: '## Does the new directory match an '
                                : '#+   existing directory?'

                                if      [[ ${AA_VV} == "${AA_TT}" ]]
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

                        if      [[ ${AA_ZZ} == yes ]]
                        then
                                scr_temp_dirs+=( "${AA_VV}" )
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
        #declare -p scr_temp_dirs #<>
        #: "${Halt:?}" #<>
        #set -x # <>


:;: '## Finally define TMPDIR.'

if      [[ ${#scr_temp_dirs[@]} -ne 0 ]]
then
        TMPDIR="${TMPDIR:="${scr_temp_dirs[0]}"}"
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

scr_tmpdr="${TMPDIR}/.temp_${scr_name}_rand-${AA_rand}_pid-$$.d"
declare -rx scr_tmpdr AA_rand


:;: '## Define temporary data file.'

scr_tmpfl="$TMPDIR/.bash_help_topics"
declare -rx scr_tmpfl

        #declare -p AA_rand scr_tmpdr scr_tmpfl #<>
        #: "${Halt:?}" #<>
        #set -x # <>


:;: '## Define groups of traps to be caught and handled.'

scr_fnct_traps_1=( SIG{INT,QUIT,STOP,TERM,USR{1,2}} )
scr_fnct_traps_2=( EXIT )


:;: '## Define \_fn_trap()\.'
#! Note, defining functions is not visible in xtrace.

_fn_trap()
{
        #local - #<>
        #set -x # <>


        :;: '## Reset traps.'

        trap - "${scr_fnct_traps_1[@]}" "${scr_fnct_traps_2[@]}"

                #declare -p scr_find_args #<>
                #declare -p scr_temp_dirs #<>
                #declare -p scr_name #<>


        :;: '## Get a list of existing temporary directories from '
	: '#+   this an prior executions.'

        local -a TR_list
        mapfile -d "" -t TR_list < <(
                find "${scr_temp_dirs[@]}" \
                        -type d "${scr_find_args[@]}" \
                        -name "*${scr_name}*" \
                        -print0 2> /dev/null
        )

                #declare -p TR_list #<>
                #: "${Halt:?}" #<>
                #set -x # <>


        :;: '## Begin loop: Delete any existing temporary directories.'

        if      (( "${#TR_list[@]}" > 0 ))
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

                        if      [[ $TR_dir =~ _pid-[0-9]{3,9}.d$    ]] ||
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

                        else    : "false" #<>
                        fi

                        :;: '## Otherwise, get a PID substring if one '
                        : '#+   exists.'
                        #! Note, of the shell that invoked \mkdir\.

                        TR_YY=${TR_dir##*_pid-}
                        TR_YY=${TR_YY%.d}

                        :;: '## Is there a PID substring in \{TR_dir} ?'

                        if      [[ -n ${TR_YY}        ]] &&
                                [[ ${TR_YY} == [0-9]* ]] &&
                                (( TR_YY > 300        )) &&
                                (( TR_YY < 2**22      ))
                        then
                                : "true" #<>

                                :;: '## Then add the directory to the '
                                : '#+   deletion list.'

                                mapfile -O "$TR_XX" -t TR_rm \
                                        <<< "${TR_dir}"

                        else    : "false" #<>
                        fi

                                #declare -p TR_rm #<>

                        :;: '## Restart loop.';:
                done

                :;: '## End loop.';:

                        #declare -p TR_rm #<>


                :;: '## If any found directories passed the filters, then '
                : '#+   remove them.'

                if      (( ${#TR_rm[@]} > 0 ))
                then
                        command -p "${scr_rm_cmd[@]}" --recursive \
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

trap '_fn_trap; kill -s SIGINT "$$"' "${scr_fnct_traps_1[@]}"
#trap '_fn_trap; exit 0'              "${scr_fnct_traps_2[@]}"

        #: "${Halt:?}" #<>
        #set -x # <>


:;: '## Create the temporary directory (used for "time file," etc.).'

mkdir "$scr_tmpdr" ||
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
                > "$scr_tmpdr/00_help-as-is"

grep '^ ' 2>&1 \
        < "$scr_tmpdr/00_help-as-is" \
        > "$scr_tmpdr/10_help-out"

cut -c -128 \
        < "$scr_tmpdr/10_help-out" \
        > "$scr_tmpdr/20_col-1"

cut -c 129- \
        < "$scr_tmpdr/10_help-out" \
        > "$scr_tmpdr/30_col-2"


:;: '## Remove spaces, fix problematic data and sort.'

awk '{ $1 = $1; print }' \
          "$scr_tmpdr/20_col-1" \
          "$scr_tmpdr/30_col-2" \
        > "$scr_tmpdr/40_col-all-trimmed"

sed 's,job_spec,%,' \
        < "$scr_tmpdr/40_col-all-trimmed" \
        > "$scr_tmpdr/50_massaged"

sort -d \
        < "$scr_tmpdr/50_massaged" \
        > "$scr_tmpdr/60_sorted"

        #ls -alhFi "$scr_tmpdr/60_sorted" #<>
        #: "${Halt:?}" #<>
        set -x # <>


## Get the list of \uniq -c\ counted unique fields at a depth of
#+   x1 awk field.
#! Note, this subsection was written as a separate script and implanted in.

awk '{ print $1 }' "$scr_tmpdr/60_sorted" |
        uniq -c |
        sort -rn > "$scr_tmpdr/70_f1-uniq-sort"

        #head -v "$scr_tmpdr/70_f1-uniq-sort" | cat -Aen #<>
        #exit "$LINENO" #<>
        #set -x # <>


## Get the list of counted multiple occurrances, ie, x3
#+   occurrances of "foo",
#+   x2 occurrances of "bar", etc.

mapfile -d "" -t counts_of_occurrances < <(
        awk '{ printf "%d\0", $1 }' "$scr_tmpdr/70_f1-uniq-sort" |
                sort -uz
)

        #declare -p counts_of_occurrances #<>
        #exit "$LINENO" #<>
        set -x # <>


## For loop
#! Note, process from low to high values, ie, 1 then 2 then 3, etc.

unset AA
for     AA in "${counts_of_occurrances[@]}"
do
                #declare -p AA #<>


        ## Get the list of unique initial substrings, left to right.

        if      (( AA == 1 ))
        then
                : "true";:; #<>


                ## For field depth one, the command is trivial.

                awk '{ print $1 }' "$scr_tmpdr/60_sorted" |
                        uniq -c |
                        sort -n |
                        awk '$1 == "1" { print $2 }' \
                                > "$scr_tmpdr/80_level-1-substrings"

                        #head -v "$scr_tmpdr/80_level-1-substrings" #<>
                        #cat -Aen "$scr_tmpdr/80_level-1-substrings" #<>
                        #wc -l "$scr_tmpdr/80_level-1-substrings" #<>
                        #exit "$LINENO" #<>

                continue

        else    : "false";: #<>
        fi


        ## For field depths greater than one.

        mapfile -d "" -t "level_${AA}" < <(
                awk -v aa="${AA}" '$1 == aa { printf "%s\0", $2 }' \
                        "$scr_tmpdr/70_f1-uniq-sort"
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
        for     XX in "${array_nameref[@]}"
        do
                        #declare -p XX #<>
                        #: ${Halt:?} #<>
                        #exit "$LINENO" #<>

                ## Execute awk program

                awk -v xx="$XX" "${awk_prg[*]}" "$scr_tmpdr/60_sorted" |
                        sed -E 's/([A-Z]{3,}|[A-Za-z]{3,}$).*//g' |
                        awk '{ $1 = $1 ; print }' \
                            >> "$scr_tmpdr/80_level-${AA}-substrings"

                        #head -v "$scr_tmpdr/80_level-${AA}-substrings" #<>
                        #cat -Aen "$scr_tmpdr/80_level-${AA}-substrings" #<>
                        #: ${Halt:?} #<>
                        #exit "$LINENO" #<>
                        #set -x # <>
        done
                #head -v "$scr_tmpdr/80_level-${AA}-substrings"|cat -Aen #<>
                #exit "$LINENO" #<>
                #set -x # <>

## End for loop
done
unset AA XX


sort -d \
        "$scr_tmpdr"/80_level-*-substrings \
        > "$scr_tmpdr/90_all-substrings"

        #cat -Aen "$scr_tmpdr/90_all-substrings" | head #<>


mapfile -O 1 -t scr_all_topix < "$scr_tmpdr/90_all-substrings"

        declare -p scr_all_topix #<>


:;: '## Match for an option flag: '
: '#+   \-l\ or \-L\            -- Section C '
: '#+   Anything else           -- Section D '
## \_ If opt_strings are
#+	) only \--\
#+	) only \-m\
#+	) only non-existent and non-null


if      [[ ${scr_strings[0]:-""} = "-s" ]]
then


        :;: '## List short descriptions of specified builtins.'
        :;: '## Remove \-s\ from the array of \scr_strings.'

        unset "scr_strings[0]"
        scr_strings=("${scr_strings[@]}")



        :;: '## Search for help_topics files.'

        mapfile -d "" -t BB_htopx_files < <(
                find "${scr_temp_dirs[@]}" -maxdepth 1 \
                        "${scr_find_args[@]}" -type f \
                        -name "*${scr_tmpfl##*/}*" -print0 2> /dev/null
        )

                declare -p BB_htopx_files #<>
                : "${Halt:?}" #<>


        :;: '## Remove any out of date help topics files.'

        if      (( ${#BB_htopx_files[@]} > 0 ))
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

                BB_file="${scr_tmpdr}/${BB_time}"
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

                        else    :;: "false" #<>
                        fi
                done


                :;: '## Delete each file on the list of files to '
                : '#+   be removed.'

                "${scr_rm_cmd[@]}" -- "${BB_list[@]}" ||
                        exit "${LINENO}"

                unset BB_time BB_file BB_list

        else    :;: 'False.' #<>
        fi

                :;: "number, BB_htopx_files: ${#BB_htopx_files[@]}" #<>


        :;: '## How many help topics files remain?'

        if      (( ${#BB_htopx_files[@]} == 1 ))
        then
                :;: 'True.' #<>

                :;: '## One file exists.'

                scr_tmpfl="${BB_htopx_files[*]}"

        else
                :;: 'False.' #<>
                :;: '## If multiple files exist, delete them.'

                :;: '## Test number of existing files.'

                if      (( ${#BB_htopx_files[@]} > 1 ))
                then
                        :;: 'True.' #<>

                        "${scr_rm_cmd[@]}" -- "${BB_htopx_files[@]}" ||
                                exit "${LINENO}"
                else    :;: 'False.' #<>
                fi

                #+ Add to listing array

                BB_htopx_files+=( "$scr_tmpfl" )
        fi

                declare -p BB_htopx_files #<>
                : "${Halt:?}" #<>










        :;: '## Print info from the topics file and exit.'
        #! Note, using awk regex rather than bash\s pattern matching
        #!   syntax.

        if      (( ${#scr_strings[@]} == 0 ))
        then
                more -e "$scr_tmpfl"
        else

                #! Bug, this section had read from \scr_tmpfl, in
                #!   order to show full usage descriptions.


                :;: '## If the string appears in the first column or '
                : '#+   at the beginning of \scr_tmpfl, then print '
                : '#+   that line.'

                        set -x # <>
                        declare -p scr_strings #<>

                #! Bug, if the search string is NA in the topics file, then
                #!   there s/b a 'NA' message output from the \help\ builtin

                for BB_YY in "${scr_strings[@]}"
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


                        if      [[ $BB_ZZ == \\\\% ]]
                        then
                                BB_ZZ='job_spec'
                        fi

                                #declare -p BB_ZZ scr_strings

                        BB_XX=$(
                            awk -v yy="$BB_ZZ" '$1 ~ yy { print " " $0 }' \
                                        "$scr_tmpfl"
                        )

                        if      [[ -n ${BB_XX:0:8} ]]
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
        [[ ${scr_strings[0]:-} = @(-l|-lh|-lv) ]]
then

	#! Bug, when the default \help\ output prints, if any builtins
	#!   are disabled, then there\s an asterisk in the first column.
	#!   Allow for that.

        :;: '#########  Section C  ######### '

        :;: '## Additional option: \-l\ for \list;\ \-lh\ and \-lv\ '
        : '#+   for horizontal and vertical lists, respectively. '
        : '#+   Defaults to vertical.'

        unset "scr_strings[0]"
        scr_strings=("${scr_strings[@]}")


        :;: '## Initialize to zero...'
        : '#+   ...Carriage Return Index.'

        cr_indx=0

        : '#+   ...Topic Index.'

        tpc_indx=0


        :;: '## Posparm \2 can be a filter. If empty, let it be any char.'

        if      [[ -z ${scr_strings[1]:-} ]]
        then
                set -- "${scr_strings[0]:=}" '.*'
        fi

        #! Bug, reduce the length of the list according to
        #!   posparms, eg, \ex\ or \sh\.


        :;: '## Get total Number of Help Topics for this run of this '
        : '#+   script.'

        ht_count=${#scr_all_topix[@]}


        :;: '## Define Maximum String Length of Topics.'

        strlen=$(
                printf '%s\n' "${scr_all_topix[@]}" |
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

        if      (( max_columns > ht_count ))
        then
                :;: "true" #<>

                all_columns=$ht_count

        else    :;: "false" #<>
        fi


        :;: '## Print a list.'

        if      [[ ${scr_strings[0]} = "-lh" ]]
        then

                :;: '## Print a list favoring a horizontal sequence.'

                :;: '## For each index of the list of topics.'

                for tpc_indx in "${!scr_all_topix[@]}"
                do
                        :;: '## If the ...'

                        if      (( cr_indx == all_columns ))
                        then
                                echo
                                cr_indx=0
                        fi

                        printf "${printf_format_string}" \
                                "${scr_all_topix[tpc_indx]}"
                        unset "scr_all_topix[tpc_indx]"

                        (( ++cr_indx ))
                done
                printf '\n'



        elif
                [[ ${scr_strings[0]} = @(-l|-lv) ]]
        then

                :;: '## Print a list favoring a vertical sequence.'

                :;: '## Get the Number of Full Rows.'

                full_rows=$(( ht_count / all_columns ))


                :;: '## Get the number of topics in any partial row (modulo).'

                row_rem=$(( ht_count % all_columns ))


                :;: '## Record whether there is a Partial Row.'

                part_rows=0

                if      (( row_rem > 0 ))
                then
                        :;: "true" #<>

                        part_rows=1

                else    :;: "false" #<>
                fi


                :;: '## Get the total number of Rows.'

                all_rows=$(( full_rows + part_rows ))

                mapfile -d "" -t list_of_rows < <(
                        CC_UU=$(( all_rows - 1 ))
                        for     (( CC_WW=0 ; CC_WW <= CC_UU ; ++CC_WW ))
                        do
                                printf '%s\0' "__row__${CC_WW}"
                        done
                        unset CC_UU
                )
                unset "${list_of_rows[@]}" CC_WW

                        declare -a "${list_of_rows[@]}" #<>

                CC_VV=$((${#scr_all_topix[@]}-1))
                CC_XX=0

                for     (( CC_YY=0; CC_YY <= CC_VV; ++CC_YY ))
                do
                        printf -v "__row__${CC_XX}[${cr_indx}]" '%s' \
                                "${scr_all_topix[CC_YY]}"

                        if      (( CC_XX == $(( all_rows - 1 )) ))
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

        :;: '#########  Section D - Formatting  ######### '

        :;: '##   If the script\s first operand is neither a \-s\ nor a '
        : '#+   \-l*\.'

                set -x # <>


        :;: '## If the number of strings is greater than zero.'

        if      (( ${#scr_strings[@]} > 0 ))
        then

                for DD_XX in "${!scr_strings[@]}"
                do
                        grep_args+=("-e" "${scr_strings[DD_XX]}")
                done
                unset DD_XX

                mapfile -d "" -t sublist_topics < <(
                        for DD_YY in "${scr_all_topix[@]}"
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
                        if      (( "${#sublist_topics[@]}" > 1 ))
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
