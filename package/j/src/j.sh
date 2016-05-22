
# prints j's bookmarks file with aligned columns and sorted lines
# replacement for "column" from "sudo apt-get install bsdmainutils"
# customized for work with j's bookmarks file
# for use in j()
function j_prettyprint() {
    local delim="$1"

    # get the bookmarks file's path
    local bookmarkDir="$(dirname ${BASH_SOURCE[0]})/../data"
    local bookmarkFile="${bookmarkDir}/bookmarks"
    # no need to continue if the bookmarks file doesn't exist
    if [ ! -e "${bookmarkDir}" ] ; then
        >&2 echo "NOT FOUND [bookmarkFile:${bookmarkFile}]"
        return 1
    fi

    # regex for parsing the bookmarks file
    local reEntry="\S\+"
    local rePath="\S.*"
    local rePrefix="^\s*"
    local reSeparator="\s\+"
    local reSuffix="\s*$"
    local reLine="${rePrefix}\(${reEntry}\)${reSeparator}\(${rePath}\)${reSuffix}"

    # parse the bookmarks file and extract the columns
    local entries=( $(sed -e "s/${reLine}/\1/" "${bookmarkFile}") )
    local paths=( $(sed -e "s/${reLine}/\2/" "${bookmarkFile}") )

    # get the max width of the entries column
    local entry
    local maxLen=0
    for entry in ${entries[@]} ; do
        [ ${#entry} -gt ${maxLen} ] && maxLen=${#entry}
    done

    # print with aligned columns and sorted line
    (   # printing in a subshell then sorting seems to be the best
        # workaround the last '\n'
        local i=0
        for (( i=0; i<${#entries[@]}; i++ )) ; do
            printf "%-${maxLen}s  %s\n" "${entries[i]}" "${paths[i]}"
        done
    ) | sort
}

function j() {
    local USAGE
    read -r -d '' USAGE << EndOfUsage
Usage:
    j
    j entry
    j entry path_at_entry
    j --add|-a entry path
    j --remove|-r entry
    j --edit|-e
    j --help|-h
EndOfUsage

    local OPTS
    OPTS=$(getopt -o 'a:r:eh' -l 'add:,remove:,edit,help' -n "${FUNCNAME}" -- "$@")
    if [ $? -ne 0 ] ; then >&2 echo "${USAGE}" ;  return 1 ; fi
    eval set -- "${OPTS}"

    # create the bookmark file if it doesn't exist
    local bookmarkDir="$(dirname ${BASH_SOURCE[0]})/../data"
    test ! -e "${bookmarkDir}" && mkdir --parents "${bookmarkDir}"
    local bookmarkFile="${bookmarkDir}/bookmarks"
    test ! -f "${bookmarkFile}" && touch "${bookmarkFile}"

    local reEntry="\S\+"
    local rePath="\S.*"
    local rePrefix="^\s*"
    local reSeparator="\s\+"
    local reSuffix="\s*$"

    case "$1" in
        '--')
            shift  # get rid of '--'
            case $# in
                0) # j : pretty print the bookmarks file
                    j_prettyprint
                ;;
                1) # j <entry> : jump to the bookmark
                    local entry="$1"
                    # get the first occurence of the entry
                    local destination=$(sed -n -e "0,/${rePrefix}${entry}${reSeparator}\(${rePath}\)${reSuffix}/s//\1/p" "${bookmarkFile}")
                    if [ -n "${destination}" ] ; then
                        # go there
                        g "${destination}"
                    else
                        >&2 echo "[${entry}] not found"
                        return 2
                    fi
                ;;
                2) # j <entry> <path_at_entry> : equivalent to: jump to bookmark then go to the given relative path
                    local entry="$1"
                    local path_at_entry="$2"

                    # straightforward implementation, doesn't allow 'cd -' to the actual OLDPWD
                    #j "${entry}" && g "${path_at_entry}"

                    # WET implementation, needs refactoring
                    # get the first occurence of the entry
                    local destination=$(sed -n -e "0,/${rePrefix}${entry}${reSeparator}\(${rePath}\)${reSuffix}/s//\1/p" "${bookmarkFile}")
                    destination+="/${path_at_entry}"
                    if [ -n "${destination}" ] ; then
                        g "${destination}"
                    else
                        >&2 echo "[${entry}] not found"
                        return 3
                    fi
                ;;
                *)
                    >&2 echo "${USAGE}"
                    return 4
                ;;
            esac
        ;;
        '--add'|'-a')
            #echo "[@:$@]"
            if [ $# -eq 4 -a "$3" = '--' ] ; then  # --add <entry> -- <path>
                local entry="$2"
                local path0="$4"
                #local path=$(readlink -f "${path0}")  # resolve symlinks
                local path=$(g "${path0}"  >/dev/null 2>&1 && pwd && cd - >/dev/null 2>&1)  # do NOT resolve symlinks
                # remove any previous entry
                j --remove "${entry}"
                # append the new entry (don't use "echo -e")
                echo                    >> "${bookmarkFile}"
                echo "${entry} ${path}" >> "${bookmarkFile}"
                # reformat the file
                # @note: keep "sort -o file"
                # for some reason, "j_prettyprint > file" and "( j_prettyprint ) | tee file" fail and erase the file
                j_prettyprint | sort -o "${bookmarkFile}"
            else
                >&2 echo "${USAGE}"
                return 5
            fi
        ;;
        '--remove'|'-r')
            if [ $# -eq 3 -a "$3" = '--' ] ; then
                local entry="$2"
                # remove all the lines containing the entry
                sed -i -e "/${rePrefix}${entry}${reSeparator}\(${rePath}\)${reSuffix}/d" "${bookmarkFile}"
            else
                >&2 echo "${USAGE}"
                return 6
            fi
        ;;
        '--edit'|'-e')
            if [ $# -eq 2 -a "$2" = '--' ] ; then
                if [ -n "${EDITOR}" ] ; then
                    "${EDITOR}" "${bookmarkFile}"
                else
                    >&2 echo "EDITOR not defined"
                    return 7
                fi
            else
                >&2 echo "${USAGE}"
                return 8
            fi
        ;;
        '--help'|'-h')
            if [ $# -eq 2 -a "$2" = '--' ] ; then
                cat "$(dirname ${BASH_SOURCE[0]})/../README.md"
            else
                >&2 echo "${USAGE}"
                return 9
            fi
        ;;
        *)
            >&2 echo "Unknown [${opt}]"
            >&2 echo "${USAGE}"
            return 10
        ;;
    esac
}

