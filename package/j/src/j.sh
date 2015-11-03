
function j()
{
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

    # create the bookmark file if it doesn't exist
    local bookmarkDir="${EFFICIENT_SHELL_DataDirectory}/j"
    test ! -e "${bookmarkDir}"  && mkdir --parents "${bookmarkDir}"
    local bookmarkFile="${bookmarkDir}/bookmarks"
    test ! -f "${bookmarkFile}" && echo " " > "${bookmarkFile}"

    local reEntry="\S\+"
    local rePath="\S.*"
    local rePrefix="^\s*"
    local reSeparator="\s\+"
    local reSuffix="\s*$"

    if [ "$#" -eq 0 ]  # j : show bookmarks
    then
        # print the bookmarks file
        local delim=":"
        sed -n -e "s/${rePrefix}\(${reEntry}\)${reSeparator}\(${rePath}\)${reSuffix}/\1${delim}\2/p" "${bookmarkFile}" \
        | column -s ${delim} -t \
        | sort

    elif [ "$#" -eq 1 ]  # j entry
    then
        local arg="$1"
        if [ "${arg}" = "--edit" -o "${arg}" = "-e" ]
        then
            ${EDITOR} "${bookmarkFile}"
        elif [ "${arg}" = "--help" -o "${arg}" = "-h" ]
        then
            cat "${EFFICIENT_SHELL_PackageDirectory}/j/README.md"
        else
            local entry="$1"

            # get the first occurence of the entry
            local destination=$(sed -n -e "0,/${rePrefix}${entry}${reSeparator}\(${rePath}\)${reSuffix}/s//\1/p" "${bookmarkFile}")

            # go there
            g "${destination}"
        fi

    elif [ "$#" -eq 2 ]  # j remove entry
    then
        local action="$1"
        local entry="$2"

        if [ "${action}" = "--remove" -o "${action}" = "-r" ]
        then
            # remove all the lines containing the entry
            sed -i -e "/${rePrefix}${entry}${reSeparator}\(${rePath}\)${reSuffix}/d" "${bookmarkFile}"
        else
            echo "Wrong argument"
            echo "${USAGE}"
            return 2
        fi
    elif [ "$#" -eq 3 ]  # j add entry path
    then
        local action="$1"
        local entry="$2"
        #local path=$(readlink -f "$3")  # resolve symlinks
        local path=$(g "$3"  >/dev/null 2>&1 && pwd && cd - >/dev/null 2>&1)  # don't resolve symlinks

        if [ "${action}" = "--add" -o "${action}" = "-a" ]
        then
            # remove any previous entry
            j --remove ${entry}
            # append the new entry (don't use "echo -e")
            echo                    >> "${bookmarkFile}"
            echo "${entry} ${path}" >> "${bookmarkFile}"
            # reformat the file
            local delim=":"
            sed -n -e "s/${rePrefix}\(${reEntry}\)${reSeparator}\(${rePath}\)${reSuffix}/\1${delim}\2/p" "${bookmarkFile}" \
            | column -s ${delim} -t \
            | sort -o "${bookmarkFile}"
        else
            echo "Wrong argument"
            echo "${USAGE}"
            return 3
        fi
    else
        echo "Wrong input"
        echo "${USAGE}"
        return 4
    fi

}

j_ProgrammableCompletion()
{
    # http://eli.thegreenplace.net/2013/12/26/adding-bash-completion-for-your-own-tools-an-example-for-pss

    # COMP_WORDS is an array of words in the current command line.
    # COMP_CWORD is the index of the current word (the one the cursor is in)
    local current_index=${COMP_CWORD}
    local current_word="${COMP_WORDS[COMP_CWORD]}"
    local previous_word="${COMP_WORDS[COMP_CWORD-1]}"

    local bookmarkDir="${EFFICIENT_SHELL_DataDirectory}/j"
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
