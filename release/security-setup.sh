#!/bin/bash
#
# This file must be sourced at the top of each admin script to ensure you have
# the proper credentials for SSH'ing and GIT'ing and sudo'ing, etc.
#
# You should always add at the end of the admin script this command: ssh-agent -k.
# This kills the ssh-agent we spawn here, so you don't have too many of them running around.
#

security_setup_preamble() {
	export admin_ssh_key="adatao2" # This must be a key known to AWS, and a secure key that has no cleartext .pem files lying around
	#export git_ssh_key="adatao-git" # This must be a key registered with github.com


	local DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" ; cd $DIR

	#echo "++++++ sudo once now so we won't be stopped half way through"
	#echo % sudo echo PASSED SUDO ; sudo echo PASSED SUDO

	#echo "++++++ Set up SSH agent and import all keys"
	local candidate_key_files="$HOME/.ssh/id_rsa $HOME/.ssh/*.pem keys/*.pem"
	local admin_key_found=false 
	#local git_key_found=false

	we_started_ssh_agent=false ; [ -z "$SSH_AGENT_PID" -a -z "$SSH_AUTH_SOCK" ] && eval `ssh-agent` && we_started_ssh_agent=true
	local existing_keys=(`ssh-add -l | cut -f3 -d' '`)

	local key_files=""
	for candidate in $candidate_key_files ; do
		if [ -e $candidate ] ; then
			local agent_already_has_key=false
			for existing_key in ${existing_keys[*]} ; do
				[ "`basename $existing_key`" == "`basename $candidate`" ] && agent_already_has_key=true && break
			done
			[ "$agent_already_has_key" == false ] && key_files+=" $candidate"
		fi

		[ `basename $candidate .pem` == $admin_ssh_key ] && local admin_key_found=true
		#[ `basename $candidate .pem` == $git_ssh_key ] && local git_key_found=true
	done

	#[ $git_key_found == false ] && echo "ERROR: Cannot find git_ssh_key $git_ssh_key.pem under $HOME/.ssh or $DIR/keys. Please fix." && exit 1
	[ $admin_key_found == false ] && echo "ERROR: Cannot find admin_ssh_key $admin_ssh_key.pem under $HOME/.ssh or $DIR/keys. Please fix." && exit 1

	[ -n "$key_files" ] && ssh-add $key_files
}

security_setup_postamble() {
	[ "$we_started_ssh_agent" == true ] && ssh-agent -k # kill it so we don't have too many lying around
}
