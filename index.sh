#!/usr/bin/env bash

# The path of the collection
COLLECTION=$1

# Start elasticsearch if it is not already started.
if [[ -n "$(pgrep java)" ]]; then
	echo "elasticsearch already started, not starting again."
else
   ./elasticsearch/bin/elasticsearch -d
fi

for filename in ${COLLECTION}/*; do
    cat ${filename} | ./ielab_cparser $1 trecweb > requests
    curl -s -H "Content-Type: application/x-ndjson" -X POST localhost:9200/_bulk --data-binary "@requests"; echo
done

rm requests