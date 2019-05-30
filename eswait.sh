#!/usr/bin/env bash

while true;
do
    echo "waiting for elasticsearch to become online..."
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" localhost:9200)
    if [[ ${STATUS} == "200" ]]
    then
        break
    fi
    echo "status was ${STATUS}"
    sleep 10
done