#!/bin/bash
version="${1:-3.8.5}"
sudo apt-get install -y libreadline-gplv2-dev libncursesw5-dev \
  libssl-dev libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev \
  wget libffi-dev
cd /u/downloads
url="https://www.python.org/ftp/python/${version}/Python-${version}.tgz"
pip_url="https://bootstrap.pypa.io/get-pip.py"
tarball="/u/downloads/python_${version}.tgz"
pip_file="/u/downloads/get-pip.py"
build_dir="/u/python_${version}"
mkdir -p "${build_dir}"
cd "${build_dir}"
if [[ ! -f $tarball ]] ; then
    wget -q $url -O $tarball ;
    tar xzf $tarball --strip-components=1
fi
./configure
make altinstall
if [[ ! -f $pip_file ]] ; then
    wget -q $pip_url -O $pip_file
fi
/usr/local/bin/python3.8 $pip_file


