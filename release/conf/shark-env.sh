#!/usr/bin/env bash

# Set Spark's memory per machine -- you might want to increase this
export SHARK_MASTER_MEM=3g

# Java options
SPARK_JAVA_OPTS+=" -Dspark.kryoserializer.buffer.mb=10"
#SPARK_JAVA_OPTS+="-verbose:gc -XX:-PrintGCDetails -XX:+PrintGCTimeStamps "
export SPARK_JAVA_OPTS

export HIVE_HOME=/root/hive/build/dist
export HADOOP_HOME=/root/ephemeral-hdfs
export HADOOP_PREFIX=/root/ephemeral-hdfs

export MASTER=`cat /root/spark-ec2/cluster-url`
export MESOS_NATIVE_LIBRARY=/usr/local/lib/libmesos.so
export SPARK_HOME=/root/spark
export SPARK_CLASSPATH=/root/BigR/lib_managed/jars/mysql-connector-java-5.1.25.jar

source $SPARK_HOME/conf/spark-env.sh
