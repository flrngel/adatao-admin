#!/bin/bash
#
# Creates/updates /etc/hosts entries for given cluster name
#

DIR="$(cd `dirname $0` 2>&1 >/dev/null ; pwd)"
SSH="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ForwardAgent=yes"

function usage {
	echo ""
	echo "Usage: $0 [[--do-set-hostnames] cluster_name (default: all clusters)]"
	exit 1
}


function list_clusters {
	$DIR/list-clusters.sh
}


function update_one_host {
	local ip=$1
	local hostname=$2
	local cluster_name=$3
	echo "$ip	$hostname	# ADATAO_MAGIC cluster = $cluster_name" >> $TEMP
	[ "$do_set_hostnames" == true ] && $SSH root@$ip "hostname $hostname ; echo $hostname > /etc/hostname"
}

function update_one_cluster {
	local cluster_name=$1

	$DIR/spark-ec2/spark-ec2 nodelist2file $cluster_name -f /tmp/$cluster_name || exit 1

	# ec2-174-129-8-171.compute-1.amazonaws.com
	master_ip=`grep master -A1 /tmp/$cluster_name | grep -v master | cut -f1 -d. | cut -f2-5 -d- | sed -e 's/-/./g'`
	slave_ips=(`grep slave -A20 /tmp/$cluster_name | grep -v slave | cut -f1 -d. | cut -f2-5 -d- | sed -e 's/-/./g'`)

	TEMP=/tmp/hosts.$$
	cp /etc/hosts $TEMP

	sed -i -e "/ADATAO_MAGIC cluster = $cluster_name/d" $TEMP

	if [ -n "$master_ip" ] ; then

		echo "######### ADATAO_MAGIC cluster = $cluster_name" >> $TEMP
		# 174.129.8.171        master3	# ADATAO_MAGIC cluster = spark3
		update_one_host $master_ip $cluster_name $cluster_name

		slave_no=1
		for ip in ${slave_ips[*]} ; do
			update_one_host $ip ${cluster_name}-${slave_no} ${cluster_name}
			slave_no=$((slave_no+1))
		done

	fi

	grep $cluster_name $TEMP

	set -x
	sudo cp $TEMP /etc/hosts
	set +x
	rm -f $TEMP
}

function run {
	do_set_hostnames=false
	[ "$1" == "--do-set-hostnames" ] && do_set_hostnames=true && shift

	local clusters
	if [ -n "$1" ] ; then
		clusters=($1) ; shift
	else
		do_set_hostnames=false # don't allow accidental setting of hostnames for all clusters

		# Since we're doing all clusters, get rid of all old entries
		sudo sed -i -e "/ADATAO_MAGIC cluster =/d" /etc/hosts

		clusters=(`list_clusters`)
	fi

	local cluster
	for cluster in ${clusters[*]} ; do
		update_one_cluster $cluster
	done
}

set -x ; sudo echo NEED_SUDO_TO_UPDATE_ETC_HOSTS_FOR_YOU ; set +x
run $@
