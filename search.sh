#!/usr/bin/env bash

COLLECTION=$1
TOPIC=$2
TOPIC_FORMAT=$3
TOP_K=$4


# Start elasticsearch if it is not already started.
if [[ -n "$(pgrep java)" ]]; then
	echo "elasticsearch already started, not starting again."
else
   ./elasticsearch/bin/elasticsearch -d
fi

cat ${TOPIC} | ./ielab_searcher ${COLLECTION} ${TOPIC_FORMAT} ${TOP_K} > ${COLLECTION}-${TOP_K}