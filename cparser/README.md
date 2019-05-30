# cparser

This package is built to parse common IR collection files and bulk index them in Elasticsearch. Once compiled, cparser reads a collection file from stdin and takes the following arguments:

```bash
cparser <index> <collection_format>
```

cparser is a Go package. It can be installed using:

```bash
go get -u github.com/osirrc2019/ielab-docker/cparser
```

It currently assumes that Elasticsearch is running on port `9200`.