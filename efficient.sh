#!/usr/bin/env bash

# @TODO submit to https://curlpipesh.tumblr.com/

# indicate that efficient-shell is available
readonly EFFICIENT_SHELL=1

# enable/disable logging
export EFFICIENT_SHELL_Verbose=1

# EFFICIENT_SHELL_Log <args...>
# executes `echo <args...>` iff EFFICIENT_SHELL_Verbose is true
#alias EFFICIENT_SHELL_Log='test ${EFFICIENT_SHELL_Verbose} && echo -e "EFFICIENT_SHELL:"'
function EFFICIENT_SHELL_Log() {
    test ${EFFICIENT_SHELL_Verbose} && echo -e "EFFICIENT_SHELL: $@"
}
# prints error messages to stderr
#alias EFFICIENT_SHELL_Error='>&2 echo -e "EFFICIENT_SHELL @ ${FUNCNAME}:"'
function EFFICIENT_SHELL_Error() {
    >&2 echo -e "EFFICIENT_SHELL @ ${FUNCNAME[1]}: $@"
}

# path to efficient.sh (i.e. this file)
readonly EFFICIENT_SHELL_MainScript="$(readlink -f "${BASH_SOURCE[0]}")"
if [ ! -f "${EFFICIENT_SHELL_MainScript}" ] ; then
    EFFICIENT_SHELL_Error "EFFICIENT_SHELL_MainScript:[${EFFICIENT_SHELL_MainScript}] is not a script."
    return 1
fi

# root directory of efficient_shell
readonly EFFICIENT_SHELL_Root="$(readlink -f "$(dirname "${EFFICIENT_SHELL_MainScript}")")"
if [ ! -d "${EFFICIENT_SHELL_Root}" ] ; then
    EFFICIENT_SHELL_Error "EFFICIENT_SHELL_Root:[${EFFICIENT_SHELL_Root}] is not a directory."
    return 2
fi

# the directory where packages are installed
readonly EFFICIENT_SHELL_PackageDirectory="${EFFICIENT_SHELL_Root}/package"
test ! -e "${EFFICIENT_SHELL_PackageDirectory}" && mkdir --parents "${EFFICIENT_SHELL_PackageDirectory}"
if [ ! -d "${EFFICIENT_SHELL_PackageDirectory}" ] ; then
    EFFICIENT_SHELL_Error "EFFICIENT_SHELL_PackageDirectory:[${EFFICIENT_SHELL_PackageDirectory}] is not a directory."
    return 3
fi

# the (preferred) directory where packages store their data
readonly EFFICIENT_SHELL_DataDirectory="${EFFICIENT_SHELL_Root}/data"
test ! -e "${EFFICIENT_SHELL_DataDirectory}" && mkdir --parents "${EFFICIENT_SHELL_DataDirectory}"
if [ ! -d "${EFFICIENT_SHELL_DataDirectory}" ] ; then
    EFFICIENT_SHELL_Error "EFFICIENT_SHELL_DataDirectory:[${EFFICIENT_SHELL_DataDirectory}] is not a directory."
    return 4
fi

# the package config file that has to be present in the package directory
readonly EFFICIENT_SHELL_PackageConfigFileName="efficient.cfg"
# package properties (to put in the config file)
readonly EFFICIENT_SHELL_PackageConfigProperty_Name="name"          # package name (not required to be the same as the package directory's)
readonly EFFICIENT_SHELL_PackageConfigProperty_Main="main"          # main file to `source`
readonly EFFICIENT_SHELL_PackageConfigProperty_Depend="depend"      # space-separated list of packages on which the package depends
# other properties (deduced/don't appear in the config file)
readonly EFFICIENT_SHELL_PackageConfigProperty_Directory="dir"      # package directory
readonly EFFICIENT_SHELL_PackageConfigProperty_ConfigFile="config"  # config file path

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

