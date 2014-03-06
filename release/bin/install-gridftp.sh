#!/bin/bash

curl -O http://www.globus.org/ftppub/latest-stable/gt-latest-stable-all-source-installer.tar.bz2
tar -xvfz gt-latest-stable-all-source-installer.tar.gz
mkdir -p /usr/local/globus-5.0.4
export GLOBUS_LOCATIO=/usr/local/globus-5.0.4
cd /root/gt5.0.4-all-source-installer/ 
./configure --prefix=/usr/local/globus-5.0.4
make
make install

