#!/usr/bin/env bash

# Setup variables.
COLLECTION_PATH=$1
INDEX=$2
COLLECTION_FORMAT=$3


BULK_SIZE=1000

# Portions of this code copied from https://github.com/osirrc/indri-docker.

# The mounted collection folder is read-only, we need a writable folder.
COLLECTION_PATH_WRITABLE=${COLLECTION_PATH}"-WRITABLE"
echo "copying files of directory ${COLLECTION_PATH} into ${COLLECTION_PATH_WRITABLE}"
cp -r ${COLLECTION_PATH} ${COLLECTION_PATH_WRITABLE}
echo "done!"


if [[ ${INDEX} == "robust04" ]]
then
    BULK_SIZE=10
    # Remove the unwanted parts of disk45 (as per ROBUST04 guidelines)
    rm -r ${COLLECTION_PATH_WRITABLE}/disk4/cr
    rm -r ${COLLECTION_PATH_WRITABLE}/disk4/dtds
    rm -r ${COLLECTION_PATH_WRITABLE}/disk5/dtds
    rm -r ${COLLECTION_PATH_WRITABLE}/disk4/fr94/aux/
    rm ${COLLECTION_PATH_WRITABLE}/disk4/ft/readfrcg.z
    rm ${COLLECTION_PATH_WRITABLE}/disk4/ft/readmeft.z
    rm ${COLLECTION_PATH_WRITABLE}/disk4/fr94/readchg.z
    rm ${COLLECTION_PATH_WRITABLE}/disk4/fr94/readmefr.z
    rm ${COLLECTION_PATH_WRITABLE}/disk5/latimes/readmela.txt
    rm ${COLLECTION_PATH_WRITABLE}/disk5/latimes/readchg.txt

    # Robust04 has a folder with `NAME.0z`, `NAME.1z` and `NAME.2z` files, simply using gunzip
    # is not an option as files are being overwritten (same name, different suffix);
    # hacked solution: add ".z" to every single file in the collection path.
    find ${COLLECTION_PATH_WRITABLE} -maxdepth 100 -name "*.0z" -type f -exec mv '{}' '{}'.z \;
    find ${COLLECTION_PATH_WRITABLE} -maxdepth 100 -name "*.1z" -type f -exec mv '{}' '{}'.z \;
    find ${COLLECTION_PATH_WRITABLE} -maxdepth 100 -name "*.2z" -type f -exec mv '{}' '{}'.z \;
    # Decompress.
    echo "robust04 ... decompressing"
    gunzip --suffix=".z" -r ${COLLECTION_PATH_WRITABLE}
    echo "done!"
fi

if [[ ${INDEX} == "core17" ]]
then
    rm -r ${COLLECTION_PATH_WRITABLE}/docs
    rm -r ${COLLECTION_PATH_WRITABLE}/dtd
    rm -r ${COLLECTION_PATH_WRITABLE}/tools
    rm ${COLLECTION_PATH_WRITABLE}/index.html

#    find ${COLLECTION_PATH_WRITABLE} -name "*.tgz" -type f -exec mv '{}' '{}'.z \;
    echo "core17 ... decompressing"
    gunzip --suffix=".tgz" -r ${COLLECTION_PATH_WRITABLE}
    mkdir -p ${COLLECTION_PATH_WRITABLE}/decompressed
    find ${COLLECTION_PATH_WRITABLE}/data -maxdepth 100 -type f -exec tar -xf '{}' -C ${COLLECTION_PATH_WRITABLE}/decompressed \;
    rm -rf ${COLLECTION_PATH_WRITABLE}/data
    echo "done!"
fi

if [[ ${INDEX} == "core18" ]]
then
    rm ${COLLECTION_PATH_WRITABLE}/MD5SUMS
    rm ${COLLECTION_PATH_WRITABLE}/README.md
    rm -r ${COLLECTION_PATH_WRITABLE}/scripts

    cd ${COLLECTION_PATH_WRITABLE}/data/
    split -l 1 TREC_Washington_Post_collection.v2.jl
    rm ${COLLECTION_PATH_WRITABLE}/data/TREC_Washington_Post_collection.v2.jl
    cd /
fi

# Wait for Elasticsearch.
./eswait.sh


# Create the index.
curl -s -H "Content-Type: application/json" -X PUT localhost:9200/${INDEX}?wait_for_active_shards=1 -d '{"settings": {"number_of_shards": 4}}'; echo
curl -s -H 'Content-Type: application/json' -X PUT localhost:9200/_settings -d '{ "index": { "refresh_interval": "60s"}}'; echo


function do_request {
    # We have a parsed file, now try to index it.
    STATUS=$(curl -s -w "%{http_code}" -o resp -H "Content-Type: application/x-ndjson" -X POST localhost:9200/${INDEX}/_bulk --data-binary "@requests")
    if [[ ${STATUS} != 200 ]]
    then
        # Can't index the file, so what's the error?
        printf "[X]\n"
        echo "###### RESPONSE: ######"
        cat resp; echo
    else
        # Okay, great, we indexed the file.
        printf "[√]\n"
    fi

    # Remove the requests file.
    [[ -e requests ]] && rm requests
}
# Iterate over each file in the collection path, parsing each
# one as it sees it, then bulk indexing the file.
I=0
for filename in $(find ${COLLECTION_PATH_WRITABLE} -type f); do
    echo "parsing ${filename} (${I}/${BULK_SIZE} for bulk index)"
    # Try to parse the file.
    cat ${filename} | ./ielab_cparser ${INDEX} ${COLLECTION_FORMAT} trecweb >> requests
    if [[ ! -e requests ]]
    then
        # We were unable to parse the file...
        printf "[X] - couldn't parse!\n"
    elif (( I >= BULK_SIZE ))
    then
        do_request
        I=0
    fi
    I=$((${I}+1))
done

if [[ $(wc -l requests) > 0 ]]
then
    echo "issuing remaining documents for bulk indexing"
    do_request
fi

# Remove the resp file.
[[ -e resp ]] && rm resp

curl -s -o /dev/null -X POST localhost:9200/${INDEX}/_refresh?pretty
curl -s -X GET localhost:9200/_cluster/health?pretty
curl -s -X GET localhost:9200/${INDEX}/_count?pretty | grep count | sed 's/["| |,]//g'