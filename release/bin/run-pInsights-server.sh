#!/bin/bash

# run in subshell so that `exit 0` terminates the sub-shell only
(
	while true; do
		pgrep -fl ipython || exit 0
		pkill -f ipython
		sleep 1
	done
)

# those are for getting rJava to work inside IPython or RStudio
export JAVA_HOME=/usr/lib/jvm/java-1.7.0-openjdk-1.7.0.19.x86_64/jre
export LD_LIBRARY_PATH=/lib:/lib/amd64/server:/usr/java/packages/lib/amd64:/usr/lib:/usr/lib/jvm/java-1.7.0-openjdk-1.7.0.19.x86_64/jre/:/usr/lib/jvm/java/lib/amd64:/usr/lib/jvm/jre/lib/amd64:/usr/lib/jvm/jre/lib/amd64/server:/usr/lib64/R/lib:/usr/lib64/R/library/:/usr/local/lib64

export BIGR_HOST={{ pAnalytics_host }}
export BIGR_PORT={{ pAnalytics_port }}

nohup {{ pInsights_venv_dir }}/bin/ipython notebook --ipython-dir={{ pInsights_dir }} --profile=adatao --pylab=inline --log-level=DEBUG >> {{ pInsights_log_file }} &
