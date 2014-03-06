#!/bin/bash

function usage {
	echo "Usage: $0 <keyfile>"
	exit 1
}

keyfile=$1 ; [ -z "$keyfile" ] && usage

TEMP=/tmp/decrypt-key.$$

openssl rsa -in $keyfile > $TEMP && cp $TEMP $keyfile && chmod 600 $keyfile && rm -f $TEMP && echo "Decrypted $keyfile"
