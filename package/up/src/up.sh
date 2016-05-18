
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
                    if [ "${arg}" -lt 1 ] ; then
                        >&2 echo "[LEVEL_COUNT:${arg}] must be >= 1"
                        >&2 echo "${USAGE}"
                        return 2
                    fi
                    # https://stackoverflow.com/a/17030976/865719
                    destination="$(printf "%0.s../" "$(seq 1 "${arg}")")"
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
