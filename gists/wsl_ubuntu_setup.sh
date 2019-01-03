#!/usr/bin/env bash
function build_python {
    version="${1}"
    mkdir -p /u/downloads
    cd /u/downloads
    filename="/u/downloads/python-${version}.tgz"
    if [ ! -f "${filename}" ] ; then
        wget "https://www.python.org/ftp/python/${version}/Python-${version}.tgz" -O "${filename}" ;
    fi
    pdir="/u/python-${version}"
    if [ ! -d "${pdir}" ] ; then
        mkdir -p "${pdir}"
        cd "${pdir}"
        tar xzf "/u/downloads/python-${version}.tgz" --strip-components=1
    fi
    cd "${pdir}"
    ./configure && make && make altinstall
    rm -rf "${pdir}"
}
apt update
apt install -y sudo
sudo apt install -y software-properties-common
sudo apt update
echo "America/Chicago" >/etc/timezone
sudo apt install -y libmysqlclient-dev wget git redis curl libcurl4-openssl-dev \
    sqlite3 libsqlite3-dev htop vim tmux libbz2-dev \
    openssl libssl-dev libffi6 libffi-dev zsh zip unzip \
    libjpeg-dev libjpeg-turbo8-dev libfreetype6-dev libncurses5-dev \
    libreadline-dev libz3-dev gcc gcc-5 g++ g++-5 less \
    make automake autoconf nfs-common bind9utils rsync gnupg \
    libldap2-dev libsasl2-dev build-essential checkinstall \
    libreadline7 libreadline-dev libncursesw5-dev tk-dev libgdbm-dev libc6-dev \
    git-crypt traceroute dnsutils net-tools mysql-client-5.7
if [[ ! -e /u ]] ; then sudo ln -s /mnt/c/u / ; fi
mkdir -p /u/downloads
build_python "2.7.15"
build_python "3.6.7"
if [ ! -d /u/dotfiles ] ; then
  cd /u ;
  git clone https://github.com/directbuy/dotfiles ;
fi
sudo usermod -a -G root,staff `whoami`
pip install -U pip ansible awscli ipython
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
sudo wget https://packages.microsoft.com/config/ubuntu/18.04/prod.list -O "/etc/apt/sources.list.d/mssql-release.list"
sudo apt update
sudo ACCEPT_EULA=Y apt -y install msodbcsql17 mssql-tools
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
echo '[client]' >>/etc/mysql/my.cnf
echo 'host=127.0.0.1' >>/etc/mysql/my.cnf
if [[ ! -e /usr/local/bin/pip ]]; then
    if [[ -e /usr/local/bin/pip3.6 ]] ; then
        sudo ln -s /usr/local/bin/pip3.6 /usr/local/bin/pip ;
    fi
fi
source ~/.bashrc
sudo apt install -y unixodbc-dev pv
sudo chsh -s /bin/zsh
sudo update-alternatives --set editor /usr/bin/vim.basic
sudo sed -Ei 's,HashKnownHosts\s+yes,HashKnownHosts no,g' /etc/ssh/ssh_config
