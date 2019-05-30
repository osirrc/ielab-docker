# tsearcher

This package is built to parse common IR topic files and issue them to Elasticsearch in an appropriate format. Once compiled, tsearcher reads a topic file from stdin, writes the results (in TREC result file format) to stdout, and takes the following arguments:

```bash
tsearcher <index> <topic_format> <top_k>
```


tsearcher is a Go package. It can be installed using:

```bash
go get -u github.com/osirrc2019/ielab-docker/tsearcher
```

It currently assumes that Elasticsearch is running on port `9200`.