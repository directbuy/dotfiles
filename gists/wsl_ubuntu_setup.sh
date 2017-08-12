#!/usr/bin/env bash
sudo apt install software-properties-common
sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
sudo add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://mirror.jaleco.com/mariadb/repo/10.1/ubuntu xenial main'
sudo add-apt-repository ppa:git-core/ppa
sudo add-apt-repository ppa:jonathonf/vim
sudo apt update
sudo apt install -y mariadb-client libmariadbclient-dev
sudo apt install -y wget
sudo apt install -y git redis
sudo apt install -y curl libcurl3
sudo apt install -y python python-dev
sudo apt install -y sqlite3 libsqlite3-dev
sudo apt install -y python-pip
sudo apt install -y htop
sudo apt install -y vim
sudo apt install -y screen
sudo apt install -y openssl libssl-dev
sudo apt install -y libffi6 libffi-dev
sudo apt install -y zsh
sudo apt install -y zip unzip
sudo apt install -y libjpeg-dev libjpeg-turbo8-dev
sudo apt install -y libfreetype6-dev libncurses5-dev libreadline6-dev
sudo apt install -y libz1g-dev libbz2-dev
sudo apt install -y gcc gcc-5
sudo apt install -y g++ g++-5
sudo apt install -y make automake autoconf
sudo apt install -y nfs-common
sudo apt install -y bind9utils
sudo apt install -y rsync
sudo apt install -y gnupg
sudo apt install -y libldap2-dev libsasl2-dev
sudo apt install -y build-essential checkinstall
sudo apt install -y libreadline-gplv2-dev libncursesw5-dev tk-dev libgdbm-dev libc6-dev
if [ ! -e /u ] ; then sudo ln -s /mnt/c/u /u ; fi
mkdir -p /u/downloads
wget https://www.python.org/ftp/python/2.7.13/Python-2.7.13.tgz -O /u/downloads/python-2.7.13.tgz
mkdir -p /u/python-2.7.13 && mkdir -p /u/python
cd /u/python-2.7.13 && tar xzf /u/downloads/python-2.7.13.tgz --strip-components=1
cd /u/python-2.7.13 && ./configure && make && sudo make altinstall
rm -rf /u/python-2.7.13
rm -f /u/downloads/python-2.7.13.tgz
sudo apt install -y git-crypt
pushd /u
if [! -d dotfiles ] ; then
  git clone https://github.com/2ps/dotfiles ;
fi
git-crypt --version
/usr/local/bin/python2.7 --version
find /usr/local/lib/python2.7/dist-packages -type f -exec sudo chmod g+w
find /usr/local/lib/python2.7/dist-packages -type d -exec sudo chmod g+w
pip install -U pip ansible awscli
pip install -U ipython
pip install -U virtualenv
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
sudo wget https://packages.microsoft.com/config/ubuntu/16.04/prod.list -O "/etc/apt/sources.list.d/mssql-release.list"
sudo apt update
sudo ACCEPT_EULA=Y apt -y install msodbcsql
sudo ACCEPT_EULA=Y apt -y install mssql-tools
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
source ~/.bashrc
sudo apt install -y unixodbc-dev
