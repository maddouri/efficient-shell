
# enable/disable logging
EFFICIENT_SHELL_Verbose=1

# EFFICIENT_SHELL_Log <args...>
# executes `echo <args...>` iff EFFICIENT_SHELL_Verbose is true
alias EFFICIENT_SHELL_Log='test ${EFFICIENT_SHELL_Verbose} && echo -e "EFFICIENT_SHELL:"'

alias EFFICIENT_SHELL_Error='>&2 echo -e "EFFICIENT_SHELL:"'

# path to efficien.sh (i.e. this file)
EFFICIENT_SHELL_MainScript="${BASH_SOURCE}"
if [ ! -f "${EFFICIENT_SHELL_MainScript}" ] ; then
    EFFICIENT_SHELL_Error "EFFICIENT_SHELL_MainScript:[${EFFICIENT_SHELL_MainScript}] is not a script."
    return 1
fi

# root directory of efficient_shell
EFFICIENT_SHELL_Root="$(readlink -f $(dirname ${EFFICIENT_SHELL_MainScript}))"
if [ ! -d "${EFFICIENT_SHELL_Root}" ] ; then
    EFFICIENT_SHELL_Error "EFFICIENT_SHELL_Root:[${EFFICIENT_SHELL_Root}] is not a directory."
    return 2
fi

# the directory where packages are installed
EFFICIENT_SHELL_PackageDirectory="${EFFICIENT_SHELL_Root}/package"
test ! -e "${EFFICIENT_SHELL_PackageDirectory}" && mkdir --parents "${EFFICIENT_SHELL_PackageDirectory}"
if [ ! -d "${EFFICIENT_SHELL_PackageDirectory}" ] ; then
    EFFICIENT_SHELL_Error "EFFICIENT_SHELL_PackageDirectory:[${EFFICIENT_SHELL_PackageDirectory}] is not a directory."
    return 3
fi

# the (preferred) directory where packages store their data
EFFICIENT_SHELL_DataDirectory="${EFFICIENT_SHELL_Root}/data"
test ! -e "${EFFICIENT_SHELL_DataDirectory}" && mkdir --parents "${EFFICIENT_SHELL_DataDirectory}"
if [ ! -d "${EFFICIENT_SHELL_DataDirectory}" ] ; then
    EFFICIENT_SHELL_Error "EFFICIENT_SHELL_DataDirectory:[${EFFICIENT_SHELL_DataDirectory}] is not a directory."
    return 4
fi

# EFFICIENT_SHELL_ForEachPackage <function>
# calls a function for each package directory
# i.e. for each package directory, calls: <function> ${pckDir}
function EFFICIENT_SHELL_ForEachPackage() {
    # function to call
    local func="$1"
    # @todo check the existence/validity of ${func}

    # list of package directories
    #local EFFICIENT_SHELL_PackageDirectories=${EFFICIENT_SHELL_PackageDirectory}/*/

    # call the function on each package directory
    local EFFICIENT_SHELL_ThisPackage
    local EFFICIENT_SHELL_ThisPackageDirectory
    for EFFICIENT_SHELL_ThisPackage in ${EFFICIENT_SHELL_PackageLoadingOrder} ; do
        EFFICIENT_SHELL_ThisPackageDirectory="${EFFICIENT_SHELL_PackageDirectory}/${EFFICIENT_SHELL_ThisPackage}"
        if [ -d "${EFFICIENT_SHELL_ThisPackageDirectory}" ] ; then
            ${func} "${EFFICIENT_SHELL_ThisPackageDirectory}"
        fi
    done
}

# EFFICIENT_SHELL_LoadPackage <pckDir>
# loads a package from the given directory
function EFFICIENT_SHELL_LoadPackage() {
    local pckDir="$1"
    local pckName="$(basename ${pckDir})"

    EFFICIENT_SHELL_Log "loading package [${pckName}]"

    # list the scripts to source
    local scriptDir="${pckDir}/src"
    local scriptFilePattern="*.sh"
    local scriptFiles=$(find "${scriptDir}" -maxdepth 1 -type f -iname "${scriptFilePattern}")

    # is there anything to load ?
    if [ -z "${scriptFiles}" ] ; then
        return 0
    fi

    # load each script
    local scriptFile
    for scriptFile in "${scriptFiles}" ; do
        EFFICIENT_SHELL_Log "loading script  [${pckName} / $(basename ${scriptFile})]"

        source "${scriptFile}"

        EFFICIENT_SHELL_Log "loaded  script  [${pckName} / $(basename ${scriptFile})]"
    done

    EFFICIENT_SHELL_Log "loaded  package [${pckName}]"
}

## EFFICIENT_SHELL_PrintHelp <pckName> <cmdName>
# function EFFICIENT_SHELL_PrintHelp()
# {
#     local pckDir="${EFFICIENT_SHELL_PackageDirectory}/$1"
#     local cmdName="$2"
#
#     local docFile="${pckDir}/doc/${cmdName}.md"
#
#     #
#     #pandoc "${docFile}" | w3m -dump -T text/html | cat
#     cat "${docFile}"
# }

