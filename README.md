# ielab-docker

[Harry Scells](https://ielab.io/people/harry-scells) and [Guido Zuccon](https://ielab.io/people/guido-zuccon)

This is the docker image for Elasticsearch conforming to the OSIRRC jig for the Open-Source IR Replicability Challenge (OSIRRC) at SIGIR 2019.

Currently supported:

 - test collections: `core17`, `core18`, `cw12b`, `robust04` 
 - hooks: `init`, `index`, `search`
 
## Quick Start

The following `jig` command can be used to index TREC disks 4/5 for `robust04`:

```bash
python run.py prepare \
  --repo osirrc/ielab-docker \
  --collections robust04=/path/to/disk45=trectext
```

The following jig command can be used to perform a retrieval run on the collection with the robust04 test collection.

```bash
python run.py search \
  --repo osirrc/ielab-docker \
  --output out/ielab \
  --qrels qrels/qrels.robust04.txt \
  --topic topics/topics.robust04.txt \
  --collection robust04
```
 
## Retrieval Methods

The container currently supports the default Elasticsearch implementattrecion of BM25. 
 
## Implementation

### Dockerfile

The `Dockerfile` uses a multi-stage build system. First, all development dependencies are installed, code is compiled, and Elasticsearch is downloaded. Next, a runtime image is built and the artifacts from the previous stage are copied (minimising the size of the image and speeding up development time).

### init

Since most of the image is configured in the `Dockerfile`, the init script does not do much (only some permission changes are made).

### index

The `index` Python script reads a JSON object containing the instructions for how and what to index as specified in the jig. This script invokes `index.sh`.

Since Elasticsearch is built to be run as a service and not as a standalone application, there are some considerations that need to be made. Firstly, all scripts that involve Elasticsearch must execute the script `eswait.sh` which will start Elasticsearch as a daemon and wait for it to complete starting up. This script is run for both the `index` and `search` phases.

Elasticsearch uses a "schema-less" model for indexing documents. This means that in order to index a document, one must first convert it into a format that Elasticsearch can consume (json). The [cparser](cparser) package implements document parsing routines to transform test collection files into bulk index Elasticsearch actions. It can be installed as a stand-alone command-line application irrespective of this repository using the Go toolchain: `go get -u github.com/osirrc/ielab-docker/cparser`.

### search

The `search` Python script reads a JSON object containing the instructions for how and what to search as specified in the jig. This script invokes `search.sh`.

Elasticsearch only supports a specific query language, so standard topic file formats cannot directly be used. The [tsearcher](tsearcher) package implements topic file parsing routines to transform a topic file into a query suitable for Elasticsearch to execute, perform the search, and write a run file. It can be installed as a stand-alone command-line application irrespective of this repository using the Go toolchain: `go get -u github.com/osirrc/ielab-docker/tsearcher`.