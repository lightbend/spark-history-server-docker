#!/usr/bin/env bash

# echo commands to the terminal output
set -ex

enablePVC=

enableGCS=
gcloudKey=

enableS3=
enableIAM=
accessKeyName=
secretKeyName=

enableWASBS=
storageAccountName=
containerName=
sasKeyMode=
sasKeyName=
storageAccountKeyName=

eventsDir=

function usage {
  cat<< EOF
  Usage: entrypoint.sh  [OPTIONS]

  Options:

  --pvc                                                 Enable PVC
  --gcs gcloudkey                                       Enable GCS and provide the Google Cloud key
  --s3 enableIAM accessKeyName secretKeyName            Enable S3 and configure whether IAM is enabled,
                                                        the accessKeyName and secretKeyName
  --wasbs storageAccountName containerName sasKeyMode \ Enable WASBS and configure its params.
          sasKeyName(or storageAccountKeyName)          If sasKeyMode=true - provide sasKeyName as last arg,
                                                        else provide storageAccountKeyName as last arg
  --events-dir events-dir                               Set events dir
  -h | --help                                           Prints this message.
EOF
}

function parse_args {
  while [[ $# -gt 0 ]]
  do
    case "$1" in
      --pvc)
        enablePVC=true
        shift
        continue
      ;;
      --gcs)
        enableGCS=true
        if [[ -n "$2" ]]; then
          gcloudKey=$2
          shift 2
          continue
        else
          printf '"--gcs" requires a non-empty option argument.\n'
          usage
          exit 1
        fi
      ;;
      --s3)
      if [[ -n "$4" ]]; then
        enableS3=true
        enableIAM=$2
        accessKeyName=$3
        secretKeyName=$4
        shift 4
        continue
      else
        printf '"--s3" require three non-empty option arguments.\n'
        usage
        exit 1
      fi
      ;;
      --wasbs)
      if [[ -n "$5" ]]; then
        enableWASBS=true
        storageAccountName=$2
        containerName=$3
        sasKeyMode=$4
        if [ "$sasKeyMode" == "true" ];
          sasKeyName=$5
        else
          storageAccountKeyName=$5
        fi
        shift 5
        continue
      else
        printf '"--wasbs" require four non-empty option arguments.\n'
        usage
        exit 1
      fi
      ;;
      --events-dir)
        if [[ -n "$2" ]]; then
          eventsDir=$2
          shift 2
          continue
        else
          printf '"--events-dir" requires a non-empty option argument.\n'
          usage
          exit 1
        fi
      ;;
      -h|--help)
        usage
        exit 0
      ;;
      --)
        shift
        break
      ;;
      '')
        break
      ;;
      *)
        printf "Unrecognized option: $1\n"
        exit 1
      ;;
    esac
    shift
  done
}

parse_args "$@"

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
elif [[ "$enableS3" == "true" ]]; then
    export SPARK_HISTORY_OPTS="$SPARK_HISTORY_OPTS \
      -Dspark.history.fs.logDirectory=$eventsDir
      -Dspark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem";
    if [[ "$enableIAM" == "false" ]]; then
      export SPARK_HISTORY_OPTS="$SPARK_HISTORY_OPTS \
      -Dspark.hadoop.fs.s3a.access.key=$(cat /etc/secrets/${accessKeyName}) \
      -Dspark.hadoop.fs.s3a.secret.key=$(cat /etc/secrets/${secretKeyName})";
    fi;
elif [ "$enableWASBS" == "true" ]; then
  export SPARK_HISTORY_OPTS="$SPARK_HISTORY_OPTS \
    -Dspark.history.fs.logDirectory=$eventsDir \
    -Dspark.hadoop.fs.defaultFS=wasbs://$containerName@$storageAccountName.blob.core.windows.net \
    -Dspark.hadoop.fs.wasbs.impl=org.apache.hadoop.fs.azure.NativeAzureFileSystem \
    -Dspark.hadoop.fs.AbstractFileSystem.wasbs.impl=org.apache.hadoop.fs.azure.Wasbs";
  if [ "$sasKeyMode" == "true" ]; then
    export SPARK_HISTORY_OPTS="$SPARK_HISTORY_OPTS \
      -Dspark.hadoop.fs.azure.local.sas.key.mode=true \
      -Dspark.hadoop.fs.azure.sas.$containerName.$storageAccountName.blob.core.windows.net=$(cat /etc/secrets/${sasKeyName})";
  else
    export SPARK_HISTORY_OPTS="$SPARK_HISTORY_OPTS \
      -Dspark.hadoop.fs.azure.account.key.$storageAccountName.blob.core.windows.net=$(cat /etc/secrets/${storageAccountKeyName})";
  fi;
else
    export SPARK_HISTORY_OPTS="$SPARK_HISTORY_OPTS \
    -Dspark.history.fs.logDirectory=$eventsDir";
fi;

exec /sbin/tini -s -- /opt/spark/bin/spark-class org.apache.spark.deploy.history.HistoryServer
