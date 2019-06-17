# ielab-docker

[Harry Scells](https://ielab.io/people/harry-scells) and [Guido Zuccon](https://ielab.io/people/guido-zuccon)

This is the docker image for Elasticsearch conforming to the OSIRRC jig for the Open-Source IR Replicability Challenge (OSIRRC) at SIGIR 2019.

Currently supported:

 - test collections: `core17`, `core18`, `cw12b`, `robust04` 
 - hooks: `init`, `index`, `search`
 
 
# Implementation details

## Initialisation

Since Elasticsearch is built to be run as a service and not as a standalone application, there are some considerations that need to be made. Firstly, all scripts that involve Elasticsearch must execute the script `eswait.sh` which will start Elasticsearch as a daemon and wait for it to complete starting up.

# Indexing

Elasticsearch uses a "schema-less" model for indexing documents. This means that in order to index a document, one must first convert it into a format that Elasticsearch can consume (json). The [cparser](cparser) package implements document parsing routines to transform test collection files into bulk index Elasticsearch actions. It can be installed as a stand-alone command-line application irrespective of this repository using the Go toolchain: `go get -u github.com/osirrc/ielab-docker/cparser`.

# Searching

Elasticsearch only supports a specific query language, so standard topic file formats cannot directly be used. The [tsearcher](tsearcher) package implements topic file parsing routines to transform a topic file into a query suitable for Elasticsearch to execute, perform the search, and write a run file. It can be installed as a stand-alone command-line application irrespective of this repository using the Go toolchain: `go get -u github.com/osirrc/ielab-docker/tsearcher`.