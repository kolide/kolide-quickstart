FROM alpine:3.4
MAINTAINER Kolide Developers <engineering@kolide.co>

RUN apk update && apk add openssl && rm -rf /var/cache/apk/*

ENTRYPOINT ["openssl"]
