#!/usr/bin/env bash

sudo -u es ./elasticsearch/bin/elasticsearch -d

while true;
do
    echo "waiting for elasticsearch to become online..."
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" localhost:9200)
    echo "status is ${STATUS}"
    if [[ ${STATUS} == "200" ]]
    then
        # Just because status is 200 DOES NOT mean that Elasticsearch is ready.
        # Here, we are waiting until the cluster health becomes at least yellow.
        curl -s -X GET localhost:9200/_cluster/health?pretty\&wait_for_status=yellow\&wait_for_active_shards=all\&timeout=5m
        break
    fi
    sleep 10
done