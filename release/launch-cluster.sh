#!/bin/bash

default_ami_id="ami-1b050872"	# private_ami14
default_num_ebs_volumes="8"
default_ebs_vol_size="20"
default_instance_type="m3.2xlarge"
default_bigr_version="master"

usage() {
	echo ""
	echo "	Error: $1"
	echo "
	Usage: launch-cluster <cluster_name> <number_of_slaves>
		[--ami ami_id (default: $default_ami_id)]
		[--ebs num_ebs_volumes (default: $default_num_ebs_volumes) ebs_vol_size (default: $default_ebs_vol_size GB)]
		[--type instance_type (default: $default_instance_type)]
		[--bigr bigr_version (default: $default_bigr_version)]
		[--elastic-ip master_elastic_ip] (default: assigned)]
		[--resume ] (default: false)
	"
	exit 1
}

do_parse_args() {
	[[ -z "$1" ]] && usage ; cluster_name=$1 ; shift
	[[ -z "$1" ]] && usage ; num_slaves=$1 ; shift

	ami_id="$default_ami_id"
	num_ebs_volumes="$default_num_ebs_volumes"
	ebs_vol_size="$default_ebs_vol_size"
	instance_type="$default_instance_type"
	bigr_version="$default_bigr_version"
	hidden_logged_reentrant_callback=false
	
	while [[ -n "$1" ]] ; do
		case $1 in
			"--ami" )
				shift ; [[ -z "$1" ]] && usage "Must specify ami_id" ; ami_id=$1
				;;
			"--ebs" )
				shift ; [[ -z "$1" ]] && usage "Must specify num_ebs_volumes" ; num_ebs_volumes=$1
				shift ; [[ -z "$1" ]] && usage "Must specify ebs_vol_size" ; ebs_vol_size=$1
				;;
			"--type" )
				shift ; [[ -z "$1" ]] && usage "Must specify instance_type" ; instance_type=$1
				;;
			"--bigr" )
				shift ; [[ -z "$1" ]] && usage "Must specify big_version" ; bigr_version=$1
				;;
			"--elastic-ip" )
				shift ; [[ -z "$1" ]] && usage "Must specify master_elastic_ip" ; master_elastic_ip=$1
				;;
			"--hidden-logged-reentrant-callback" )
				shift ; hidden_logged_reentrant_callback=true
				;;
			"--resume" )
				shift ; resume=1
				;;
			* )
				usage "Unknown switch '$1'"
				;;
		esac
		shift
	done
	forks=$(expr $num_slaves + 1)
}

do_setup_log() {
	return
	if [ $hidden_logged_reentrant_callback == false ] ; then
		local me=`basename $0 .sh`
		local logfile=$DIR/logs/$me.log
		echo ++++++ Logging output to $log_file
		exec "$0" $@ --hidden-logged-reentrant-callback 2>&1 | tee $logfile
	fi
}

do_preamble() {
	DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
	do_parse_args $@
	do_setup_log $@
	source $DIR/security-setup.sh
	security_setup_preamble
}

do_launch() {
	echo ++++++ Creating random SSH key for use within new cluster
	local cluster_keyfile="/tmp/$cluster_name.pem" cluster_pubfile="/tmp/$cluster_name.pub"
	$DIR/keys/new-clear-key.sh $cluster_name 2>/dev/null
	mv $cluster_name.{pem,pub} /tmp

	echo ++++++ Launching cluster $cluster_name with $num_slaves slaves of type $instance_type
	set -x
	${DIR}/spark-ec2/spark-ec2 \
		-a ${ami_id} \
		-k ${admin_ssh_key} \
		-i ${cluster_keyfile} \
		-p ${cluster_pubfile} \
		-s ${num_slaves} \
		--instance-type=${instance_type} \
		-w 120 \
		--zone=us-east-1e \
		--cluster-type=mesos \
		--num-ebs-vols=${num_ebs_volumes} \
		--ebs-vol-size=${ebs_vol_size} \
		--no-ganglia \
		--periodic-command "echo%20sudo-keepalive" \
		`if [[ -n ${master_elastic_ip} ]]; then echo "--elastic-ip=${master_elastic_ip}"; fi` \
		`if [[ -n $resume ]]; then echo "--resume"; fi` \
		launch ${cluster_name} || exit 1
	set +x
}

do_enumerate_hosts() {
	# This is now already taken care of fairly early within spark_ec2.py
	#echo ++++++ Update local /etc/hosts to include new cluster
	#echo ""
	#echo "#### Note: you may be required to enter your password for a sudo operation here ####"
	#${DIR}/update-etc-hosts.sh ${cluster_name}

	echo ++++++ Store cluster node list to a file
	${DIR}/spark-ec2/spark-ec2 nodelist2file  ${cluster_name} -f /tmp/${cluster_name} || exit 1
}

do_configure() {
	export ANSIBLE_SSH_ARGS="-o StrictHostKeyChecking=no -o ForwardAgent=yes"
	
	#echo ++++++ Install BigR
	#ansible-playbook ${DIR}/yml/install-bigr-server.yml -f $forks -i /tmp/${cluster_name} --extra-vars "bigr_version=${bigr_version}" || exit 1

	#echo ++++++ Install libmesos
	#ansible-playbook ${DIR}/yml/install-mesos.yml -f $forks -i /tmp/${cluster_name} --extra-vars "mesos_version=${mesos_version}"

	#echo ++++++ Install mysql
	#ansible-playbook ${DIR}/yml/install-mysql-metadata-server-newami.yml -i /tmp/${cluster_name} || exit 1

	#echo ++++++ "Ensure R & Rserve is installed and running"
	#ansible-playbook ${DIR}/yml/install-r.yml -i /tmp/${cluster_name}  -f $forks || exit 1

	#master=$(sed -n 2p /tmp/${cluster_name})
	
	echo ++++++ Ensure services are running
	ansible-playbook ${DIR}/yml/start-cluster.yml -i /tmp/${cluster_name} || exit 1	
	
	echo ++++++ Create airline table
	ansible-playbook ${DIR}/yml/create-airline-table.yml -i /tmp/${cluster_name} || exit 1
}

do_postamble() {
	security_setup_postamble
}

do_run() {
	do_preamble $@
	do_launch
	do_enumerate_hosts
	do_configure
	do_postamble
}

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cluster_string=$(cat ${DIR}/elasticip.csv | grep ${cluster_name})
echo "Cluster string is: "${cluster_string}
master_elastic_ip=$(echo ${cluster_string} | cut -d',' -f2) 

do_run $@
