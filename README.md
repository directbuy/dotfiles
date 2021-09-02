# dotfiles

> **dot·files**: hidden files in a directory (folder) which are commonly
>   used for storing user preferences or preserving the state of a
>   utility

One of the many heralds of geekdom is an extremely customized
environment. This is the history of our journey down that path.

We use vim and [Z-Shell](http://www.zsh.org/) as our primary tools for getting things
done. We track our code with [Git](http://git-scm.com/).  Much of that code is
written in [Python](http://www.python.org/) and [NodeJS](http://www.nodejs.org).

Our many thanks to the wonderful [Cassie Meharry](https://github.com/cassiemeharry/dotfiles/),
whose original dotfiles was a guide.

* [chocolatey](chocolatey.md)

To install dotfiles clone the repository and run ./wsl-install

## Update as of 6/6/2020
2ps has made some speed improvements please be sure to grab most recent commit of dotfiles.

Also included in this update:
### 1. Substring searching
##### Example
> Type fab and hit up arrow to show any command that you have used in your history that contains fab.
> Up and down arrow command functionality still present as well after this update.

### 2. Long string edit
##### Example
> Type a long string: echo "this is a super long string for us to try to use our new fun edit functionality on this will be something very cool for us to use in the future."
> Once you push enter and go to new line type fc then press enter.
> This will open up your last line in a vim window for easier editing! 

## Update as of 10/1/2020
### 1. Fix WSL resolv.conf
>Type ```fix_resolv_conf``` in a new shell and the function will add the nameservers to your resolv.conf!

### 2. Support for running Linux Bash commands in Windows Powershell
Support for the bash commands:
`"awk", "emacs", "grep", "head", "less", "ls", "man", "sed", "seq", "ssh", "tail", "touch"`
has been added to powershell for use on the windows side of your windows machine. Tab completion for these commands 
is included. 
