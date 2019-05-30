#!/usr/bin/env bash

cd /

sudo -u es ./elasticsearch/bin/elasticsearch -d
./eswait.sh

# Setup variables.
INDEX=$1
TOPIC_PATH=$2
TOPIC_FORMAT=$3
TOP_K=$4

# Perform the search.
cat ${TOPIC_PATH} | ./ielab_tsearcher ${INDEX} ${TOPIC_FORMAT} ${TOP_K} > ${INDEX}-${TOP_K}