# print aligned columns from CSV-like, multiline string
# (almost) pure-shell script replacement for `column` from `bsdmainutils`
# requires [head, grep, wc, sed, awk] which should be available everywhere
function EFFICIENT_SHELL_Columnize() {  # <inputMultilineString> <inputColumnSeparator> [<outputColumnSeparator>]
    # read input
    local inputString="$1"
    local sep="$2"
    local outputFieldSeparator=' '
    [ -n "$3" ] && outputFieldSeparator="$3"

    # compute the number of columns -- i.e. fields
    # https://stackoverflow.com/a/16679640/865719
    local sepCount
    local colCount
    sepCount="$(head -n 1 <<< "${inputString}" | grep -o "${sep}" | wc -l)"
    colCount=$((sepCount+1))
    #echo "colCount:$colCount"

    # compute the maximum width of each column
    local colNum
    local colWidths=()
    for ((colNum=1; colNum<=colCount; colNum++)) ; do
        local fieldColumn
        fieldColumn="$(awk -F "${sep}" '{print $'"${colNum}"'}' <<< "${inputString}")"  # http://www.joeldare.com/wiki/using_awk_on_csv_files
        # length of the longest line
        colWidths+=( $(
            IFS=$'\n';  # https://stackoverflow.com/a/8768435/865719
            lines=( $(echo "${fieldColumn}") );
            maxLen=0;
            for line in "${lines[@]}" ; do
                if [ ${#line} -gt ${maxLen} ] ; then maxLen=${#line}; fi;
            done;
            echo "${maxLen}";
        ) )
    done
    #echo "colWidths:${colWidths[@]}"

    # print each field of each line using the information of maximum width
    (
        local outputString=""
        local IFS=$'\n'
        local line
        local lines
        lines=( $(echo "${inputString}") )
        for line in "${lines[@]}" ; do
            #echo "[${line}]"
            local colNum
            local outputLine=""
            for ((colNum=1; colNum<=colCount; colNum++)) ; do
                local field
                field="$(awk -F "${sep}"  '{print $'"${colNum}"'}' <<< "${line}")"
                outputLine+="$(printf "%-${colWidths[colNum-1]}s%s" "${field}" "${outputFieldSeparator}")"
            done
            # remove the last (unnecessary) separator (@see the for printf above for why it is unnecessary)
            outputLine="$(sed 's/'"${outputFieldSeparator}"'$//' <<< "${outputLine}")"
            outputLine+=$'\n'
            outputString+="${outputLine}"
        done

        echo -n "${outputString}"
    )
}

# reads the provided <configFile> and prints out an associative array
# representing the `<property>="<value>"` structure of the file
# e.g. For package/j/efficient.cfg, this function outputs the following string:
#   declare -A properties='([depend]="g" [name]="j" [config]="/efficient-shell/package/j/efficient.cfg" [main]="src/j.sh" [dir]="/efficient-shell/package/j" )'
# The above string DOES contain `declare -A properties=...`
# This is a trick to "return" an associative array from a function
# Therefore, to "get" the returned array, the caller has to use the `eval` command
# e.g. The following code calls EFFICIENT_SHELL_ParseConfigFile then
# creates the `properties` array from the its output:
#   local pckInfo="$(EFFICIENT_SHELL_ParseConfigFile "${configFilePath}")"
#   eval "declare -A properties=${pckInfo#*=}"
function EFFICIENT_SHELL_ParseConfigFile() {  # <configFile>
    local configFile="$1"
    if [ -f "${configFile}" ] ; then
        # use an associative array
        declare -A properties

        # special info
        properties["${EFFICIENT_SHELL_PackageConfigProperty_Directory}"]="$(dirname "$(readlink -f "${configFile}")")"
        properties["${EFFICIENT_SHELL_PackageConfigProperty_ConfigFile}"]="$(readlink -f "${configFile}")"

        # info in the config file
        local infoName
        for infoName in $EFFICIENT_SHELL_PackageConfigProperty_{Name,Main,Depend} ; do
            # find the <infoName> field and filter out <infoName> and any quotes surrounding the info
            # input : <infoName>="<info>" | <infoName>='<info>' | <infoName> = '<info>' | ...
            # output: <info>
            properties["${infoName}"]="$(
                grep "${infoName}" "${configFile}" |            # find the property
                tail -n 1 |                                     # keep the last occurence (robustness to (erroneous) multiple definitions)
                sed 's/^[^=]*=\s*["\x27]\(.*\)["\x27]\s*$/\1/'  # filter out <infoName>, =, " or ' and any extra spaces
            )"
        done

        # return the data
        declare -p properties
    else
        EFFICIENT_SHELL_Error "Config file not found for [${configFile}]"
        return 1;
    fi
}

# Outputs the list of installed packages alon with their properties
# Valid properties are EFFICIENT_SHELL_PackageConfigProperty_*
# If no <field> is provied, this function prints all the properties of all packags
function EFFICIENT_SHELL_ListPackages() {  # [<field>...]
    # print all fields by default
    [ $# -eq 0 ] && eval set -- "$(echo $EFFICIENT_SHELL_PackageConfigProperty_{Name,Main,Depend,Directory,ConfigFile})"

    # validate that $@ contains words from EFFICIENT_SHELL_PackageConfigProperty_*
    local infoName
    for infoName in "$@" ; do
        echo $EFFICIENT_SHELL_PackageConfigProperty_{Name,Main,Depend,Directory,ConfigFile} | grep -q "\b${infoName}\b"
        if [ $? -ne 0 ] ; then
            EFFICIENT_SHELL_Error "Valid fields:" $EFFICIENT_SHELL_PackageConfigProperty_{Name,Main,Depend,Directory,ConfigFile}
            return 1
        fi
    done

    #local columnSeparator=","
    local columnSeparator=$'\t'
    local resultString=""
    local configFiles="${EFFICIENT_SHELL_PackageDirectory}/*/${EFFICIENT_SHELL_PackageConfigFileName}"
    for config in ${configFiles} ; do
        local infoName
        local resultLine=""
        local pckInfo
        pckInfo="$(EFFICIENT_SHELL_ParseConfigFile "${config}")"
        eval "declare -A properties=${pckInfo#*=}"
        for infoName in "$@" ; do
            resultLine+="${properties[${infoName}]}${columnSeparator}"
        done
        # remove the last (unnecessary) separator (@see above for why it is unnecessary)
        resultLine=$(sed 's/'"${columnSeparator}"'$//' <<< "${resultLine}")
        #EFFICIENT_SHELL_Error "resultString[${resultString}]"
        # add '\n' to the last field and go to the next entry/line
        resultLine+=$'\n'
        resultString+="${resultLine}"
    done

    #echo "${resultString}"

    # https://stackoverflow.com/a/3800791/865719
    # column is not installed by default, sudo apt-get install bsdmainutils
    #echo "${resultString}" | column -s"${columnSeparator}" -t

    # pretty print the fields in aligned columns
    EFFICIENT_SHELL_Columnize "${resultString}" "${columnSeparator}" "  "
}

# Returns 0 if the <pckName> exists and 1 otherwise
function EFFICIENT_SHELL_PackageInstalled() {  # <pckName>
    if [ $# -ne 1 ] ; then
        EFFICIENT_SHELL_Error "Expected <pckName>, received [$@]"
        return 2
    fi

    local pckName="$1"
    local outputString=""
    outputString="$(
        EFFICIENT_SHELL_ListPackages "${EFFICIENT_SHELL_PackageConfigProperty_Name}"  |
        grep "^\s*${pckName}"  |
        EFFICIENT_SHELL_TrimSpaces
    )"

    test -n "${outputString}"
    return $?
}

# Outputs information about a given package
function EFFICIENT_SHELL_GetPackageInfo() {  # <pckName> [<infoName>]
    local pckName="$1"
    local infoName="$2"

    local outputString=""
    # if a specific property name has been provided, print it
    if [ -n "${infoName}" ] ; then
        outputString="$(
            EFFICIENT_SHELL_ListPackages "${EFFICIENT_SHELL_PackageConfigProperty_Name}" "${infoName}" |
            grep "^\s*${pckName}"   |
            sed -e "s/${pckName}//" |
            EFFICIENT_SHELL_TrimSpaces
        )"
    # if no property name has been provided, print all of them
    else
        outputString="$(EFFICIENT_SHELL_ListPackages | grep "^\s*${pckName}")"
    fi

    echo "${outputString}"
}

# generates a list of installed packages in EFFICIENT_SHELL_Packages:
#  pck1
#  pck2
#  ...
function EFFICIENT_SHELL_CreatePackageList() {
    EFFICIENT_SHELL_ListPackages "${EFFICIENT_SHELL_PackageConfigProperty_Name}" |\
    EFFICIENT_SHELL_FactorAndTrimSpaces
}

# finds the dependencies between the installed packages
# outputs the dependency graph in EFFICIENT_SHELL_DependencyGraph
# the dependency graph is formatted according to the format accepted by tsort https://en.wikipedia.org/wiki/Tsort
function EFFICIENT_SHELL_BuildDependencyGraph() {  # <pck> [<pck>...]
    local dependencyGraph=""

    local pckName
    for pckName in "$@" ; do

        #EFFICIENT_SHELL_Log "Processing [${pckName}]"

        # get the dependency list in the form "dep1 dep2 ..."
        # this way, it can be iterated over
        local pckDepend
        pckDepend="$(
            EFFICIENT_SHELL_GetPackageInfo "${pckName}" "${EFFICIENT_SHELL_PackageConfigProperty_Depend}"  |
            sed -e "s/${pckName}//" |
            EFFICIENT_SHELL_FactorAndTrimSpaces
        )"

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
                dependencyGraph+=$'\n'"${d} ${pckName}"
            done
        # this package doesn't have dependencies
        else
            # https://en.wikipedia.org/wiki/Tsort#Usage_notes
            # Pairs of identical items indicate presence of a vertex, but not ordering
            # (so the following represents one vertex without edges):
            dependencyGraph+=$'\n'"${pckName} ${pckName}"
        fi
    done

    echo "${dependencyGraph}"
}

