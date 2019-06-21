#!/usr/bin/env bash

# Setup variables.
COLLECTION_PATH=$1
INDEX=$2
COLLECTION_FORMAT=$3


# Portions of this code copied from https://github.com/osirrc/indri-docker.

# The mounted collection folder is read-only, we need a writable folder.
COLLECTION_PATH_WRITABLE=${COLLECTION_PATH}"-WRITABLE"
echo "copying files of directory ${COLLECTION_PATH} into ${COLLECTION_PATH_WRITABLE}"
cp -r ${COLLECTION_PATH} ${COLLECTION_PATH_WRITABLE}
echo "done!"

if [[ ${INDEX} == "robust04" ]]
then
    # Remove the unwanted parts of disk45 (as per ROBUST04 guidelines)
    rm -r ${COLLECTION_PATH_WRITABLE}/disk4/cr
    rm -r ${COLLECTION_PATH_WRITABLE}/disk4/dtds
    rm -r ${COLLECTION_PATH_WRITABLE}/disk5/dtds
    rm -r ${COLLECTION_PATH_WRITABLE}/disk4/aux
    rm ${COLLECTION_PATH_WRITABLE}/disk4/ft/readfrcg
    rm ${COLLECTION_PATH_WRITABLE}/disk4/ft/readmeft
    rm ${COLLECTION_PATH_WRITABLE}/disk4/fr94/readchg
    rm ${COLLECTION_PATH_WRITABLE}/disk4/fr94/readmefr

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

if [[ ${INDEX} == "core17" ]]
then
    rm -r ${COLLECTION_PATH_WRITABLE}/NYTcorpus/docs
    rm -r ${COLLECTION_PATH_WRITABLE}/NYTcorpus/dtd
    rm -r ${COLLECTION_PATH_WRITABLE}/NYTcorpus/tools
    rm ${COLLECTION_PATH_WRITABLE}/NYTcorpus/index.html

    find ${COLLECTION_PATH_WRITABLE} -name "*.tgz" -type f -exec mv '{}' '{}'.z \;
    echo "core17 ... Uncompressing"
    gunzip -v --suffix=".z" -r ${COLLECTION_PATH_WRITABLE}
fi

if [[ ${INDEX} == "core18" ]]
then
    rm ${COLLECTION_PATH_WRITABLE}/MD5SUMS
    rm ${COLLECTION_PATH_WRITABLE}/README.md
    rm -r ${COLLECTION_PATH_WRITABLE}/scripts

    cd ${COLLECTION_PATH_WRITABLE}/data/
    split -l 1 TREC_Washington_Post_collection.v2.jl
    rm ${COLLECTION_PATH_WRITABLE}/data/TREC_Washington_Post_collection.v2.jl
    ls ${COLLECTION_PATH_WRITABLE}/data
    cd /
fi

# Wait for Elasticsearch.
./eswait.sh

curl -s -H 'Content-Type: application/json' -X PUT localhost:9200/_settings -d '{ "index": { "refresh_interval": "60s"}}'

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