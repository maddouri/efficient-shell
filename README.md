[![License](https://img.shields.io/github/license/maddouri/efficient-shell.svg)](LICENSE)

# efficient.sh

Easy management of scripts, functions and aliases for an efficient experience in the shell.

## Basics

`efficient.sh` is a script for managing a collection of shell scripts, functions, aliases, etc.

Every script/function/alias/etc. or collection of scripts/functions/aliases/etc. is stored in its own directory. `efficient.sh` manages [`source`](http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/x237.html)ing them when a new shell is started.

A collection of scripts/functions/aliases/etc. is referred to as a **package**.

## Usage

`efficient.sh` is similar in usage to [`vim-pathogen`](https://github.com/tpope/vim-pathogen):

1. Clone this repository somewhere on your machine:

    ```shell
    git clone https://github.com/maddouri/efficient-shell.git "~/.efficient-shell"
    ```

2. Add `efficient.sh` to your `.bashrc`:

    ```shell
    echo "source ~/.efficient-shell/efficient.sh" >> ~/.bashrc
    ```

3. Restart the shell or simply:

    ```shell
    source "~/.efficient-shell/efficient.sh"
    ```

4. Done! You can now either:
    * Try some of the [pre-installed packages](package),
    * [Make your own package](#make-your-own-package),
    * Install a package that someone else has made.

## Directory Structure

`efficient.sh` assumes that packages are stored in the `${EFFICIENT_SHELL_Root}/package` directory.
`${EFFICIENT_SHELL_Root}` being the directory where `efficient.sh` has been installed.
(e.g. `~/.efficient-shell` in the usage example)

If a package `p` needs to store/access data, it is recommended that it does so in `${EFFICIENT_SHELL_Root}/data/p`.

A typical package `p` is a directory `${EFFICIENT_SHELL_Root}/package/p` that has a sub-directory `src` with, at least, one shell script file ending with `.sh`.

Our imaginary `p` package can, for instance, have the following, minimal structure:

```
~/.efficient-shell/package/p
└── src
    └── pp.sh
```

In this package `pp.sh` can contain a useful [alias](http://tldp.org/LDP/abs/html/aliases.html), a complex [function](http://tldp.org/LDP/abs/html/functions.html) or anything that you need `efficient.sh` to [`source`](http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/x237.html).  Check out the [pre-installed packages](package) for some examples.

<a name="make-your-own-package"></a>
## Make Your Own Package

This is a walkthrough on how to make a simple package. We'll assume that `efficient.sh` is installed in `~/.efficient-shell`.

Suppose you have a collection of handy aliases, related to a particular task, that you use frequently:
```shell
# cd to parent directory
alias up='cd ..'
# cd to previous directory
alias bk='cd -'
```

Usually, they are put, along with other unrelated aliases, in `~/.bash_aliases`, which is then `source`d in `~/.bashrc`: `source ~/.bash_aliases`

To make this into an `efficient.sh` package, let's call it `efficient-cd`, we just have to:

1. Create a minimal package directory structure:

    ```shell
    mkdir --parents ~/.efficient-shell/package/efficient-cd/src
    ```

2. Create the script that will be `source`d (notice the `.sh` file extension):

    ```shell
    vim ~/.efficient-shell/package/efficient-cd/src/aliases.sh
    # put this in ~/.efficient-shell/package/efficient-cd/src/aliases.sh
    # cd to parent directory
    alias up='cd ..'
    # cd to previous directory
    alias bk='cd -'
    ```

3. Restart the shell or:

    ```shell
    source "~/.efficient-shell/efficient.sh"
    ```

4. That's it! The `efficient.sh` package is now loaded. You can try the aliases that it provides:

    ```shell
    ~ $ up
    /home $ bk
    ~ $
    ```

This is a very simple example of what you can do in a package, check out the [pre-installed packages](package) for more examples.
