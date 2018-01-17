# ZSH Theme - Preview: http://gyazo.com/8becc8a7ed5ab54a0262a470555c3eed.png
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
        prefix="\e[1mwsl\e[0m "
        border_color="\e[0m";
    else
       if [ -n "${docker_env}" ] ; then
           # echo "docker setting prefix to: [${docker_env}]" >> .logfile
           prefix="\e[1m${docker_env}\e[0m ";
           docker=true;
           border_color="\e[31m";
       else
           if [[ "${platform}" =~ (amzn|centos|ubuntu) ]] ; then
               remote=true ;
               prefix="\e[1mremote\e[0m"
               border_color="\e[34m";
           else
               if [[ "${platform}" =~ cygwin ]] ; then
                   prefix="\e[1mcygwin\e[0m";
                   border_color="\e[35m";
                   cygwin=true;
               else
                   if [[ "${platform}" =~ darwin ]] ; then
                       stupid_mac=true
                   fi
               fi
           fi
       fi
    fi
    prefix=$(print -P "${prefix}")
}

function rpad {
    local st=$(printf '%0.1s' "━"{1..60})
}

function detect_docker {
  [[ -n ${docker_env} ]] || return
  printf "\e[37m${docker_env} ━━ \e[0m"
}

local user_host
if [ -n "${prefix}" ] ; then
    user_host="${prefix}"
else
    user_host=$(print -P '\e[1m%n\e[0m@\e[32m%m\e[0m')
fi

if [[ $UID -eq 0 ]]; then
    local user_symbol='\e[31m➤\e[0m'
else
    local user_symbol='\e[1m➤e[0m'
fi

local current_dir='%~'
local venv='%{$fg[yellow]%}$(virtualenv_prompt_info)%{$reset_color%}'
local git_branch='$(git_prompt_info)%{$reset_color%}'
local curr_date='$(date +"%Y.%m.%d %I:%M%p")'
local padding=$(printf '%0.1s' "━"{1..60})


function actual_length {
    local st="${1}";
    if [ ! $stupid_mac ] ; then
        echo "${#$(echo "${1}" | sed -r "s/\x1B\[([0-9]{1,3}((;[0-9]{1,3})*)?)?[m|K]//g")}"
    else
        echo "${#$(echo "${1}" | sed $'s,\x1b\\[[0-9;]*[a-zA-Z],,g')}"
    fi
}

function rpad {
    local st="$(print -P ${1})"
    local len=$(actual_length "${st}")
    local pad_length="${2}";
    printf '%s' "${st}"
    printf " ${border_color}"
    printf '%*.*s' 0 $((pad_length - len)) $padding
    printf "\e[0m"
}

function dbuy_prompt {
    start=$(date +%s%N | cut -b1-13)
    prompt1=$(print -P "${border_color}┏━━\e[0m %d ${border_color}━━\e[0m $(git_prompt_info)")
    end=$(date +%s%N | cut -b1-13)
    prompt2=$(print -P "${border_color}┃━━\e[37m ${user_host} ${border_color}━━\e[0m ${curr_date}")
    local m=$(actual_length "${prompt1}")
    local n=$(actual_length "${prompt2}")
    n=$((m > n ? m + 1 : n + 1))
    prompt1=$(rpad "${prompt1}" $n)
    prompt2=$(rpad "${prompt2}" $n)
    # prompt3=$(print -P "${border_color}┗ \e[0m${user_symbol} ")
    end=$(date +%s%N | cut -b1-13)
    prompt3=$(print -P "${border_color}┗ \e[0m$((end-start))ms ${user_symbol} ")
    printf "%s${border_color}━┓\e[0m\\n%s${border_color}━┛\e[0m\\n%s" "${prompt1}" "${prompt2}" "${prompt3}"
}


detect_platform

PROMPT='$(dbuy_prompt)'
# RPS1="%B${return_code}%b"

ZSH_THEME_VIRTUALENV_PREFIX=' ('
ZSH_THEME_VIRTUALENV_SUFFIX=')'
ZSH_THEME_GIT_PROMPT_PREFIX="[\e[34m"
ZSH_THEME_GIT_PROMPT_SUFFIX="\e[0m]"

local ret_status="%(?:%{$fg_bold[green]%}➜ :%{$fg_bold[red]%}➜ )"
PROMPT='%d%{$fg[yellow]%}$(virtualenv_prompt_info)%{$reset_color%}$(git_prompt_info)
$prefix $(date +"%Y.%m.%d %I:%M%p")
${ret_status}%{$reset_color%} '

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[blue]%} git:(%{$fg[red]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%}) %{$fg[white]%}*"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})"
