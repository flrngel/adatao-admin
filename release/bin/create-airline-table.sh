#!/bin/bash 

if [/root/ephemeral-hdfs/bin/hadoop fs -test -d /airline -eq 0]; then
  echo "airline already in HDFS"
  #/root/ephemerial-hdfs/bin/hadoop fs -rmr /airline
else
  echo "put airline data into HDFS"
  /root/ephemeral-hdfs/bin/hadoop fs -put /root/airline/ /
fi

source /root/shark/conf/shark-env.sh

/root/shark/bin/shark -e "drop table if exists airline; create external table airline (Year int,Month int,DayofMonth int,DayOfWeek int,DepTime int,CRSDepTime int,ArrTime int,CRSArrTime int,UniqueCarrier string, FlightNum int, TailNum string, ActualElapsedTime int, CRSElapsedTime int, AirTime int, ArrDelay int, DepDelay int, Origin string, Dest string, Distance int, TaxiIn int, TaxiOut int, Cancelled int, CancellationCode string, Diverted string, CarrierDelay int, WeatherDelay int, NASDelay int, SecurityDelay int, LateAircraftDelay int ) ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS TEXTFILE LOCATION '\/airline/';"


