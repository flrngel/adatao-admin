#!/bin/bash

function usage {
	echo "Usage: $0 <keyfile>"
	exit 1
}

keyfile=$1 ; [ -z "$keyfile" ] && usage
[ ! -e $keyfile ] && keyfile="$keyfile.pem"
pubfile="`basename $keyfile .pem`.pub"

#openssl rsa -in $keyfile -pubout -out $pubfile && chmod 600 $pubfile
ssh-keygen -y -f $keyfile > $pubfile && chmod 600 $pubfile
echo "Created public key file $pubfile"
