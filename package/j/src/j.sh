
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
