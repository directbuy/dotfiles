local return_code="%(?..%{$fg[red]%}%? ↵%{$reset_color%})"
local platform=`python -m platform`
local prefix=''
local stupid_mac=false
local remote=false;
local wsl=false;
local cygwin=false;
local docker=false;
local docker_env=''
local border_color=''
setopt nocasematch

function detect_platform {
    if [[ -f /etc/docker/docker.cfg ]] ; then
        docker_env=`$(cat /etc/docker.cfg)`
    fi

    if [[ "${platform}" =~ microsoft ]] ; then
        wsl=true ;
        prefix="wsl"
        border_color="${reset_color}";
    else
       if [ -n "${docker_env}" ] ; then
           # echo "docker setting prefix to: [${docker_env}]" >> .logfile
           prefix="${docker_env}";
           docker=true;
           border_color="$fg[red]";
       else
           if [[ "${platform}" =~ (amzn|centos|ubuntu) ]] ; then
               remote=true ;
               prefix="remote"
               border_color="$fg[blue]";
           else
               if [[ "${platform}" =~ cygwin ]] ; then
                   prefix="cygwin";
                   border_color="${reset_color}";
                   cygwin=true;
               else
                   if [[ "${platform}" =~ darwin ]] ; then
                       prefix=mac
                       stupid_mac=true
                   fi
               fi
           fi
       fi
    fi
    prefix=$(print -P "${prefix}")
}

detect_platform

# PROMPT='$(dbuy_prompt)'
# RPS1="%B${return_code}%b"

ZSH_THEME_VIRTUALENV_PREFIX=' ('
ZSH_THEME_VIRTUALENV_SUFFIX=')'
ZSH_THEME_GIT_PROMPT_PREFIX="[\e[34m"
ZSH_THEME_GIT_PROMPT_SUFFIX="\e[0m]"

local ret_status="%(?:%{$fg[white]%}➤ :%{$fg[red]%}➤ )"
PROMPT='%{$border_color%}┏━━%{$reset_color%} %d $(virtualenv_prompt_info)$(git_prompt_info)
%{$border_color%}┣━━%{$fg_bold[white]%} %{$prefix%} %{$reset_color%}%{$border_color%}━━%{$reset_color%} %{$fg[cyan]%}%n@%m%{$reset_color%} %{$border_color%}━━%{$reset_color%} $(date +"%Y.%m.%d %I:%M%p")
%{$border_color%}┗━ %{$reset_color%}${ret_status}%{$reset_color%}'

ZSH_THEME_GIT_PROMPT_PREFIX="%{$border_color%}━━┫%{$reset_color%} %{$fg_bold[blue]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX=" ┃"
ZSH_THEME_GIT_PROMPT_DIRTY=" %{$fg[white]%}*%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$reset_color%}"
ZSH_THEME_VIRTUALENV_PREFIX="%{$border_color%}━━┫%{$reset_color%} %{$fg_bold[blue]%}"
ZSH_THEME_VIRTUALENV_SUFFIX=" %{$reset_color%}┣"
