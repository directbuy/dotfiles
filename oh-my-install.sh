#!/usr/bin/env zsh
pushd `dirname $0` >/dev/null
cp zsh/.zshrc.oh-my ~/.zshrc
cp zsh/dbuy.zsh_aliases ~/.zsh_aliases
mkdir -p ~/.oh-my-zsh/custom/themes
cp zsh/dbuy.zsh-theme ~/.oh-my-zsh/custom/themes/
source ~/.zshrc
export ZSH_CUSTOM=~/.oh-my-zsh/custom
dirname="${ZSH_CUSTOM}/plugins/zsh-autosuggestions"
if [ ! -e  "${dirname}"] ; then
    git clone https://github.com/zsh-users/zsh-autosuggestions.git "${dirname}"
else
    pushd "${dirname}" >/dev/null
    git pull
    popd >/dev/null
fi
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
popd >/dev/null
