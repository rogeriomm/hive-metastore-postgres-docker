ARG HADOOP_VERSION=3.2.0

FROM maven:3.9.0 as maven

ARG HADOOP_VERSION

COPY dependencies/pom.xml /root

WORKDIR /root

RUN mvn clean install dependency:copy-dependencies -Dhadoop.version=${HADOOP_VERSION}

FROM openjdk:8u342-jre

RUN apt-get update \
 && apt-get upgrade --assume-yes \
 && apt-get install --assume-yes telnet vim \
 && apt-get clean

WORKDIR /opt

ARG HADOOP_VERSION

ENV METASTORE_VERSION=3.0.0

ENV HADOOP_HOME=/opt/hadoop-${HADOOP_VERSION}
ENV HIVE_HOME=/opt/apache-hive-metastore-${METASTORE_VERSION}-bin

# https://techjogging.com/standalone-hive-metastore-presto-docker.html
# https://cwiki.apache.org/confluence/display/Hive/AdminManual+Metastore+3.0+Administration
# https://gitee.com/fenglinliu/docker-hive/tree/master GANGLIA
RUN curl -L https://apache.org/dist/hive/hive-standalone-metastore-${METASTORE_VERSION}/hive-standalone-metastore-${METASTORE_VERSION}-bin.tar.gz | tar zxf - && \
    curl -L https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz | tar zxf - && \
    curl -L https://repo1.maven.org/maven2/org/postgresql/postgresql/42.6.0/postgresql-42.6.0.jar  --output /tmp/postgresql.jar && \
    mv /tmp/postgresql.jar ${HIVE_HOME}/lib

COPY conf/metastore-site.xml ${HIVE_HOME}/conf
COPY scripts/entrypoint.sh /entrypoint.sh

RUN groupadd -r hive --gid=1000 && \
    useradd -r -g hive --uid=1000 -d ${HIVE_HOME} hive && \
    chown hive:hive -R ${HIVE_HOME} && \
    chown hive:hive /entrypoint.sh && chmod +x /entrypoint.sh

# Install MINIO client
RUN wget -nv -O /tmp/mc https://dl.min.io/client/mc/release/linux-amd64/mc && \
    mkdir -p /opt/minio/bin && \
    mv /tmp/mc /opt/minio/bin && \
    chmod +x /opt/minio/bin/mc
ENV PATH $PATH:/opt/minio/bin

COPY --from=maven /root/target/dependency/. ${HIVE_HOME}/lib/

RUN rm $HADOOP_HOME/share/hadoop/common/lib/slf4j-log4j12-1.7.25.jar

USER root
EXPOSE 9083

ENTRYPOINT ["sh", "-c", "/entrypoint.sh"]
