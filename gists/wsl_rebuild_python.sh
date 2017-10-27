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
version="2.7.14"
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
./configure --enable-optimizations && make && make altinstall
