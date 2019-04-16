FROM openjdk:8-alpine

COPY init init
COPY index index
COPY search.sh search
COPY doc.go doc.go
COPY cparser parsedocs/parsedocs.go

#install bash, cURL and Python
RUN apk add --update bash && rm -rf /var/cache/apk/*
RUN apk add curl0
RUN apk add python3
RUN apk add go

# Set working directory
WORKDIR /work