
# enable/disable logging
EFFICIENT_SHELL_Verbose=1

# EFFICIENT_SHELL_Log <args...>
# executes `echo <args...>` iff EFFICIENT_SHELL_Verbose is true
alias EFFICIENT_SHELL_Log='test ${EFFICIENT_SHELL_Verbose} && echo -e "EFFICIENT_SHELL:"'

alias EFFICIENT_SHELL_Error='>&2 echo -e "EFFICIENT_SHELL @ ${FUNCNAME}:"'

# path to efficient.sh (i.e. this file)
EFFICIENT_SHELL_MainScript=$(readlink -f "${BASH_SOURCE[0]}")
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

# package list
EFFICIENT_SHELL_Packages=""

# the package config file that has to be present in the package directory
EFFICIENT_SHELL_PackageConfigFileName="efficient.cfg"
# package properties (to put in the config file)
EFFICIENT_SHELL_PackageConfigProperty_Name="name"          # package name (not required to be the same as the package directory's)
EFFICIENT_SHELL_PackageConfigProperty_Main="main"          # main file to `source`
EFFICIENT_SHELL_PackageConfigProperty_Depend="depend"      # (optional) space-separated list of packages on which the package depends
# other properties (deduced/don't appear in the config file)
EFFICIENT_SHELL_PackageConfigProperty_Directory="dir"      # package directory
EFFICIENT_SHELL_PackageConfigProperty_ConfigFile="config"  # config file path

