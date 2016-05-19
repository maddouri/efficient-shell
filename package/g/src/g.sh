
# if <path> is a directory, echo <path>
# if <path> is a file (i.e. "-e <path>" is true), echo $(dirname <path>)
# error otherwise
function g_getdir() {  # ${FUNCNAME} <path>
    if [ $# -ne 1 ] ; then
        >&2 echo "${FUNCNAME}: expected 1 argument, received $# [$@]"
        return 1
    fi

    local arg="$1"

    if   [ -d "${arg}" ] ; then echo "${arg}"
    elif [ -e "${arg}" ] ; then echo "$(dirname ${arg})"
    else
        >&2 echo "${FUNCNAME}: [${arg}] does not exist"
        return 2
    fi
}

# assume valid arguments passed from g()
function g_cd_wrapper() {
    g_onExit "${nextDir}" ; if [ $? -ne 0 ] ; then >&2 echo "g_cd_wrapper: g_onExit failed"  ; return 1 ; fi
    cd "$@"               ; if [ $? -ne 0 ] ; then >&2 echo "g_cd_wrapper: cd failed"        ; return 2 ; fi
    g_onEntry             ; if [ $? -ne 0 ] ; then >&2 echo "g_cd_wrapper: g_onEntry failed" ; return 3 ; fi
}

# when the given path is a file not a directory, cd to that file's directory
# otherwise, acts like cd
function g() {
    local USAGE
    read -r -d '' USAGE << EndOfUsage
Usage:
    g
    g [-L|-P] path
    g -
    g --hooks
    g -h|--help
EndOfUsage

    # http://www.bahmanm.com/blogs/command-line-options-how-to-parse-in-bash-using-getopt
    # https://gist.github.com/cosimo/3760587
    local OPTS
    # https://stackoverflow.com/a/9525025/865719
    OPTS=$(getopt -o 'L:P:h' -l 'hooks,help' -n "${FUNCNAME}" -- "$@")
    if [ $? -ne 0 ] ; then >&2 echo "${USAGE}" ;  return 1 ; fi

    # Set $1, $2... to the values of OPTS, even if it begins with '−' or '+':
    # e.g. if $OPTS == "-a b --c d something"
    # then
    #    $1 == -a
    #    $2 == b
    #    $3 == --c
    #    $4 == d
    #    $5 == something
    # which is useful for the "while" loop later and the calls to "shift"
    eval set -- "${OPTS}"

    # sanity check: $OPTS == $@
    #echo "[OPTS:${OPTS}][#:$#][@:$@]"
    # '--' is used at the beginning of the non-option arguments

    # used in g_cd_wrapper()
    local previousDir="${OLDPWD}"
    local currentDir="${PWD}"
    # actual directory name -- after a call to g_getdir
    local nextDir
    case "$1" in
        '-h'|'--help')
            if [ $# -eq 2 -a "$2" = '--' ] ; then
                cat "$(dirname "${BASH_SOURCE[0]}")/../README.md"
                return 0
            else
                >&2 echo "${USAGE}"
                return 2
            fi
        ;;
        '-L'|'-P')
            if [ $# -eq 3 -a "$3" = '--' ] ; then
                nextDir=$(g_getdir "$2") ; if [ $? -ne 0 ] ; then >&2 echo "${USAGE}" ; return 3 ; fi
                g_cd_wrapper "$1" "${nextDir}"
            else
                >&2 echo "${USAGE}"
                return 4
            fi
        ;;
        '--hooks')
            if [ $# -eq 2 -a "$2" = '--' ] ; then
                readlink -f "$(dirname "${BASH_SOURCE[0]}")/../data/hooks.sh"
                return 0
            else
                >&2 echo "${USAGE}"
                return 5
            fi
        ;;
        '--')
            shift  # get rid of '--'
            #echo "[#:$#][@:$@]"
            if [ $# -eq 0 ] ; then
                nextDir="${HOME}"
                g_cd_wrapper
            elif [ $# -eq 1 ] ; then
                if [ "$1" = '-' ] ; then
                    nextDir="${OLDPWD}"
                    g_cd_wrapper -
                else
                    nextDir=$(g_getdir "$1") ; if [ $? -ne 0 ] ; then >&2 echo "${USAGE}" ;  return 6 ; fi
                    g_cd_wrapper "${nextDir}"
                fi
            else
                >&2 echo "${USAGE}"
                return 7
            fi
        ;;
        *)
            >&2 echo "Unknown [$@]"
            >&2 echo "${USAGE}"
            return 8
        ;;
    esac
}
