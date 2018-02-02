#!/usr/bin/env bash
yum clean metadata
yum updateinfo
yum -y install python python-devel sqlite-devel python-pip openssl-devel \
    libffi-devel libjpeg-turbo-devel freetype-devel zlib-devel \
    bzip2-devel gcc gcc-c++ make automake autoconf tkinter tk-devel \
    ncurses-devel
if [ ! -e /u/downloads ] ; then mkdir -p /u/downloads ; fi
version=${1:-"2.7.14"}
printf "\e[36mBuilding python %s\e[0m\n" "${version}"
pushd /u/downloads
filename="/u/downloads/python-${version}.tgz"
if [ ! -f "${filename}" ] ; then
    printf "\e[32mdownloading source bundle\e[0m\n"
    wget "https://www.python.org/ftp/python/${version}/Python-${version}.tgz" -O "${filename}" ;
fi
pdir="/u/python-${version}"
if [ ! -d "${pdir}" ] ; then
    mkdir -p "${pdir}"
    pushd "${pdir}"
    printf "\e[32muntarring bundle\e[0m\n"
    tar xzf "/u/downloads/python-${version}.tgz" --strip-components=1
else
    pushd "${pdir}"
fi
printf "\e[32mbuilding!\e[0m\n"
./configure && make && make altinstall
popd
popd
