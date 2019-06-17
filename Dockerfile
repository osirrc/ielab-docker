FROM ubuntu:18.04 AS build

# Update and upgrade repo
RUN apt-get update -y -q && apt-get upgrade -y -q

# Install tools we might need
RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y -q curl build-essential ca-certificates git

# Download Go 1.2.2 and install it to /usr/local/go
RUN curl -s https://storage.googleapis.com/golang/go1.12.linux-amd64.tar.gz | tar -v -C /usr/local -xz

# Let's people find our Go binaries
ENV PATH $PATH:/usr/local/go/bin

COPY cparser/ cparser/
COPY tsearcher tsearcher/

RUN cd cparser && go build -v -mod=vendor -o ../ielab_cparser main.go && cd ../
RUN cd tsearcher && go build -v -mod=vendor -o ../ielab_tsearcher main.go && cd ../

# Download and extract the elasticsearch archive.
RUN curl -s https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.0.0-linux-x86_64.tar.gz | tar -v -C . -xz
RUN mv elasticsearch-7.0.0 elasticsearch

FROM ubuntu:18.04 AS runtime

# Update and upgrade repo
RUN apt-get update -y -q && apt-get upgrade -y -q

RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y -q sudo python3 curl ca-certificates

RUN useradd -ms /bin/bash es

COPY --from=build /ielab_cparser .
COPY --from=build /ielab_tsearcher .
COPY --from=build /elasticsearch/ /elasticsearch/

COPY init init
COPY index index
COPY index.sh index.sh
COPY search search
COPY search.sh search.sh
COPY eswait.sh eswait.sh
