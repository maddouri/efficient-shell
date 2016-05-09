
# requires "column" from "sudo apt-get install bsdmainutils"
function j() {
    local USAGE
    read -r -d '' USAGE << EndOfUsage
Usage:
    j
    j entry
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
            # j : pretty print the bookmarks file
            if [ $# -eq 0 ] ; then
                local delim=":"
                sed -n -e "s/${rePrefix}\(${reEntry}\)${reSeparator}\(${rePath}\)${reSuffix}/\1${delim}\2/p" "${bookmarkFile}" \
                | column -s ${delim} -t \
                | sort
            # j <entry> : jump to the bookmark
            elif [ $# -eq 1 ] ; then
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
            else
                >&2 echo "${USAGE}"
                return 3
            fi
        ;;
        '--add'|'-a')
            echo "[@:$@]"
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
                local delim=":"
                sed -n -e "s/${rePrefix}\(${reEntry}\)${reSeparator}\(${rePath}\)${reSuffix}/\1${delim}\2/p" "${bookmarkFile}" \
                | column -s ${delim} -t \
                | sort -o "${bookmarkFile}"
            else
                >&2 echo "${USAGE}"
                return 4
            fi
        ;;
        '--remove'|'-r')
            if [ $# -eq 3 -a "$3" = '--' ] ; then
                local entry="$2"
                # remove all the lines containing the entry
                sed -i -e "/${rePrefix}${entry}${reSeparator}\(${rePath}\)${reSuffix}/d" "${bookmarkFile}"
            else
                >&2 echo "${USAGE}"
                return 5
            fi
        ;;
        '--edit'|'-e')
            if [ $# -eq 2 -a "$2" = '--' ] ; then
                if [ -n "${EDITOR}" ] ; then
                    "${EDITOR}" "${bookmarkFile}"
                else
                    >&2 echo "EDITOR not defined"
                    return 6
                fi
            else
                >&2 echo "${USAGE}"
                return 7
            fi
        ;;
        '--help'|'-h')
            if [ $# -eq 2 -a "$2" = '--' ] ; then
                cat "$(dirname ${BASH_SOURCE[0]})/../README.md"
            else
                >&2 echo "${USAGE}"
                return 8
            fi
        ;;
        *)
            >&2 echo "Unknown [${opt}]"
            >&2 echo "${USAGE}"
            return 9
        ;;
    esac
}

j_ProgrammableCompletion()
{
    # http://eli.thegreenplace.net/2013/12/26/adding-bash-completion-for-your-own-tools-an-example-for-pss

    # COMP_WORDS is an array of words in the current command line.
    # COMP_CWORD is the index of the current word (the one the cursor is in)
    local current_index=${COMP_CWORD}
    local current_word="${COMP_WORDS[COMP_CWORD]}"
    local previous_word="${COMP_WORDS[COMP_CWORD-1]}"

    local bookmarkDir="$(dirname ${BASH_SOURCE[0]})/../data"
    local bookmarkFile="${bookmarkDir}/bookmarks"
    # no need to continue if the bookmars file doesn't exist
    if [ ! -e "${bookmarkDir}" ]
    then
        echo "NOT FOUND [bookmarkFile:${bookmarkFile}]"
        return 1
    fi

    local candidate_list

    if [ ${current_index} -eq 1   ] && \
       [[ "${current_word}" == -* ]]  # option
    then
        # possible options
        candidate_list="--add -a --remove -r --edit -e --help -h"
        COMPREPLY=($(compgen -W "${candidate_list}" -- ${current_word}))
    elif [ ${COMP_CWORD} -eq 1             ] || \
         [ "${previous_word}" = '--remove' ] || \
         [ "${previous_word}" = '-r'       ]
    then
        # get the list of entries
        candidate_list=$(sed -e 's/^\s*\(\S\+\)\s\+.\+$/\1/' "${bookmarkFile}")
        COMPREPLY=($(compgen -W "${candidate_list}" -- ${current_word}))
    # these options don't accept arguments or there is no meaning to completing their first argument
    elif [ "${previous_word}" = '--edit' ] || \
         [ "${previous_word}" = '-e'     ] || \
         [ "${previous_word}" = '--help' ] || \
         [ "${previous_word}" = '-h'     ] || \
         [ "${previous_word}" = '--add'  ] || \
         [ "${previous_word}" = '-a'     ]
    then
        COMPREPLY=()
    else
        # just list the files in the current directory (default behavior of bash)
        COMPREPLY=($(/bin/ls))
    fi

    return 0
}

# Register j_ProgrammableCompletion to provide completion for the following commands
complete -F j_ProgrammableCompletion j
