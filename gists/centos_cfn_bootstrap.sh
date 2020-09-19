#!/bin/bash
# should be run as root

yum -y install python27 python27-devel wget
mkdir -p /u/downloads
cd /u/downloads
url=https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz
filename=/u/downloads/aws-cfn-bootstrap.tar.gz
mkdir -p /opt/aws/bin
wget $url -O $filename
if [[ -e /usr/bin/pip2.7 ]] || [[ -e /usr/local/bin/pip2.7 ]] ; then
    pip2.7 install $filename
    prefix=$(dirname $(which pip2.7))
else 
    pip install $filename
    prefix=$(dirname $(which pip))
fi
ln -s "$(dirname prefix)/init/redhat/cfn-hup" /etc/init.d/cfn-hup
chmod 775 "$(dirname prefix)/init/redhat/cfn-hup"
ln -s $prefix/cfn-hup /opt/aws/bin/cfn-hup
ln -s $prefix/cfn-signal /opt/aws/bin/cfn-signal
ln -s $prefix/cfn-init /opt/aws/bin/cfn-init
ln -s $prefix/cfn-get-metadata /opt/aws/bin/cfn-get-metadata
ln -s $prefix/cfn-send-cmd-event /opt/aws/bin/cfn-send-cmd-event
ln -s $prefix/cfn-send-cmd-result /opt/aws/bin/cfn-send-cmd-result

