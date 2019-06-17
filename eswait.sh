#!/usr/bin/env bash

sudo -u es ./elasticsearch/bin/elasticsearch -d

while true;
do
    echo "waiting for elasticsearch to become online..."
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" localhost:9200)
    echo "status is ${STATUS}"
    if [[ ${STATUS} == "200" ]]
    then
        break
    fi
    sleep 10
done