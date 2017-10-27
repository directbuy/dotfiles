#!/usr/bin/env bash
if [ ! -e /u/downloads ] ; then mkdir -p /u/downloads ; fi
yum -y install ncurses-devel
version="3.6.3"
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
