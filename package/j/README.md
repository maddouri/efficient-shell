
# NAME

`j` - jump to a bookmarked location

# SYNOPSIS

    j
    j entry
    j --add|-a entry path
    j --remove|-r entry
    j --edit|-e
    j --help|-h

# DESCRIPTION

`j` uses a _bookmarks_ file to look up a given `entry`
then calls `g` to go to the corresponding location.

# OPTIONS

* no arguments     : shows the list of bookmarks
* `entry`          : changes the directory which path corresponds to `entry` in the _bookmarks_ file
* `--add`, `-a`    : adds a new `entry` with the given `path` to the _bookmarks_ file.
                     If `entry` exists already, then its `path` is replaced by the new one
* `--remove`, `-r` : removes an `entry` from the _bookmarks_ file
* `--edit`, `-e`   : directly edit the _bookmarks_ file in `${EDITOR}`
* `--help`, `-h`   : shows this help

# FILES

* `${EFFICIENT_SHELL_Root}/data/j/bookmarks`
    * the _bookmarks_ file, contains the `entry path` list of bookmarks

# SEE ALSO

    g, cd

# AUTHOR

Written by **Mohamed-Yassine MADDOURI**