# helpful functions for processing whitespace
# @note use with pipes
function EFFICIENT_SHELL_FactorSpaces() {
    sed -e 's/[[:space:]]\+/ /g'
}
function EFFICIENT_SHELL_TrimSpaces() {
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}
function EFFICIENT_SHELL_FactorAndTrimSpaces() {
    sed -e 's/[[:space:]]\+/ /g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# EFFICIENT_SHELL_ForEachPackage <function>
# calls <function> for each package directory
# i.e. for each package directory, executes: <function> ${pckDir}
function EFFICIENT_SHELL_ForEachPackage() {
    # function to call
    local func="$1"
    # @todo check the existence/validity of ${func}

    # list of package directories
    #local EFFICIENT_SHELL_PackageDirectories=${EFFICIENT_SHELL_PackageDirectory}/*/

    # call the function on each package directory
    local thisPackage
    local packageDirectory
    for thisPackage in ${EFFICIENT_SHELL_PackageLoadingOrder} ; do
        packageDirectory="${EFFICIENT_SHELL_PackageDirectory}/${thisPackage}"
        if [ -d "${packageDirectory}" ] ; then
            ${func} "${packageDirectory}"
        else
            EFFICIENT_SHELL_Error "Failed to access package [${thisPackage}]: directory [${packageDirectory}] not found"
            return 1
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

function EFFICIENT_SHELL_GetPackageInfo_FromConfigFile() {  # ${FUNCNAME} <configFile> <infoName>
    local configFile="$1"
    local infoName="$2"

    if [ -f "${configFile}" ] ; then
        # special cases
        # if the info is the path of the config file itself
        if [ "${infoName}" = "${EFFICIENT_SHELL_PackageConfigProperty_Directory}" ] ; then
            echo $(dirname $(readlink -f "${configFile}"))
            return 0
        elif [ "${infoName}" = "${EFFICIENT_SHELL_PackageConfigProperty_ConfigFile}" ] ; then
            echo $(readlink -f "${configFile}")
            return 0
        fi

        # find the <infoName> field and filter out <infoName> and any quotes surrounding the info
        # input : <infoName>="<info>" | <infoName>='<info>' | <infoName> = '<info>' | ...
        # output: <info>
        local info=$(
            grep "${infoName}" "${configFile}" |                # find the property
            tail -n 1 |                                     # keep the last occurence (robustness to (erroneous) multiple definitions)
            sed 's/^[^=]*=\s*["\x27]\(.*\)["\x27]\s*$/\1/'  # filter out <infoName>, =, " or ' and any extra spaces
        )
        if [ -n "${info}" ] ; then
            echo "${info}"
        else
            # fail silenty
            echo ''
            #EFFICIENT_SHELL_Error "[infoName:${infoName}] not found in [configFile:${configFile}]"
            #return 2
        fi
    else
        EFFICIENT_SHELL_Error "Config file not found for [${pckDir}]"
        return 1;
    fi
}

function EFFICIENT_SHELL_ListPackages() {  # ${FUNCNAME} <fields> [<field>...]
    #local columnSeparator=","
    local columnSeparator=$'\t'
    local resultString=""
    local configFiles="${EFFICIENT_SHELL_PackageDirectory}/*/${EFFICIENT_SHELL_PackageConfigFileName}"
    for config in ${configFiles} ; do
        local infoName
        for infoName in "$@" ; do
            local info=$(EFFICIENT_SHELL_GetPackageInfo_FromConfigFile "${config}" "${infoName}")
            if [ -n "${info}" ] ; then
                resultString+="${info}${columnSeparator}"
            else
                # fail silenty
                resultString+="${columnSeparator}"
                #EFFICIENT_SHELL_Error "Configuration problem in [config:${config}}"
                #return 1
            fi
        done
        # add '\n' to the last field
        resultString+=$'\n'
    done
    echo "${resultString}"
    # https://stackoverflow.com/a/3800791/865719
    # column is not installed by default, sudo apt-get install bsdmainutils
    #echo "${resultString}" | column -s, -t
}

function EFFICIENT_SHELL_GetPackageInfo() {  # ${FUNCNAME} <pckName> [<infoName>]
    local pckName="$1"
    local infoName="$2"
    if [ -n "${infoName}" ] ; then
        local info=$(
            EFFICIENT_SHELL_ListPackages "${EFFICIENT_SHELL_PackageConfigProperty_Name}" "${infoName}" |
            grep "^\s*${pckName}"   |
            sed -e "s/${pckName}//" |
            EFFICIENT_SHELL_TrimSpaces
        )
        echo "${info}"
    else
        local infos=$(
            EFFICIENT_SHELL_ListPackages "${EFFICIENT_SHELL_PackageConfigProperty_Name}" "${EFFICIENT_SHELL_PackageConfigProperty_Main}" "${EFFICIENT_SHELL_PackageConfigProperty_Depend}" "${EFFICIENT_SHELL_PackageConfigProperty_Directory}" |
            grep "${pckName}"
        )
        echo "${infos}"
    fi
}

# generates a list of installed packages in EFFICIENT_SHELL_Packages:
#  pck1
#  pck2
#  ...
function EFFICIENT_SHELL_CreatePackageList() {
    EFFICIENT_SHELL_Packages=$(
        EFFICIENT_SHELL_ListPackages "name" |  # get the package list
        EFFICIENT_SHELL_FactorAndTrimSpaces
    )
    EFFICIENT_SHELL_Log "EFFICIENT_SHELL_Packages:\n$(tr '\n' ' ' <<< ""${EFFICIENT_SHELL_Packages}"")"
}

# finds the dependencies between the installed packages
# outputs the dependency graph in EFFICIENT_SHELL_DependencyGraph
# the dependency graph is formatted according to the format accepted by tsort https://en.wikipedia.org/wiki/Tsort
function EFFICIENT_SHELL_BuildDependencyGraph() {
    # reset dependency graph (global variable)
    EFFICIENT_SHELL_DependencyGraph=""

    local pckName
    for pckName in ${EFFICIENT_SHELL_Packages} ; do

        #EFFICIENT_SHELL_Log "Processing [${pckName}]"

        # get the dependency list in the form "dep1 dep2 ..."
        # this way, it can be iterated over
        local pckDepend=$(
            EFFICIENT_SHELL_GetPackageInfo "${pckName}" "${EFFICIENT_SHELL_PackageConfigProperty_Depend}"  |
            sed -e "s/${pckName}//" |
            EFFICIENT_SHELL_FactorAndTrimSpaces
        )

        #EFFICIENT_SHELL_Log "pckDepend [${pckDepend}]"

        # this package has dependencies
        if [ -n "${pckDepend}" ] ; then
            # parse the package's dependency list
            # the goal is get it in the form:
            #   dep1 this_package
            #   dep2 this_package
            #   ...
            for d in ${pckDepend} ; do  # don't use "${depend}"  (i.e. no quotes)
                # append the dependency list to the dependency graph
                EFFICIENT_SHELL_DependencyGraph+=$'\n'"${d} ${pckName}"
            done
        # this package doesn't have dependencies
        else
            # https://en.wikipedia.org/wiki/Tsort#Usage_notes
            # Pairs of identical items indicate presence of a vertex, but not ordering
            # (so the following represents one vertex without edges):
            EFFICIENT_SHELL_DependencyGraph+=$'\n'"${pckName} ${pckName}"
        fi

    done

    #
    EFFICIENT_SHELL_Log "EFFICIENT_SHELL_DependencyGraph:${EFFICIENT_SHELL_DependencyGraph}"
}

# computes the package loading order from the dependency graph generated by EFFICIENT_SHELL_BuildDependencyGraph
# outputs the loading order in ${EFFICIENT_SHELL_PackageLoadingOrder}
function EFFICIENT_SHELL_SolveDependencies() {
    # @TODO reduce dependency to external tools by replacing tsort with pure-shell implementation
    # http://rosettacode.org/wiki/Topological_sort#UNIX_Shell

    # topological sort of the dependency graph (global variable)
    EFFICIENT_SHELL_PackageLoadingOrder=$(tsort <<< "${EFFICIENT_SHELL_DependencyGraph}")

    EFFICIENT_SHELL_Log "EFFICIENT_SHELL_PackageLoadingOrder:\n$(tr '\n' ' ' <<< ${EFFICIENT_SHELL_PackageLoadingOrder})"
}

# checks that the required packages are actually installed
function EFFICIENT_SHELL_CheckPackages() {
    EFFICIENT_SHELL_MissingPackages=""

    # call the function on each package directory
    local pckName
    for pckName in ${EFFICIENT_SHELL_PackageLoadingOrder} ; do
        local pckInfo=$(EFFICIENT_SHELL_GetPackageInfo "${pckName}")
        if [ ! -n "${pckInfo}" ] ; then
            EFFICIENT_SHELL_MissingPackages+=$'\n'
            EFFICIENT_SHELL_MissingPackages+="${pckName}"
            EFFICIENT_SHELL_Error "missing [${pckName}]"
        fi
    done

    if [ -n "${EFFICIENT_SHELL_MissingPackages}" ] ; then
        EFFICIENT_SHELL_Error "some packages are missing [$(tr '\n' ' ' <<< ${EFFICIENT_SHELL_MissingPackages})]"
        return 1
    fi
}

# loads the packages in the order specified in EFFICIENT_SHELL_PackageLoadingOrder
function EFFICIENT_SHELL_LoadPackages() {
    local pckName
    for pckName in ${EFFICIENT_SHELL_PackageLoadingOrder} ; do
        local pckDir=$(EFFICIENT_SHELL_GetPackageInfo "${pckName}" "${EFFICIENT_SHELL_PackageConfigProperty_Directory}")
        local pckMainInfo=$(EFFICIENT_SHELL_GetPackageInfo "${pckName}" "${EFFICIENT_SHELL_PackageConfigProperty_Main}")
        local pckMain="${pckDir}/${pckMainInfo}"

        EFFICIENT_SHELL_Log "loading [${pckName}]"
        if [ -f "${pckMain}" ] ; then
            source "${pckMain}"
        else
            EFFICIENT_SHELL_Error "[pckMain:${pckMain}] not found"
            return 1
        fi
        EFFICIENT_SHELL_Log "loaded  [${pckName}]"
    done
}


# initializes the efficiency!
function EFFICIENT_SHELL_Init() {
    # populate EFFICIENT_SHELL_Packages
    EFFICIENT_SHELL_CreatePackageList    || return 10

    # build the dependency graph
    EFFICIENT_SHELL_BuildDependencyGraph || return 11

    # compute the package loading order
    EFFICIENT_SHELL_SolveDependencies    || return 12

    # check that all packages are available
    EFFICIENT_SHELL_CheckPackages        || return 13

    # load packages
    EFFICIENT_SHELL_LoadPackages         || return 14
}

# init
EFFICIENT_SHELL_Init
