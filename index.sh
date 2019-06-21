#!/usr/bin/env bash

# Setup variables.
COLLECTION_PATH=$1
INDEX=$2
COLLECTION_FORMAT=$3


# Portions of this code copied from https://github.com/osirrc/indri-docker.

# The mounted collection folder is read-only, we need a writable folder.
COLLECTION_PATH_WRITABLE=${COLLECTION_PATH}"-WRITABLE"
echo "robust04 ... Copying files of directory ${COLLECTION_PATH} into ${COLLECTION_PATH_WRITABLE}"
cp -r ${COLLECTION_PATH} ${COLLECTION_PATH_WRITABLE}

if [[ ${INDEX} == "robust04" ]]
then
    # Remove the unwanted parts of disk45 (as per ROBUST04 guidelines)
    rm -r ${COLLECTION_PATH_WRITABLE}/disk4/cr
    rm -r ${COLLECTION_PATH_WRITABLE}/disk4/dtds
    rm -r ${COLLECTION_PATH_WRITABLE}/disk5/dtds

    # Robust04 has a folder with `NAME.0z`, `NAME.1z` and `NAME.2z` files, simply using gunzip
    # is not an option as files are being overwritten (same name, different suffix);
    # hacked solution: add ".z" to every single file in the collection path.
    find ${COLLECTION_PATH_WRITABLE} -name "*.0z" -type f -exec mv '{}' '{}'.z \;
    find ${COLLECTION_PATH_WRITABLE} -name "*.1z" -type f -exec mv '{}' '{}'.z \;
    find ${COLLECTION_PATH_WRITABLE} -name "*.2z" -type f -exec mv '{}' '{}'.z \;
    # Decompress.
    echo "robust04 ... Uncompressing"
    gunzip -v --suffix=".z" -r ${COLLECTION_PATH_WRITABLE}
fi

# Wait for Elasticsearch.
./eswait.sh

# Create the index.
curl -s -H "Content-Type: application/json" -X PUT localhost:9200/${INDEX}?wait_for_active_shards=1 -d '{"settings": {"number_of_shards": 1}}'; echo

# Iterate over each file in the collection path, parsing each
# one as it sees it, then bulk indexing the file.
for filename in $(find ${COLLECTION_PATH_WRITABLE} -type f); do
    echo ${filename}
    cat ${filename} | ./ielab_cparser ${INDEX} ${COLLECTION_FORMAT} trecweb > requests
    curl -s -H "Content-Type: application/x-ndjson" -X POST localhost:9200/${INDEX}/_bulk?wait_for_active_shards=1\&refresh=wait_for --data-binary "@requests"; echo
done

# Tidy up the file containing the bulk request at the end.
rm requests

curl -s -o /dev/null -X POST localhost:9200/${INDEX}/_refresh?pretty
curl -s -X GET localhost:9200/${INDEX}/_count?pretty | grep count | sed 's/["| |,]//g'