#!/usr/bin/env bash

# echo commands to the terminal output
set -ex

enablePVC=$1
enableGCS=$2
eventsDir=$3
gcloudKey=$4

# Check whether there is a passwd entry for the container UID
uid=$(id -u)
gid=$(id -g)
# turn off -e for getent because it will return error code in anonymous uid case
set +e
uid_entry=$(getent passwd ${uid})
set -e

# If there is no passwd entry for the container UID, attempt to create one
if [[ -z "${uid_entry}" ]] ; then
    if [[ -w /etc/passwd ]] ; then
        echo "$uid:x:$uid:$gid:anonymous uid:${SPARK_HOME}:/bin/false" >> /etc/passwd
    else
        echo "Container entrypoint.sh failed to add passwd entry for anonymous UID"
    fi
fi

if [[ "$enablePVC" == "true" ]]; then
    export SPARK_HISTORY_OPTS="$SPARK_HISTORY_OPTS \
    -Dspark.history.fs.logDirectory=file:/mnt/$eventsDir";
elif [[ "$enableGCS" == "true" ]]; then
    if [[ -n ${gcloudKey} ]]; then
      export SPARK_HISTORY_OPTS="$SPARK_HISTORY_OPTS \
      -Dspark.hadoop.google.cloud.auth.service.account.json.keyfile=/etc/secrets/$gcloudKey \
      -Dspark.history.fs.logDirectory=$eventsDir";
    else
      echo "Please pass your Google Cloud Key!"
      exit 1
    fi
else
    export SPARK_HISTORY_OPTS="$SPARK_HISTORY_OPTS \
    -Dspark.history.fs.logDirectory=$eventsDir";
fi;

exec /sbin/tini -s -- /opt/spark/bin/spark-class org.apache.spark.deploy.history.HistoryServer
