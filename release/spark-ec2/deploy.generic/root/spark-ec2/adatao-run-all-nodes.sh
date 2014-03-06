#!/bin/bash
#
# @author ctn@adatao.com
# @date Tue Aug  6 10:08:53 PDT 2013
#
# This script will be copied to /root/spark-ec2 and invoked by spark_ec2.py
# before doing any other setup tasks.
#

usage() {
	echo ""
	echo "Use this script to run something for all nodes, including masters and slaves."
	echo "Usage: $0 <command>"
	exit 1
}

command="$@" ; [ -z "$command" ] && usage

PATH+=:/sbin

# Make sure we are in the spark-ec2 directory
cd /root/spark-ec2

# Load the environment variables specific to this AMI
source /root/.bash_profile

source ec2-variables.sh

dir="`pwd`"
for node in $MESOS_MASTERS $MESOS_SLAVES ; do
	#ssh -o StrictHostKeyChecking=no -o ForwardAgent=yes $node "cd $dir ; $command"
	ssh -o StrictHostKeyChecking=no $node "cd $dir ; $command"
done
