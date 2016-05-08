
function g()
{
    local USAGE
read -r -d '' USAGE << EndOfUsage
Usage:
    g
    g [-L|-P] path
    g -
    g -h|--help
EndOfUsage

    if [ "$#" -eq 0 ]                          # no arguments, go to the home directory
    then
        cd
    elif [ "$#" -eq 1 ]                        # 1 argument: path or -
    then
        if [ "$1" = "-h" -o "$1" = "--help" ]  # help
        then
            cat "$(dirname ${BASH_SOURCE[0]})/../README.md"
        elif [ "$1" = "-" ]                    # go to ${OLDPWD}
        then
            cd -
        elif [ -d "$1" ]                       # path is a directory, cd to it
        then
            cd "$1"
        elif [ -e "$1" ]                       # path is a file, cd to it's parent directory
        then
            cd "$(dirname $1)"
        else
            echo "Wrong path [$1]"
            echo "${USAGE}"
            return 1
        fi
    elif [ "$#" -eq 2 ]                    # 2 argument: -L|-P path
    then
        if [ "$1" = "-L" -o "$1" = "-P" ]  # -L|-P path
        then
            if [ -d "$2" ]                 # path is a directory, cd to it
            then
                cd "$1" "$2"
            elif [ -e "$2" ]               # path is a file, cd to it's parent directory
            then
                cd "$1" "$(dirname $2)"
            else
                echo "Wrong path."
                echo "${USAGE}"
                return 2
            fi
        else
            echo "Wrong first argument"
            echo "${USAGE}"
            return 3
        fi
    else
        echo "Wrong argument count"
        echo "${USAGE}"
        return 4
    fi
}
