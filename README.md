# Efficient Shell

[![License](https://img.shields.io/github/license/maddouri/efficient-shell.svg?style=flat-square)](LICENSE)

| Branch | Build Status |
| ---- | ---- |
| master | [![](https://img.shields.io/travis/maddouri/efficient-shell/master.svg?style=flat-square)](https://travis-ci.org/maddouri/efficient-shell) |
| develop | [![](https://img.shields.io/travis/maddouri/efficient-shell/develop.svg?style=flat-square)](https://travis-ci.org/maddouri/efficient-shell) |

Easy management of scripts, functions and aliases for an efficient experience in the shell.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->


- [Basics](#basics)
- [Usage](#usage)
- [Packages Structure](#packages-structure)
- [Make Your Own Package](#make-your-own-package)
- [TODO](#todo)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Basics

`efficient.sh` is a script for managing a collection of shell scripts, functions, aliases, etc.

Every script/function/alias/etc. or collection of scripts/functions/aliases/etc. is stored in its own directory. `efficient.sh` manages [`source`](http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/x237.html)ing them when a new shell is started.

A collection of scripts/functions/aliases/etc. is referred to as a **package**.

## Usage

`efficient.sh` is similar in usage to [`vim-pathogen`](https://github.com/tpope/vim-pathogen):

1. Clone this repository somewhere on your machine:

    ```sh
    git clone https://github.com/maddouri/efficient-shell.git "${HOME}/.efficient-shell"
    ```

2. Add `efficient.sh` to your `.bashrc`:

    ```sh
    echo "source ${HOME}/.efficient-shell/efficient.sh" >> "${HOME}/.bashrc"
    ```

3. Restart the shell or simply:

    ```sh
    source "${HOME}/.efficient-shell/efficient.sh"
    ```

4. Done! You can now either:
    * Try some of the [pre-installed packages](package),
    * [Make your own package](#make-your-own-package),
    * Install a package that someone else has made.

## Packages Structure

`efficient.sh` assumes that packages are stored in the `${EFFICIENT_SHELL_Root}/package` directory.
`${EFFICIENT_SHELL_Root}` is the directory where `efficient.sh` has been installed.
(e.g. `${HOME}/.efficient-shell` in the usage example)

A typical package `p` is a directory `${EFFICIENT_SHELL_Root}/package/p` that has a configuration file named `efficient.cfg` and, at least, one shell script file to be `source`'d when the shell starts.

Our example's `p` package can, for instance, have the following, minimal structure:

```
${HOME}/.efficient-shell/package/p
├── efficient.cfg
└── pp.sh
```

In this package, `pp.sh` can contain a useful [alias](http://tldp.org/LDP/abs/html/aliases.html), a complex [function](http://tldp.org/LDP/abs/html/functions.html) or anything that you need `efficient.sh` to [`source`](http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/x237.html).  Check out the [pre-installed packages](package) for some examples.

The `efficient.cfg` configuration file, is a simple list of `<key>="<value>"` pairs that tells efficient-shell how to load the package. Here is a complete example:

```sh
# efficient.sh
# list of <key>="<value>" pairs
# <key> does NOT contain spaces
# <key> is NOT surrounded by quotes
# = MAY be surrounded by spaces
# <value> MUST be surrounded by quotes

# package name (does NOT have to be the same as the directory name)
# the package name must NOT contain spaces
name="p"
# main script file to source
# relative path to the main script
main="pp.sh"
# dependencies to other efficient-shell packages
# space-separated list of dependencies
# e.g. dependency to pck1, pck2 and pck3
#      depend="pck1 pck2 pck3"
# e.g. no dependencies
#      depend=""
depend=""

```

<a name="make-your-own-package"></a>
## Make Your Own Package

This is a walkthrough on how to make a simple package. We'll assume that `efficient.sh` is installed in `${HOME}/.efficient-shell`.

Suppose you have a collection of handy aliases, related to a particular task, that you use frequently:
```sh
# cd to parent directory
alias up='cd ..'
# cd to previous directory
alias bk='cd -'
```

Usually, they are put, along with other unrelated aliases, in `${HOME}/.bash_aliases`, which is then `source`d in `${HOME}/.bashrc`: `source ${HOME}/.bash_aliases`

To make this into an `efficient.sh` package, let's call it `efficient-cd`, we just have to:

1. Create a minimal package directory structure:

    ```sh
    mkdir --parents ${HOME}/.efficient-shell/package/efficient-cd/src
    ```

1. Create the script that will be `source`'d:

    ```sh
    vim ${HOME}/.efficient-shell/package/efficient-cd/src/aliases.sh
    # put this in ${HOME}/.efficient-shell/package/efficient-cd/src/aliases.sh
    # cd to parent directory
    alias up='cd ..'
    # cd to previous directory
    alias bk='cd -'
    ```

1. Add the package configuration file:

    ```sh
    vim ${HOME}/.efficient-shell/package/efficient-cd/efficient.cfg
    # put this in ${HOME}/.efficient-shell/package/efficient-cd/efficient.cfg
    main="efficient-cd"
    main="src/aliases.sh"
    depend=""
    ```

1. The package directory should now look like this:

    ```
    ${HOME}/.efficient-shell/package/efficient-cd
    ├── efficient.cfg
    └── src
        └── aliases.sh
    ```

1. Restart the shell or:

    ```sh
    source "${HOME}/.efficient-shell/efficient.sh"
    ```

1. That's it! The `efficient.sh` package is now loaded. You can try the aliases that it provides:

    ```sh
    ~ $ up
    /home $ bk
    ~ $
    ```

This is a very simple example of what you can do in a package, check out the [pre-installed packages](package) for more examples.

## TODO

Efficient Shell is a work in progress. (although, the `master` branch is reliable for everyday use)

Here are my current goals: (feel free to suggest your own ideas by opening a new [issue](https://github.com/maddouri/efficient-shell/issues))

* [ ] Refactor/cleanup/simplify `efficient.sh`'s code
* [x] Simplify package structure
* [ ] Create an interface _à la_ `apt-get`
* [ ] Add an `install` command to fetch packages from local and remote sources
* [ ] Add more management commands (e.g. `update`, `remove`, etc.)
* [ ] Add documentation
