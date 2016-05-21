
# go UP in the current directory hierarchy
function up() {

    local USAGE
    read -r -d '' USAGE << EndOfUsage
Usage:
    up
    up LEVEL_COUNT
    up DIRECTORY_NAME
    up --help|-h
EndOfUsage

    local destination=""

    # @TODO fix bug when DIRECTORY_NAME is a number (e.g. allow adding / to the name ?)

    case "$#" in
        '0')
            destination=".."
        ;;
        '1')
            local arg="$1"
            # https://stackoverflow.com/a/3951175/865719
            case "${arg}" in
                '--help'|'-h')
                    cat "$(dirname "${BASH_SOURCE[0]}")/../README.md"
                    return 0
                ;;
                *[!0-9]*)  # not a number
                    # don't do anything if requesting to cd to the current directory
                    [ "${arg}" == "$(basename "${PWD}")" ] && return 0

                    # find the last occurence of "${arg}"
                    # @TODO we should have some autocomletion for this
                    # @TODO switch the sed regex separator from / to something else if arg contains /
                    destination="$(sed -n "s/^\(.*\\/${arg}\)\\/.*$/\1/p" <<< "${PWD}")"
                    if [ -z "${destination}" ] ; then
                        >&2 echo "[DIRECTORY_NAME:${arg}] not found in current path [PWD:${PWD}]"
                        >&2 echo "${USAGE}"
                        return 1
                    fi
                ;;
                *)  # number
                    if [ "${arg}" -lt 0 ] ; then
                        >&2 echo "[LEVEL_COUNT:${arg}] must be >= 1"
                        >&2 echo "${USAGE}"
                        return 2
                    fi

                    # don't do anything if requesting to cd to the current directory
                    [ "${arg}" -eq 0 ] && return 0

                    # https://stackoverflow.com/a/17030976/865719
                    destination="$(printf "%0.s../" $(seq 1 ${arg}))"
                ;;
            esac
        ;;
        *)
            >&2 echo "${USAGE}"
            return 3
        ;;
    esac

    cd "${destination}"
}

up_ProgrammableCompletion() {

    local current_index=${COMP_CWORD}
    local current_word="${COMP_WORDS[COMP_CWORD]}"
    local previous_word="${COMP_WORDS[COMP_CWORD-1]}"

    local candidate_list

    # option
    if [ ${current_index} -eq 1 ] && [[ "${current_word}" == -* ]] ; then
        candidate_list="--help -h"
        COMPREPLY=($(compgen -W "${candidate_list}" -- "${current_word}"))
    # get list of directories forming the current path
    elif [ ${current_index} -eq 1 ] ; then
        # '/curent/working/directory/path' > "'curent' 'working' 'directory' 'path'"
        candidate_list="$(IFS=$'\n' sed -e 's:/:\n:g' <<< "${PWD}")"
        COMPREPLY=($(compgen -W "${candidate_list}" -- "${current_word}"))
    fi

    return 0
}

# register j_ProgrammableCompletion to provide completion for j
complete -F up_ProgrammableCompletion up
