#!/usr/bin/env bash
if [ ! -e /u/downloads ] ; then mkdir -p /u/downloads ; fi
wget https://www.python.org/ftp/python/2.7.13/Python-2.7.13.tgz -O /u/downloads/python-2.7.13.tgz
mkdir -p /u/python-ucs2
cd /u/python-ucs2 && tar xzf /u/downloads/python-2.7.13.tgz --strip-components=1
cd /u/python-ucs2 && ./configure --prefix=/u/python-ucs2f --enable-unicode=ucs2 && make && make install
