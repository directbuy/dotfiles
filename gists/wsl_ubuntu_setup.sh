#!/usr/bin/env bash
# n.b., this has to be run as root
export DEBIAN_FRONTEND=noninteractive
echo "pulling latest package data"
apt-get -qq update
echo "installing apt-utils"
apt-get install -qq apt-utils >/dev/null
echo "installing sudo"
apt-get install -qq libreadline-dev sudo >/dev/null
echo "installing timezone"
apt-get install -qq tzdata >/dev/null
echo "America/Chicago" >/etc/timezone
echo "installing common packages"
apt-get install -qq software-properties-common >/dev/null
echo "installing other packages #1"
apt-get install -qq libmysqlclient-dev wget git redis curl >/dev/null
echo "installing other packages #2"
apt-get install -qq libcurl4-openssl-dev sqlite3 libsqlite3-dev htop vim tmux libbz2-dev >/dev/null
echo "installing other packages #3"
apt-get install -qq openssl libssl-dev libffi6 libffi-dev zsh zip unzip >/dev/null
echo "installing other packages #4"
apt-get install -qq libjpeg-dev libjpeg-turbo8-dev libfreetype6-dev libncurses5-dev >/dev/null
echo "installing other packages #5"
apt-get install -qq libreadline-dev libz3-dev libbz2-dev gcc gcc-5 g++ g++-5 less >/dev/null
echo "installing other packages #6"
apt-get install -qq make automake autoconf nfs-common bind9utils rsync gnupg >/dev/null
echo "installing other packages #7"
apt-get install -qq libldap2-dev libsasl2-dev build-essential checkinstall >/dev/null
echo "installing other packages #8"
apt-get install -qq libreadline7 libreadline-dev libncursesw5-dev tk-dev libgdbm-dev >/dev/null
echo "installing other packages #9"
apt-get install -qq libc6-dev git-crypt traceroute dnsutils net-tools mysql-client-5.7 >/dev/null
echo "installing other packages #10"
apt-get install -qq libxml2-dev libxslt1-dev libyaml-dev rlwrap >/dev/null
echo "installing snakes"
add-apt-repository -y ppa:deadsnakes/ppa
apt-get -qq update
apt-get install -qq python3.7 python3.7-dev python3.7-venv python3-pip >/dev/null
python3.7 -m pip install -U -q pip wheel invoke setuptools
python3.7 -m pip install -U -q invoke awscli ansible ipython
apt-get install -qq python3.8 python3.8-dev python3.8-venv python3-pip >/dev/null
python3.8 -m pip install -U -q pip wheel invoke setuptools
python3.8 -m pip install -U -q invoke awscli ansible ipython
#echo "grabbing dotfiles"
#if [[ ! -e /u ]] && [[ -e /mnt/c/u ]]; then sudo ln -s /mnt/c/u / ; fi
#mkdir -p /u/downloads
#if [[ ! -d /u/dotfiles ]] ; then
#  cd /u ;
#  git clone https://github.com/2ps/dotfiles ;
#fi
usermod -a -G root,staff `whoami`
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
repo_url=https://packages.microsoft.com/config/ubuntu/18.04/prod.list
wget -q "${repo_url}" -O "/etc/apt/sources.list.d/mssql-release.list"
apt-get -qq update
ACCEPT_EULA=Y DEBIAN_FRONTEND=noninteractive apt-get -qq install msodbcsql17 mssql-tools
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile
echo '[client]' >>/etc/mysql/my.cnf
echo 'host=127.0.0.1' >>/etc/mysql/my.cnf
if [[ ! -e /usr/local/bin/pip ]]; then
    if [[ -e /usr/local/bin/pip3.7 ]] ; then
        ln -s /usr/local/bin/pip3.7 /usr/local/bin/pip ;
    fi
fi
source ~/.bashrc
apt-get install -qq unixodbc-dev pv >/dev/null
chsh -s /bin/zsh
update-alternatives --set editor /usr/bin/vim.basic
sed -Ei 's,HashKnownHosts\s+yes,HashKnownHosts no,g' /etc/ssh/ssh_config
