#!/usr/bin/env bash

# Setup variables.
INDEX=$1
TOPIC_PATH=$2
TOPIC_FORMAT=$3
TOP_K=$4

./eswait.sh

# Perform the search.
cat ${TOPIC_PATH} | ./ielab_tsearcher ${INDEX} ${TOPIC_FORMAT} ${TOP_K} > output/${INDEX}-${TOP_K}.run