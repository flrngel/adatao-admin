#!/bin/bash

function usage {
	echo "Usage: $0 <keyfile>"
	exit 1
}

keyfile=$1 ; [ -z "$keyfile" ] && usage

TEMP=/tmp/encrypt-key.$$ 

openssl rsa -in $keyfile -des3 > $TEMP && cp $TEMP $keyfile && chmod 600 $keyfile && rm -f $TEMP && echo "Encrypted $keyfile"
