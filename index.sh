#!/usr/bin/env bash

cd /

# Setup variables.
COLLECTION_PATH=$1
INDEX=$2
COLLECTION_FORMAT=$3

sudo -u es ./elasticsearch/bin/elasticsearch -d
./eswait.sh

# Iterate over each file in the collection path, parsing each
# one as it sees it, then bulk indexing the file.
for filename in ${COLLECTION_PATH}/*; do
    cat ${filename} | ./ielab_cparser ${INDEX} ${COLLECTION_FORMAT} trecweb > requests
    curl -s -H "Content-Type: application/x-ndjson" -X POST localhost:9200/_bulk --data-binary "@requests"; echo
done

# Tidy up the file containing the bulk request at the end.
rm requests