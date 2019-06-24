FROM ubuntu:18.04 AS build
# STEP 1: Create a `build` stage where the go command-line applications are compiled and Elasticsearch is downloaded.

# Update and upgrade repo.
RUN apt-get update -y -q && \
    apt-get upgrade -y -q

# Install tools we need.
RUN DEBIAN_FRONTEND=noninteractive apt-get install --fix-missing --no-install-recommends -y -q curl build-essential ca-certificates git

# Download Go 1.2.2 and install it to /usr/local/go.
RUN curl -s https://storage.googleapis.com/golang/go1.12.linux-amd64.tar.gz | tar -v -C /usr/local -xz

# Lets people find our Go binaries.
ENV PATH $PATH:/usr/local/go/bin

# Copy over and compile the applications.
COPY cparser/ cparser/
COPY tsearcher tsearcher/

RUN cd cparser && go build -v -mod=vendor -o ../ielab_cparser main.go && cd ../
RUN cd tsearcher && go build -v -mod=vendor -o ../ielab_tsearcher main.go && cd ../

# Download and extract the elasticsearch archive.
RUN curl -s https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.0.0-linux-x86_64.tar.gz | tar -v -C . -xz
RUN mv elasticsearch-7.0.0 elasticsearch

FROM ubuntu:18.04 AS runtime
# STEP 2: Create a `runtime` stage which only installs what is nedeed for the image to run.

# Update and upgrade repo.
RUN apt-get update -y -q && apt-get upgrade -y -q

# Install the tools we need.
RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y -q sudo python3 curl ca-certificates

# Create an es user to be able to start Elasticsearch on docker.
RUN useradd -ms /bin/bash es

# Copy over the compiled applications from the `build` stage.
COPY --from=build /ielab_cparser .
COPY --from=build /ielab_tsearcher .
COPY --from=build /elasticsearch/ /elasticsearch/

# Copy all the scripts from into the runtime stage.
COPY init init
COPY index index
COPY index.sh index.sh
COPY search search
COPY search.sh search.sh
COPY eswait.sh eswait.sh
