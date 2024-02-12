#!/bin/bash

/bin/sh

function addProperty() {
  local path=$1
  local name=$2
  local value=$3

  local entry="<property><name>$name</name><value>${value}</value></property>"
  # shellcheck disable=SC2155
  local escapedEntry=$(echo "$entry" | sed 's/\//\\\//g')
  sed -i "/<\/configuration>/ s/.*/${escapedEntry}\n&/" "$path"
}

function configure() {
    local path=$1
    local module=$2
    local envPrefix=$3

    local var
    local value

    echo "Configuring $module"
    for c in $(printenv | perl -sne 'print "$1 " if m/^${envPrefix}_(.+?)=.*/' -- -envPrefix="$envPrefix"); do
        name=$(echo "${c}" | perl -pe 's/___/-/g; s/__/@/g; s/_/./g; s/@/_/g;')
        var="${envPrefix}_${c}"
        value=${!var}
        echo " - Setting $name=$value"
        addProperty "$path" "$name" "$value"
    done
}

export HADOOP_HOME=/opt/hadoop-3.2.0
export HADOOP_CLASSPATH=${HADOOP_HOME}/share/hadoop/tools/lib/aws-java-sdk-bundle-1.11.375.jar:${HADOOP_HOME}/share/hadoop/tools/lib/hadoop-aws-3.2.0.jar
export JAVA_HOME=/usr/local/openjdk-8

configure "$HIVE_HOME"/conf/metastore-site.xml "Hive metastore" HIVE_SITE_CONF

if [ -n "$CA_CERTIFICATE_FILE" ]; then
  cp "$CA_CERTIFICATE_FILE" /usr/local/share/ca-certificates/
  update-ca-certificates
  #rm -f /usr/local/share/ca-certificates/*
fi

# shellcheck disable=SC2154
DB_HOST=$(echo "$HIVE_SITE_CONF_javax_jdo_option_ConnectionURL" | awk -F/ '{print $3}' | awk -F: '{print $1}')

# Make sure Postgres is ready
MAX_TRIES=10000
CURRENT_TRY=1
SLEEP_BETWEEN_TRY=4
until [ "$(telnet "${DB_HOST}" 5432 | sed -n 2p)" = "Connected to ${DB_HOST}." ] || [ "$CURRENT_TRY" -gt "$MAX_TRIES" ]; do
    echo "Waiting for Postgres server..."
    sleep "$SLEEP_BETWEEN_TRY"
    CURRENT_TRY=$((CURRENT_TRY + 1))
done

if [ "$CURRENT_TRY" -gt "$MAX_TRIES" ]; then
  echo "WARNING: Timeout when waiting for Postgres."
fi

# Check if schema exists
"$HIVE_HOME"/bin/schematool -dbType postgres -info

if [ $? -eq 1 ]; then
  echo "Getting schema info failed. Probably not initialized. Initializing..."
  "$HIVE_HOME"/bin/schematool -initSchema -dbType postgres
fi

# shellcheck disable=SC2086
$HIVE_HOME/bin/start-metastore
