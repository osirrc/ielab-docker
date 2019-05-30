FROM ubuntu:18.04

COPY init init
COPY index index
COPY index.sh index.sh
COPY search search
COPY search.sh search.sh
COPY cparser/ cparser/
COPY tsearcher tsearcher/
COPY eswait.sh eswait.sh

#install bash, cURL and Python
#RUN apt-get install --assume-yes curl
#RUN yum -y install centos-release-scl
#RUN yum -y install gcc

#RUN apk add --update bash && rm -rf /var/cache/apk/*
#RUN apk add curl
#RUN apk add python3



# Update and upgrade repo
RUN apt-get update -y -q && apt-get upgrade -y -q

# Install tools we might need
RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y -q sudo python3 curl build-essential ca-certificates git

# Download Go 1.2.2 and install it to /usr/local/go
RUN curl -s https://storage.googleapis.com/golang/go1.12.linux-amd64.tar.gz| tar -v -C /usr/local -xz

# Let's people find our Go binaries
ENV PATH $PATH:/usr/local/go/bin

RUN useradd -ms /bin/bash es
#USER es
#WORKDIR /home/es