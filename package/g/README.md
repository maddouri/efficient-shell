
# NAME

`g` - go, a better `cd`

# SYNOPSIS

    g
    g [-L|-P] path
    g -
    g --hooks
    g -h|--help

# DESCRIPTION

`g` uses `cd` to change the working directory.

`g` accepts the same arguments as `cd` with one exception:
`path` can be either a directory or a file path:

* If `path` is a directory, then `g path` has the same behavior as `cd path`.
* If `path` is a file, then `g` has the same behavior as `cd "$(dirname path)"`

In addition to that, it is also possible to define _hooks_ which are functions
that are called when changing directories. There are currently 2 editable hooks:

* `g_onExit`  is executed in the current directory before changing to a new one
* `g_onEntry` is executed in the new directory after changing to a it

# OPTIONS

* `-`, `-L`, `-P`, no arguments : same behavior as `cd`
* `--hooks`                     : prints the path of the _hooks_ file
* `--help`, `-h`                : shows this help

# FILES

* `<INSTALL_DIR>/data/hooks.sh`
    * the _hooks_ file, contains the `g_onExit` and `g_onEntry` hooks

# SEE ALSO

    cd

# AUTHOR

Written by **Mohamed-Yassine MADDOURI**
