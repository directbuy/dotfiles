#!/usr/bin/env bash
yum updateinfo
yum makecache fast
yum -y install dh-autoreconf curl-devel expat-devel gettext-devel \
  openssl-devel perl-devel zlib-devel
yum -y install asciidoc xmlto docbook2X
if [ ! -e /u/downloads ] ; then mkdir -p /u/downloads ; fi
version=${1:-"2.14.3"}
printf "Building git %s\n" "${version}"
pushd /u/downloads
filename="/u/downloads/git-${version}.tgz"
if [ ! -f "${filename}" ] ; then
    printf "downloading source bundle\n"
    wget "https://www.kernel.org/pub/software/scm/git/git-${version}.tar.gz" -O "${filename}" ;
fi
pdir="/u/git-${version}"
if [ ! -d "${pdir}" ] ; then
    mkdir -p "${pdir}"
    pushd "${pdir}"
    printf "untarring bundle\n"
    tar xzf $filename --strip-components=1
else
    pushd "${pdir}"
fi
printf "\e[32mbuilding!\e[0m\n"
make configure
./configure --prefix=/usr
make all doc
popd
popd
