#!/bin/bash

# run in subshell so that `exit 0` terminates the sub-shell only
(
	while true; do
		pgrep -fl Rserve || exit 0
		pkill -f Rserve
		sleep 1
	done
)

# This command will deamonize, but using nohup works nicer with Ansible.
# http://rforge.net/Rserve/doc.html
# http://stat.ethz.ch/R-manual/R-devel/library/base/html/Startup.html
nohup R CMD Rserve --vanilla --RS-workdir /mnt/Rserv/ --RS-encoding utf8 >> /mnt/log/Rserve.log 2>&1 &

sleep 2

pgrep -fl Rserve || echo "Error: No 'Rserve' process found. Something is wrong"
