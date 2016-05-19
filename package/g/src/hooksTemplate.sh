
# 1. g_onExit is executed in PWD
# 2. cd to nextDir
# 3. g_onEntry is executed in nextDir

# executed in the current directory before changing to a new
function g_onExit() {  # ${FUNCNAME} <next (new) dir>
    local previousDir="${OLDPWD}"
    local currentDir="${PWD}"
    # next directory (will cd there when this function returns successfully)
    local nextDir="$1"

    #echo "Exiting [${currentDir}], Entering [${nextDir}]"
}

# executed after cd-ing to a new directory
function g_onEntry() {  # ${FUNCNAME}
    local previousDir="${OLDPWD}"
    local currentDir="${PWD}"

    #echo "Exited [${previousDir}], Entered [${currentDir}]"
}


