
function g_init() {
    local pckRoot="$(dirname "${BASH_SOURCE[0]}")/.."
    local pckSrc="${pckRoot}/src"
    local pckData="${pckRoot}/data"
    local hooksTemplate="${pckSrc}/hooksTemplate.sh"
    local userHooks="${pckData}/hooks.sh"

    if [ ! -f "${userHooks}" ] ; then
        mkdir -p "${pckData}"
        cp "${hooksTemplate}" "${userHooks}"
    fi

    source "${userHooks}"
    source "${pckSrc}/g.sh"
}

g_init
