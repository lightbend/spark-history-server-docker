ARG SPARK_IMAGE=gcr.io/spark-operator/spark:v2.4.0
FROM ${SPARK_IMAGE}

# Set up dependencies for Google Cloud Storage access.
RUN rm $SPARK_HOME/jars/guava-14.0.1.jar
ADD http://repo1.maven.org/maven2/com/google/guava/guava/23.0/guava-23.0.jar $SPARK_HOME/jars
# Add the connector jar needed to access Google Cloud Storage using the Hadoop FileSystem API.
ADD https://storage.googleapis.com/hadoop-lib/gcs/gcs-connector-latest-hadoop2.jar $SPARK_HOME/jars

# Add dependency for hadoop-aws
ADD http://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk/1.7.4/aws-java-sdk-1.7.4.jar $SPARK_HOME/jars
# Add hadoop-aws to access Amazon S3
ADD http://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/2.7.5/hadoop-aws-2.7.5.jar $SPARK_HOME/jars

# Add dependency for hadoop-azure
ADD http://repo1.maven.org/maven2/com/microsoft/azure/azure-storage/2.0.0/azure-storage-2.0.0.jar $SPARK_HOME/jars
# Add hadoop-azure to access Azure Blob Storage
ADD http://repo1.maven.org/maven2/org/apache/hadoop/hadoop-azure/2.7.3/hadoop-azure-2.7.3.jar $SPARK_HOME/jars

ENTRYPOINT ["/opt/entrypoint.sh"]
