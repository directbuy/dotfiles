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
echo "installing git redis curl"
apt-get install -qq wget git redis curl >/dev/null
echo "installing vim curl sqlite tmux"
apt-get install -qq libcurl4-openssl-dev sqlite3 libsqlite3-dev htop vim tmux libbz2-dev >/dev/null
echo "installing ssl, ffi, zsh, zip"
apt-get install -qq openssl libssl-dev libffi7 libffi-dev zsh zip unzip >/dev/null
echo "installing python prereqs"
apt-get install -qq libjpeg-dev libjpeg-turbo8-dev libfreetype6-dev libncurses5-dev >/dev/null
echo "installing readline, gcc, g++"
apt-get install -qq libreadline-dev libz3-dev libbz2-dev gcc g++ less >/dev/null
echo "installing make, nfs, and rsync"
apt-get install -qq make automake autoconf nfs-common bind9utils rsync gnupg >/dev/null
echo "installing ldap and build stuff"
apt-get install -qq libldap2-dev libsasl2-dev build-essential checkinstall >/dev/null
echo "installing readline and gdbm"
apt-get install -qq libreadline8 libncursesw5-dev tk-dev libgdbm-dev >/dev/null
echo "installing network utilities and git-crypt"
apt-get install -qq libc6-dev git-crypt traceroute dnsutils net-tools >/dev/null
echo "installing xml and yaml"
apt-get install -qq libxml2-dev libxslt1-dev libyaml-dev rlwrap >/dev/null
echo "installing postgres client and dev libraries"
apt-get install -qq libpq-dev postgresql-client >/dev/null
echo "install mysql"
mkdir -p /u/downloads
cd /u/downloads
wget  https://dev.mysql.com/get/mysql-apt-config_0.8.22-1_all.deb
dpkg -i /u/downloads/mysql-apt-config_0.8.22-1_all.deb
apt-get -y update
apt-get install -y mysql-shell mysql-client libmysqlclient-dev
echo "installing snakes"
add-apt-repository -y ppa:deadsnakes/ppa
add-apt-repository -y ppa:git-core/ppa
apt-get -qq update
apt-get install -y git
apt-get install -y python3 python3-dev python3-venv python3-pip python3-distutils python3-apt >/dev/null
python3.8 -m pip install -U -q pip wheel invoke setuptools
python3.8 -m pip install -U -q raft awscli ipython
apt-get install -qq python3.9 python3.9-dev python3.9-venv >/dev/null
python3.9 -m pip install -U -q testresources pip wheel invoke setuptools
python3.9 -m pip install -U -q raft awscli ipython
#echo "grabbing dotfiles"
#if [[ ! -e /u ]] && [[ -e /mnt/c/u ]]; then sudo ln -s /mnt/c/u / ; fi
#mkdir -p /u/downloads
#if [[ ! -d /u/dotfiles ]] ; then
#  cd /u ;
#  git clone https://github.com/2ps/dotfiles ;
#fi
usermod -a -G root,staff `whoami`
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
repo_url=https://packages.microsoft.com/config/ubuntu/20.04/prod.list
wget -q "${repo_url}" -O "/etc/apt/sources.list.d/mssql-release.list"
apt-get -qq update
ACCEPT_EULA=Y apt-get -qq install msodbcsql17 mssql-tools
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile
echo '[client]' >>/etc/mysql/my.cnf
echo 'host=127.0.0.1' >>/etc/mysql/my.cnf
source ~/.bashrc
apt-get install -qq unixodbc-dev pv >/dev/null
chsh -s /bin/zsh
update-alternatives --set editor /usr/bin/vim.basic
sed -Ei 's,HashKnownHosts\s+yes,HashKnownHosts no,g' /etc/ssh/ssh_config
