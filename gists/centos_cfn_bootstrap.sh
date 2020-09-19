#!/bin/bash
# should be run as root

yum -y install python27 python27-devel wget
mkdir -p /u/downloads
cd /u/downloads
url=https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz
filename=/u/downloads/aws-cfn-bootstrap.tar.gz
wget $url -O $filename
pip2.7 install $filename
mkdir -p /opt/aws/bin
ln -s /usr/init/redhat/cfn-hup /etc/init.d/cfn-hup
chmod 775 /usr/init/redhat/cfn-hup
ln -s /usr/bin/cfn-hup /opt/aws/bin/cfn-hup
ln -s /usr/bin/cfn-signal /opt/aws/bin/cfn-signal
ln -s /usr/bin/cfn-init /opt/aws/bin/cfn-init
ln -s /usr/bin/cfn-get-metadata /opt/aws/bin/cfn-get-metadata
ln -s /usr/bin/cfn-signal /opt/aws/bin/cfn-signal
ln -s /usr/bin/cfn-send-cmd-event /opt/aws/bin/cfn-send-cmd-event
ln -s /usr/bin/cfn-send-cmd-result /opt/aws/bin/cfn-send-cmd-result