function j_ProgrammableCompletion() {
    # http://eli.thegreenplace.net/2013/12/26/adding-bash-completion-for-your-own-tools-an-example-for-pss

    # COMP_WORDS is an array of words in the current command line.
    # COMP_CWORD is the index of the current word (the one the cursor is in)
    local current_index=${COMP_CWORD}
    local current_word="${COMP_WORDS[COMP_CWORD]}"
    local previous_word="${COMP_WORDS[COMP_CWORD-1]}"

    local bookmarkDir="$(dirname ${BASH_SOURCE[0]})/../data"
    local bookmarkFile="${bookmarkDir}/bookmarks"
    # no need to continue if the bookmarks file doesn't exist
    if [ ! -e "${bookmarkDir}" ] ; then
        >&2 echo "NOT FOUND [bookmarkFile:${bookmarkFile}]"
        return 1
    fi

    local bookmarks=$(sed -e 's/^\s*\(\S\+\)\s\+.\+$/\1/' "${bookmarkFile}")
    local candidate_list

    # option
    if [ ${current_index} -eq 1    ] && \
       [[ "${current_word}" == -* ]] ; then
        # possible options
        candidate_list="--add -a --remove -r --edit -e --help -h"
        COMPREPLY=($(compgen -W "${candidate_list}" -- "${current_word}"))
    # get entry or remove entry
    elif [ ${current_index} -eq 1          ] || \
         [ "${previous_word}" = '--remove' ] || \
         [ "${previous_word}" = '-r'       ] ; then
        COMPREPLY=($(compgen -W "${bookmarks}" -- "${current_word}"))
    # these options don't accept arguments or there is no meaning to completing their first argument
    elif [ "${previous_word}" = '--edit' ] || \
         [ "${previous_word}" = '-e'     ] || \
         [ "${previous_word}" = '--help' ] || \
         [ "${previous_word}" = '-h'     ] || \
         [ "${previous_word}" = '--add'  ] || \
         [ "${previous_word}" = '-a'     ] ; then
        COMPREPLY=()
    # j --add <entry> (${current_word} = <path>)
    elif [ ${current_index} -eq 3 ] && \
         [ "${COMP_WORDS[1]}" = '--add' -o "${COMP_WORDS[1]}" = '-a' ] ; then
        # https://unix.stackexchange.com/a/55622/140618
        # Unescape space
        current_word=${current_word//\\ / }
        # Expand tilder to $HOME
        [[ ${current_word} == "~/"* ]] && current_word=${current_word/\~/$HOME}
        # Show completion if path exist (and escape spaces)
        compopt -o filenames
        local files=("${current_word}"*)
        [[ -e ${files[0]} ]] && COMPREPLY=( "${files[@]// /\ }" )
    # j <entry> (${current_word} = <relative path at entry>)
    elif [ ${current_index} -eq 2 ] && \
         [ $(grep "${previous_word}" <<< "${bookmarks}") ] ; then  # <entry> has to be valid
        #
        local entryPath=$(j "${previous_word}" >/dev/null 2>&1 && pwd && cd - >/dev/null 2>&1)
        COMPREPLY=( $(
            cd "${entryPath}" >/dev/null 2>&1

            local files=""
            local f=""
            # quick & dirty hack (tm): adding a garbage sting --nothing-- in dirname
            #     if current_word is a directory, it returns current_word (not its parent)
            #     if current_word is empty, returns entryPath
            #     otherwise, returns the usual dirname
            for f in "$(dirname ${current_word}nothing)"/* ; do
                # append "/" at the end of a directory names
                # add nothing to other names
                if [ -d "${f}" ] ; then
                    files+=" ${f/.\//}/"
                else
                    files+=" ${f/.\//}"
                fi
            done

            # no required, we're in a subshell
            #cd - >/dev/null 2>&1

            # let compgen filter/generate the completion list
            compgen -W "${files}" -- "${current_word}"
        ) )

        # *shows* only "basename" in the completion
        compopt -o filenames
        # do not append a space unless there is only 1 option, which is NOT a directory
        # i.e. add a space only when the only completion possible is the name of a file
        local comp_len=${#COMPREPLY[@]}
        if [ ${comp_len} -eq 0 ] || [ ${comp_len} -gt 1 ] || [ -d "${entryPath}/${COMPREPLY[0]}" ] ; then
            compopt -o nospace
        fi

    fi

    return 0
}

# register j_ProgrammableCompletion to provide completion for j
complete -F j_ProgrammableCompletion j
