
# NAME

`g` - go, a better `cd`

# SYNOPSIS

    g
    g [-L|-P] path
    g -
    g -h|--help

# DESCRIPTION

`g` uses `cd` to change the working directory.

`g` accepts the same arguments as `cd` with one exception:
`path` can be either a directory or a file path.

* If `path` is a directory, then `g path` has the same behavior as `cd path`.
* If `path` is a file, then `g` has the same behavior as `cd "$(dirname path)"`

# OPTIONS

* `-`, `-L`, `-P`, no arguments : same behavior as `cd`
* `--help`, `-h`                : shows this help

# SEE ALSO

    cd

# AUTHOR

Written by **Mohamed-Yassine MADDOURI**
