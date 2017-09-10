#!/usr/bin/env bash
yum clean metadata
yum updateinfo
yum -y install python
yum -y install python-devel
yum -y install sqlite-devel
yum -y install python-pip
yum -y install openssl-devel
yum -y install libffi-devel
yum -y install libjpeg-turbo-devel
yum -y install freetype-devel
yum -y install zlib-devel
yum -y install bzip2-devel
yum -y install gcc
yum -y install gcc-c++
yum -y install make
yum -y install automake
yum -y install autoconf
yum -y install tkinter tk-devel
if [ ! -e /u/downloads ] ; then mkdir -p /u/downloads ; fi
wget https://www.python.org/ftp/python/2.7.13/Python-2.7.13.tgz -O /u/downloads/python-2.7.13.tgz
mkdir -p /u/python-2.7.13
cd /u/python-2.7.13 && tar xzf /u/downloads/python-2.7.13.tgz --strip-components=1
cd /u/python-2.7.13 && ./configure && make && make altinstall
rm -rf /u/python-2.7.13
rm -f /u/downloads/python-2.7.13.tgz
