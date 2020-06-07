# -*- mode: sh; -*-
#
# .zshrc is sourced in interactive shells.
# It should contain commands to set up aliases,
# functions, options, key bindings, etc.
#

fpath=(~/.zsh.d/functions $fpath)
autoload -U ~/.zsh.d/functions/*(:t)
plugins=(aws django fabric git yum docker docker-compose docker-machine)
source ~/.zsh.d/syntax-highlighting/zsh-syntax-highlighting.zsh
source ~/.zsh.d/functions/history-substring-search.zsh
autoload -Uz compinit
compinit

#allow tab completion in the middle of a word
setopt COMPLETE_IN_WORD
setopt INTERACTIVE_COMMENTS
setopt EXTENDED_GLOB
unsetopt NOMATCH
setopt nocasematch
export TIME_STYLE=long-iso
unsetopt beep

## keep background processes at full speed
#setopt NOBGNICE
## restart running processes on exit
#setopt HUP

## history
HISTSIZE=100000
SAVEHIST=100000
HISTFILE=~/.history

setopt APPEND_HISTORY
## for sharing history between zsh processes
setopt INC_APPEND_HISTORY
setopt EXTENDED_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_NO_FUNCTIONS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY

setopt autocd notify
bindkey -e

# See if we can use colors
autoload -U colors
colors

typeset -ga chpwd_functions
chpwd_functions+='chpwd_auto_venv'

# Prompt
if which python >/dev/null; then
    export platform=$(python -m platform)
elif which python3.6 >/dev/null; then
    export platform=$(python3.6 -m platform)
fi ;
if [ -f /etc/docker.conf ] ; then
    export docker_image=$(cat /etc/docker.conf) ;
fi
source ~/.zprompt
setopt PROMPT_SUBST
PROMPT='$(prompt)'
PS2='$(prompt2)'
RPROMPT='$(rprompt)'
TZ=CST6CDT
# Aliases
which dircolors >/dev/null
if [[ -f ~/.dircolors ]] && [[ $? ]]; then
    eval $(dircolors -b ~/.dircolors) ;
fi
alias ls='ls --color=auto'
alias ll='ls -lFH'
alias la='ls -lAhS'
alias grep='grep --color=auto'
alias nano='nano -w'
alias memusage="ps -u $LOGNAME -o pid,rss,command | sort -n +1 -2"
alias edit='emacsclient -nw --alternate-editor="" -c'
alias visudo='sudo -E visudo'

alias pycheck="python -m py_compile"
alias dj='python manage.py'
alias djsp='python manage.py shell_plus --quiet-load'
alias djmigrate='python manage.py migrate --merge --ignore-ghost-migrations'
alias djact='. bin/activate'
# Global aliases, can be specified anywhere (not just the beginning of a command)
alias -g swapouterr='3>&1 1>&2 2>&3 3>&-'
if [ -e /opt/mssql-tools/bin ] ; then
    alias sqlcmd='/opt/mssql-tools/bin/sqlcmd'
fi
if [[ -e ~/.zsh_aliases ]] ; then
    source ~/.zsh_aliases ;
fi
function psgrep() {
    ps up $(pgrep -f $@) 2>&-;
}

function tac () {
    awk '1 { last = NR; line[last] = $0; } END { for (i = last; i > 0; i--) { print line[i]; } }'
}

# Alias functions, for more complicated replacements
if which colordiff > /dev/null 2>/dev/null; then
    function diff () {
        colordiff $@ | less -R -F -X
    }
fi


if [ -e ~/.zshenv ]; then
    # Machine local config
    source ~/.zshenv
fi

if [ -d ~/.rbenv ]; then
    eval "$(rbenv init -)"
fi

# OPAM configuration
if [ -d ~/.opam ]; then
    . ~/.opam/opam-init/init.zsh > /dev/null 2> /dev/null || true
    eval `opam config env`
fi

if [ -f /usr/bin/aws_zsh_completer.sh ] ; then
    source /usr/bin/aws_zsh_completer.sh
fi
if [ -f /usr/local/bin/aws_zsh_completer.sh ] ; then
    source /usr/local/bin/aws_zsh_completer.sh
fi
export LESS='-i -R --silent'
export MORE='-d'

# these are wsl- conemu- specific
bindkey '^[[H' beginning-of-line      # [Home] - Go to beginning of line
bindkey '^[[F'  end-of-line            # [End] - Go to end of line
bindkey '^[[1~' beginning-of-line      # [Home] - Go to beginning of line
bindkey '^[[4~'  end-of-line            # [End] - Go to end of line
bindkey '^[[1;5C' forward-word                        # [Ctrl-RightArrow] - move forward one word
bindkey '^[[1;5D' backward-word                       # [Ctrl-LeftArrow] - move backward one word
# bindkey '^[OC' forward-word                        # [Ctrl-RightArrow in tmux] - move forward one word
# bindkey '^[OD' backward-word                       # [Ctrl-LeftArrow in tmux] - move backward one word
bindkey '^Z' undo
bindkey '^_' backward-kill-word
bindkey '^H' backward-kill-word
bindkey '^[[3;5~' kill-word
bindkey "$terminfo[kcuu1]" history-substring-search-up
bindkey "$terminfo[kcud1]" history-substring-search-down
if [[ "${terminfo[kcbt]}" != "" ]]; then
  bindkey "${terminfo[kcbt]}" reverse-menu-complete   # [Shift-Tab] - move through the completion menu backwards
fi

bindkey '^?' backward-delete-char                     # [Backspace] - delete backward
if [[ "${terminfo[kdch1]}" != "" ]]; then
  bindkey "${terminfo[kdch1]}" delete-char            # [Delete] - delete forward
else
  bindkey "^[[3~" delete-char
  bindkey "^[3;5~" delete-char
  bindkey "\e[3~" delete-char
fi
if [ -e ~/.vault-pass.txt ] ; then
    export ANSIBLE_VAULT_PASSWORD_FILE=~/.vault-pass.txt
fi
if [ -e /usr/bin/virtualenvwrapper.sh ] ; then
    export WORKON_HOME=/u/envs
    source /usr/bin/virtualenvwrapper.sh
fi
if [ -e ~/.local_zsh ] ; then
    source ~/.local_zsh
fi
if [ -d ~/.nvm ]; then
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
fi

function update_dns() {
    comment=$(head -1 /etc/resolv.conf)
    local_dns=$(head -2 /etc/resolv.conf | tail -1)
    aws_dns=$(tail -2 /etc/resolv.conf)
    printf "${comment}\n${aws_dns}\n${local_dns}\n" | sudo tee /etc/resolv.conf
}
if [[ -f "/etc/profile.d/rvm.sh" ]] ; then
    source "/etc/profile.d/rvm.sh"
fi

