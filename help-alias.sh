#!/bin/bash
## help-alias.sh, version 0.1

#+   A re-implementation written in bash 5.2 of `help -s`, which is
#+ `apropos` for bash's help builtin. Where bash's `help` builtin
#+ performs bash's internal Pattern Matching syntax, this script accepts
#+ awk regular expressions. This difference in functionality was an
#+ accidental design flaw in this script.
#+   SPDX-FileCopyrightText: 2024 Wiley Young
#+   SPDX-License-Identifier: GPL-3.0-or-later

## Variables, etc: define a list of search \strings, either from the CLI
#+ or by default for demonstration purposes; \FF is a durable file name
#set -euxo pipefail
LC_ALL=C
if [[ $# -ne 0 ]]
then
    strings=("$@")
else
    strings=(builtins echo info ls man type which)
fi
FF=~/.bash_help_topics


## List short descriptions of specified builtins
if [[ $1 = "-s" ]]
then

    ## Remove "dead" temporary directories: get a list of directories
    mapfile -d "" -t dirs < <(
        find ~ -type d -name '*_mkhelp.sh_*' -print0
    )

    #+ If any are found
    if [[ "${#dirs[@]}" -gt 0 ]]
    then
        #+ For each directory name
        for DD in "${dirs[@]}"
        do
            #+ Get the embedded value of $$, ie, the PID of the
            #+ invoking shell, then look to see whether the PID from
            #+ the found directory is still active
            AA=${DD##*_}
            BB=$(
            ps aux |
                awk -v dd="$AA" '$2 ~ dd'
            )

            #+ If an active PID is found, then continue to the next
            #+ found directory, ie, the next loop; or, remove said
            #+ found directory
            if [ -n "$BB" ]
            then
                continue
            fi
            rm -fr "$DD" ||
                exit "$LINENO"
          done
      fi

    ## Does a valid help_topics file exist?
    mapfile -d "" -t EE < <(
        find ~ -maxdepth 1 -type f -name "*${FF##*/}*" -print0
    )
    case ${#EE[@]} in
        #+ If no files exist then create one. Use a new temporary 
        #+ working directory with a unique hash based on the time
        0)  CC=$(
                date |
                    sum |
                    tr -d ' \t'
            )
            DD="$HOME/.tmp_mkhelp.sh_${CC}_$$"
            mkdir -p "$DD" ||
                exit "$LINENO"

            ## Parse data and remove leading spaces
            COLUMNS=256 builtin help |
                grep ^" " > "$DD/o"
            cut -c -128 "$DD/o" > "$DD/c1"
            cut -c $((128+1))- "$DD/o" > "$DD/c2"
            sort -u "$DD/c1" "$DD/c2" > "$DD/c0"
            sed -i 's/[ \t]*$//' "$DD/c0"

            ## Create a durable file and remove working directory. Note,
            #+ `:` is a Thompson-style comment - readable when xtrace
            #+ is enabled.
            mv "$DD/c0" "$FF" ||
                exit "$LINENO"
            : Topics file created.
            rm -fr "$DD" ||
                exit "$LINENO"
            ;;
        #+ If one file exists (Thompson-style comment)
        1)  : Topics file exists.
            ;;
        #+ If multiple files exist
        [2-9]|[1-9][0-9]+)
            echo Multiple topics files exist. Exiting.
            ls -la "${EE[@]}"
            exit "$LINENO"
            ;;
        #+ Catch any errors
        *)  echo Error. Exiting.
            exit "$LINENO"
            ;;
    esac

    ## Print info from the topics file and exit. (Note, using awk regex
    #+ rather than bash's pattern matching syntax.)
    for HH in "${strings[@]}"
    do
        awk -v regex="$HH" '$1 ~ regex { print $0 }' "$FF"
    done |
        sort -u

## Print a list of help topics
else
    ## Get a list of topics and some data
    mapfile -t topix < <(
        compgen -A helptopic
    )
    cr_indx=0
    tpc_indx=0
    strlen=$(printf '%s\n' "${topix[@]}" | 
        awk '{if (x < length($0)) x = length($0) }; END { print x }')
    col_width=$((strlen+3))
    columns=$((80/col_width))

    ## Print a list favoring a horizontal sequence
    if [[ $1 = "-lh" ]]
    then

        ## For each index of the list of topics
        for tpc_indx in "${!topix[@]}"
        do
            ## If the
            if [[ $cr_indx -eq $columns ]]
            then
                echo
                cr_indx=0
            fi
            printf '%-12s' "${topix[tpc_indx]}"
            unset "topix[tpc_indx]"
            ((cr_indx++))
        done
        printf '\n'

    ## Print a list favoring a vertical sequence
    elif [[ $1 = @(-l|-lv) ]]
    then

        ht_count=${#topix[@]}
        col_count=0
        rows=$((ht_count/columns))
        row_rem=$((ht_count%columns))
        (( row_rem > 0 )) && 
            rows=$((rows+1))
        tpc_indx=0

        while true
        do
            (( ${#topix[@]} == 0 )) && 
                break
            if (( cr_indx == columns ))
            then
                printf '\n'
                cr_indx=0
                col_count=$((col_count+1))
                (( tpc_indx >= ht_count )) && 
                    tpc_indx=$col_count
            fi
            printf '%-12s' "${topix[tpc_indx]}"
            unset "topix[tpc_indx]"
            tpc_indx=$((tpc_indx + rows))
            ((cr_indx++))
        done
        #printf '\n'
    else
        builtin help "$@" | 
            less
    fi
fi

exit 00
