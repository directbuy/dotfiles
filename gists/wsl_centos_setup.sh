#!/usr/bin/env bash
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
sed -i 's,^root\(.*\)$,root\1\n%sudoers ALL=(ALL)    NOPASSWD: ALL,g' /etc/sudoers
yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpmrpm -Uvh http://www.city-fan.org/ftp/contrib/yum-repo/city-fan.org-release-1-13.rhel7.noarch.rpm
echo "[mariadb]" > /etc/yum.repos.d/mariadb.repo
echo "name = MariaDB" >> /etc/yum.repos.d/mariadb.repo
echo "baseurl = http://yum.mariadb.org/10.2/centos7-amd64" >> /etc/yum.repos.d/mariadb.repo
echo "gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB" >> /etc/yum.repos.d/mariadb.repo
echo "gpgcheck=1" >> /etc/yum.repos.d/mariadb.repo
yum -y install https://centos7.iuscommunity.org/ius-release.rpm
yum clean all
yum updateinfo
yum -y install --enablerepo=city-fan.org curl libcurl-devel
yum -y install wget
yum -y install python
yum -y install python-devel
yum -y install sqlite-devel
yum -y install python-pip
yum -y install htop
yum -y install vim
yum -y install screen
yum -y install openssl
yum -y install openssl-devel
yum -y install libffi-devel
yum -y install zsh
yum -y install zip
yum -y install unzip
yum -y install libjpeg-turbo-devel
yum -y install freetype-devel
yum -y install zlib-devel
yum -y install bzip2-devel
yum -y install gcc
yum -y install gcc-c++
yum -y install make
yum -y install automake
yum -y install autoconf
yum -y install nfs-utils
yum -y install bind-utils
yum -y install rsync
yum -y install gnupg
yum -y update
yum -y upgrade
yum -y install MariaDB-devel MariaDB-client MariaDB-shared
yum -y install gettext-devel perl-CPAN perl-devel
wget https://github.com/git/git/archive/v2.13.3.tar.gz -O /tmp/git.tgz
mkdir -p /usr/local/src/git
tar xzf /tmp/git.tgz -C /usr/local/src/git --strip-components=1
cd /usr/local/src/git && make configure && ./configure --prefix=/usr/local && make && make install
rm -rf /usr/local/src/git
rm -rf /tmp/git.tgz
ln -s /mnt/c/u /u
mkdir -p /u/downloads
wget https://www.python.org/ftp/python/2.7.13/Python-2.7.13.tgz -O /u/downloads/python-2.7.13.tgz
mkdir -p /u/python-2.7.13 && mkdir -p /u/python
cd /u/python-2.7.13 && tar xzf /u/downloads/python-2.7.13.tgz --strip-components=1
cd /u/python-2.7.13 && ./configure && make && make altinstall
rm -rf /u/python-2.7.13
rm -f /u/downloads/python-2.7.13.tgz
mkdir -p /usr/local/src
cd /usr/local/src && git clone https://github.com/AGWA/git-crypt
cd /usr/local/src/git-crypt && make && make install
rm -rf /usr/local/src/git-crypt
cd /u && git clone https://github.com/2ps/dotfiles
/u/dotfiles/wsl-install
/usr/local/bin/git --version
git-crypt --version
/usr/local/bin/python2.7 --version
pip install -U pip ansible awscli
pip install setuptools==33.1.1
pip install -U ipython
pip install -U virtualenv
curl https://packages.microsoft.com/config/rhel/7/prod.repo > /etc/yum.repos.d/mssql-release.repo
ACCEPT_EULA=Y yum install msodbcsql
ACCEPT_EULA=Y yum install mssql-tools
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.zshrc
sudo yum install unixODBC-devel
