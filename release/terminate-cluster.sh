#!/bin/bash

cluster_name=$1

usage() {
echo "Usage: terminate-cluster <cluster_name>"
exit 1
}

[[ -n "$1" ]] || { usage; }

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo ++++++ Terminate cluster $cluster_name
${DIR}/spark-ec2/spark-ec2 destroy ${cluster_name}

echo ++++++ Remove nodelist file
rm /tmp/$cluster_name