#!/bin/bash

usage() {
	[ -n "$1" ] && echo "Error: $1"
	echo "Usage: start-cluster <cluster_name> <--elastic-ip elastic_ip>"
	exit 1
}

[[ -n "$1" ]] || { usage; }

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

[[ -z "$1" ]] && usage ; cluster_name=$1 ; shift
[[ -z "$1" ]] && usage ;

while [[ -n "$1" ]] ; do
	case $1 in
		"--elastic-ip" )
			shift ; [[ -z "$1" ]] && usage "Must specify elastic-ip" ; elastic_ip=$1
			;;
		* )
			usage "Unknown switch '$1'"
			;;
	esac
	shift
done
	
zone="us-east-1e"

echo ++++++ Start cluster $cluster_name with cluster string: $cluster_string
set -x
${DIR}/spark-ec2/spark-ec2 \
	--zone=us-east-1e \
	--num-ebs-vols=8 \
	--cluster-type=mesos \
	--no-ganglia \
	--elastic-ip=${elastic_ip} \
	start ${cluster_name}  || exit 1
set +x

echo ++++++ Store cluster node list to a file
${DIR}/spark-ec2/spark-ec2 nodelist2file  ${cluster_name} -f /tmp/${cluster_name} || exit 1

forks=$(wc -l < /tmp/${cluster_name})

echo ++++++ Ensure services are running
ansible-playbook ${DIR}/yml/start-cluster.yml -i /tmp/${cluster_name} || exit 1
