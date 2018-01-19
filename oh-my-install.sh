#!/usr/bin/env zsh

function clone_plugin {
    local dirname=${1}
    if [ ! -e  "${ZSH_CUSTOM}/plugins/${dirname}" ] ; then
        git clone "https://github.com/zsh-users/${dirname}.git" "${ZSH_CUSTOM}/plugins/${dirname}"
    else
        pushd "${ZSH_CUSTOM}/plugins/${dirname}" >/dev/null
        git pull
        popd >/dev/null
    fi
}
pushd `dirname $0` >/dev/null
cp zsh/.zshrc.oh-my ~/.zshrc
cp zsh/dbuy.zsh_aliases ~/.zsh_aliases
mkdir -p ~/.oh-my-zsh/custom/themes
cp zsh/dbuy.zsh-theme ~/.oh-my-zsh/custom/themes/
source ~/.zshrc
export ZSH_CUSTOM=~/.oh-my-zsh/custom
clone_plugin "zsh-autosuggestions"
clone_plugin "zsh-syntax-highlighting"
popd >/dev/null
