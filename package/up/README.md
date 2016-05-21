
# NAME

`up` - go UP in the current directory hierarchy

# SYNOPSIS

    up
    up LEVEL_COUNT
    up DIRECTORY_NAME
    up --help|-h

# DESCRIPTION

`up` changes the directory to a higher level directory in the current hierarchy.

# OPTIONS

* no arguments     : Same as `cd ..`
* `LEVEL_COUNT`    : Goes `LEVEL_COUNT` levels up in the current hierarchy. Must be `>= 0`
* `DIRECTORY_NAME` : Goes to the last directory named `DIRECTORY_NAME` in the current hierarchy
* `--help`, `-h`   : Shows this help

# EXAMPLES

    /a/b/c/d/e/f       $ up
    /a/b/c/d/e         $ up 2
    /a/b/c             $ cd d/e/f
    /a/b/c/d/e/f       $ up c
    /a/b/c             $ cd d/e/f/b/g/h
    /a/b/c/d/e/f/b/g/h $ up b
    /a/b/c/d/e/f/b     $ up 100
    /                  $

# SEE ALSO

    cd

# AUTHOR

Written by **Mohamed-Yassine MADDOURI**
