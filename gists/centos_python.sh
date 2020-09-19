#!/bin/bash
version=${1:-"2.7.18"}
yum -y install gcc openssl-devel bzip2-devel wget
mkdir -p /u/downloads
url="https://www.python.org/ftp/python/$version/Python-$version.tgz"
filename="/u/downloads/python_$version.tgz"
wget $url -O $filename
mkdir -p /u/python_$version
cd /u/python_$version
tar xzf $filename
/u/python_$version
cd /u/python_$version
tar xzf $filename
./configure
make altinstall

