#!/usr/bin/env bash

# Setup variables.
COLLECTION_PATH=$1
INDEX=$2
COLLECTION_FORMAT=$3

./eswait.sh

curl -s -H "Content-Type: application/json" -X PUT localhost:9200/${INDEX}?wait_for_active_shards=1 -d '{"settings": {"number_of_shards": 1}}'; echo

# Iterate over each file in the collection path, parsing each
# one as it sees it, then bulk indexing the file.
for filename in ${COLLECTION_PATH}/*; do
    cat ${filename} | ./ielab_cparser ${INDEX} ${COLLECTION_FORMAT} trecweb > requests
    curl -s -H "Content-Type: application/x-ndjson" -X POST localhost:9200/${INDEX}/_bulk?wait_for_active_shards=1\&refresh=wait_for --data-binary "@requests"; echo
done

# Tidy up the file containing the bulk request at the end.
rm requests

curl -s -o /dev/null -X POST localhost:9200/${INDEX}/_refresh?pretty
curl -s -X GET localhost:9200/${INDEX}/_count?pretty | grep count | sed 's/["| |,]//g'