# computes the package loading order from the dependency graph generated by EFFICIENT_SHELL_BuildDependencyGraph
# outputs the loading order in ${EFFICIENT_SHELL_PackageLoadingOrder}
function EFFICIENT_SHELL_SolveDependencies() {  # <dependencyGraph>
    local dependencyGraph="$1"

    # @TODO reduce dependency to external tools by replacing tsort with pure-shell implementation
    # http://rosettacode.org/wiki/Topological_sort#UNIX_Shell

    # topological sort of the dependency graph
    tsort <<< "${dependencyGraph}"
}

# checks that the required packages are actually installed
function EFFICIENT_SHELL_CheckPackages() {  # <pck> [<pck>...]
    local missingPackages=""

    # call the function on each package directory
    local pckName
    for pckName in "$@" ; do
        if ! EFFICIENT_SHELL_PackageInstalled "${pckName}" ; then
            missingPackages+=$'\n'"${pckName}"
        fi
    done

    if [ -n "${missingPackages}" ] ; then
        EFFICIENT_SHELL_Error "some packages are missing [$(tr '\n' ' ' <<< "${missingPackages}")]"
        echo "${missingPackages}"
        return 1
    fi
}

# loads the packages in the order specified in EFFICIENT_SHELL_PackageLoadingOrder
function EFFICIENT_SHELL_LoadPackages() {  # <pck> [<pck>...]
    local pckName
    for pckName in "$@" ; do
        local pckDir
        local pckMainInfo
        local pckMain
        pckDir="$(EFFICIENT_SHELL_GetPackageInfo "${pckName}" "${EFFICIENT_SHELL_PackageConfigProperty_Directory}")"
        pckMainInfo="$(EFFICIENT_SHELL_GetPackageInfo "${pckName}" "${EFFICIENT_SHELL_PackageConfigProperty_Main}")"
        pckMain="${pckDir}/${pckMainInfo}"

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

    # package list
    # Deduced from the packages in EFFICIENT_SHELL_PackageDirectory
    # Format
    #   pck1
    #   pck2
    #   ...
    local EFFICIENT_SHELL_Packages=""
    # populate EFFICIENT_SHELL_Packages
    EFFICIENT_SHELL_Packages="$(EFFICIENT_SHELL_CreatePackageList)"
    [ $? -ne 0 ] && return 10
    EFFICIENT_SHELL_Log "EFFICIENT_SHELL_Packages:\n$(tr '\n' ' ' <<< "${EFFICIENT_SHELL_Packages}")"

    # dependency graph
    # Has a format compatible with the `tsort` command: https://en.wikipedia.org/wiki/Tsort#Usage_notes
    # e.g. If there are 2 packages -- pck_a and pck_b -- that are to be loaded
    # and pck_a depends on pck11 and pck12
    # and pck_b depends on pck_a and pck_x
    # and pck_c doesn't depend on any other package
    # then the dependency graph should be:
    #   pck11 pck_a
    #   pck12 pck_a
    #   pck_a pck_b
    #   pck_x pck_b
    #   pck_c pck_c
    # Note that pck11, pck12 and pck_x have to be installed as well
    # Therefore, the dependency graph is actually: (assuming pck11, pck12 and pck_x don't depend on other packages)
    #   pck11 pck_a
    #   pck12 pck_a
    #   pck_a pck_b
    #   pck_x pck_b
    #   pck_c pck_c
    #   pck11 pck11
    #   pck12 pck12
    #   pck_x pck_x
    # Note that the order doesn't matter
    local EFFICIENT_SHELL_DependencyGraph=""
    # build the dependency graph
    EFFICIENT_SHELL_DependencyGraph="$(EFFICIENT_SHELL_BuildDependencyGraph $(tr '\n' ' ' <<<"${EFFICIENT_SHELL_Packages}"))"
    [ $? -ne 0 ] && return 11
    EFFICIENT_SHELL_Log "EFFICIENT_SHELL_DependencyGraph:${EFFICIENT_SHELL_DependencyGraph}"

    # the package list, sorted by the order in which the packages are to be loaded
    # This is the results of `tsort <<< "${EFFICIENT_SHELL_DependencyGraph}"`
    # e.g. The package loading order of the example illustrated in EFFICIENT_SHELL_DependencyGraph is:
    #   pck11
    #   pck12
    #   pck_c
    #   pck_x
    #   pck_a
    #   pck_b
    local EFFICIENT_SHELL_PackageLoadingOrder=""
    # compute the package loading order
    EFFICIENT_SHELL_PackageLoadingOrder="$(EFFICIENT_SHELL_SolveDependencies "${EFFICIENT_SHELL_DependencyGraph}")"
    [ $? -ne 0 ] && return 12
    EFFICIENT_SHELL_Log "EFFICIENT_SHELL_PackageLoadingOrder:\n$(tr '\n' ' ' <<< "${EFFICIENT_SHELL_PackageLoadingOrder}")"

    # the list of missing dependencies
    # If, when loading packages, (in the order specified in EFFICIENT_SHELL_PackageLoadingOrder)
    # a package is not found, then its name is added to EFFICIENT_SHELL_MissingPackages
    local EFFICIENT_SHELL_MissingPackages=""
    # check that all packages are available
    EFFICIENT_SHELL_MissingPackages="$(EFFICIENT_SHELL_CheckPackages $(tr '\n' ' ' <<< "${EFFICIENT_SHELL_PackageLoadingOrder}"))"
    [ $? -ne 0 ] && return 13
    EFFICIENT_SHELL_Log "Found all packages"

    # load packages
    EFFICIENT_SHELL_LoadPackages $(tr '\n' ' ' <<< "${EFFICIENT_SHELL_PackageLoadingOrder}")
    [ $? -ne 0 ] && return 14
    EFFICIENT_SHELL_Log "Ready to go!"
}

# init
EFFICIENT_SHELL_Init