# finds the dependencies between the installed packages
# outputs the dependency graph in ${EFFICIENT_SHELL_DependencyGraph}
# the dependency graph is formatted according to the format accepted by tsort https://en.wikipedia.org/wiki/Tsort
function EFFICIENT_SHELL_BuildDependencyGraph() {
    ## build dependency graph

    # list of package directories
    local EFFICIENT_SHELL_PackageDirectories=${EFFICIENT_SHELL_PackageDirectory}/*/

    # reset dependency graph (global variable)
    EFFICIENT_SHELL_DependencyGraph=""

    # call the function on each package directory
    local EFFICIENT_SHELL_ThisPackageDirectory
    local EFFICIENT_SHELL_ThisPackageName
    local EFFICIENT_SHELL_ThisPackageDependencies
    local EFFICIENT_SHELL_ThisPackageDependencyFile

    for EFFICIENT_SHELL_ThisPackageDirectory in ${EFFICIENT_SHELL_PackageDirectories} ; do
        EFFICIENT_SHELL_ThisPackageDependencyFile="${EFFICIENT_SHELL_ThisPackageDirectory}depend"
        if [ -d "${EFFICIENT_SHELL_ThisPackageDirectory}" ] ; then
            EFFICIENT_SHELL_ThisPackageName=$(basename "${EFFICIENT_SHELL_ThisPackageDirectory}")

            # this package has dependencies
            if [ -f "${EFFICIENT_SHELL_ThisPackageDependencyFile}" ] ; then
                # parse the package's dependency list
                # the goal is get it in the form "dep1 dep2... this_package"
                EFFICIENT_SHELL_ThisPackageDependencies=$(
                    cat "${EFFICIENT_SHELL_ThisPackageDependencyFile}"  |
                    sed -e '/^\s*$/d'                                   |  # remove empty/whitespace lines
                    sed -e 's/^\s*//;s/\s*$//'                          |  # trim leading/trailing spaces
                    sed -e "s/$/ ${EFFICIENT_SHELL_ThisPackageName}/"      # append the package name
                )

                # append the dependency list to the dependency graph
                EFFICIENT_SHELL_DependencyGraph+=$'\n'
                EFFICIENT_SHELL_DependencyGraph+="${EFFICIENT_SHELL_ThisPackageDependencies}"

            # this package doesn't have dependencies
            else
                # https://en.wikipedia.org/wiki/Tsort#Usage_notes
                # Pairs of identical items indicate presence of a vertex, but not ordering
                # (so the following represents one vertex without edges):
                EFFICIENT_SHELL_DependencyGraph+=$'\n'
                EFFICIENT_SHELL_DependencyGraph+="${EFFICIENT_SHELL_ThisPackageName} ${EFFICIENT_SHELL_ThisPackageName}"
            fi
        fi
    done

    #
    EFFICIENT_SHELL_Log "EFFICIENT_SHELL_DependencyGraph:${EFFICIENT_SHELL_DependencyGraph}"
}

# computes the package loading order from the dependency graph generated by EFFICIENT_SHELL_BuildDependencyGraph
# outputs the loading order in ${EFFICIENT_SHELL_PackageLoadingOrder}
function EFFICIENT_SHELL_SolveDependencies() {
    # topological sort of the dependency graph (global variable)
    EFFICIENT_SHELL_PackageLoadingOrder=$(tsort <<< "${EFFICIENT_SHELL_DependencyGraph}")

    EFFICIENT_SHELL_Log "EFFICIENT_SHELL_PackageLoadingOrder:\n$(tr '\n' ' ' <<< ${EFFICIENT_SHELL_PackageLoadingOrder})"
}

# checks that the required packages are actually installed
function EFFICIENT_SHELL_CheckPackages() {
    EFFICIENT_SHELL_MissingPackages=""

    # call the function on each package directory
    local EFFICIENT_SHELL_ThisPackage
    local EFFICIENT_SHELL_ThisPackageDirectory
    for EFFICIENT_SHELL_ThisPackage in ${EFFICIENT_SHELL_PackageLoadingOrder} ; do
        EFFICIENT_SHELL_ThisPackageDirectory="${EFFICIENT_SHELL_PackageDirectory}/${EFFICIENT_SHELL_ThisPackage}"
        if [ -d "${EFFICIENT_SHELL_ThisPackageDirectory}" ] ; then
            EFFICIENT_SHELL_Log "found [${EFFICIENT_SHELL_ThisPackage}]"
        else
            EFFICIENT_SHELL_MissingPackages+=$'\n'
            EFFICIENT_SHELL_MissingPackages+="${EFFICIENT_SHELL_ThisPackage}"
            EFFICIENT_SHELL_Error "missing [${EFFICIENT_SHELL_ThisPackage}]"
        fi
    done

    if [ -n "${EFFICIENT_SHELL_MissingPackages}" ] ; then
        EFFICIENT_SHELL_Error "some packages are missing [$(tr '\n' ' ' <<< ${EFFICIENT_SHELL_MissingPackages})]"
        return 1
    fi

}

# calls EFFICIENT_SHELL_LoadPackage on each package directory
function EFFICIENT_SHELL_LoadPackages {
    EFFICIENT_SHELL_ForEachPackage EFFICIENT_SHELL_LoadPackage
}

# EFFICIENT_SHELL_Init
# initializes the efficiency
function EFFICIENT_SHELL_Init() {
    # build the dependency graph
    EFFICIENT_SHELL_BuildDependencyGraph || return 10

    # compute the package loading order
    EFFICIENT_SHELL_SolveDependencies    || return 11

    # check that all packages are available
    EFFICIENT_SHELL_CheckPackages        || return 12

    # load packages
    EFFICIENT_SHELL_LoadPackages         || return 13
}

# lists the available packages
# @todo fix this
# function lsefficient() {
#     # https://stackoverflow.com/a/2924755/865719
#     local BT=$(tput bold)  # bold text
#     local NT=$(tput sgr0)  # normal text
#
#     echo
#     echo "List of ${BT}efficient-shell${NT} packages"
#     echo
#     #@todo list packages here
#     echo
# }

# init
EFFICIENT_SHELL_Init
