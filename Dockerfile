FROM debian:stretch as builderc

# Fluent Bit version
ENV FLB_MAJOR 1
ENV FLB_MINOR 4
ENV FLB_PATCH 5
ENV FLB_VERSION 1.4.5

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    ca-certificates \
    cmake \
    make \
    tar \
    libssl-dev \
    libsasl2-dev \
    pkg-config \
    libsystemd-dev \
    zlib1g-dev \
    libpq-dev \
    postgresql-server-dev-all \
    flex \
    bison

RUN mkdir -p /fluent-bit/bin /fluent-bit/etc /fluent-bit/log /tmp/src/
COPY . /tmp/src/
RUN rm -rf /tmp/src/build/*

WORKDIR /tmp/src/build/
RUN cmake -DFLB_DEBUG=Off \
          -DFLB_TRACE=Off \
          -DFLB_JEMALLOC=On \
          -DFLB_TLS=On \
          -DFLB_SHARED_LIB=Off \
          -DFLB_EXAMPLES=Off \
          -DFLB_HTTP_SERVER=On \
          -DFLB_IN_SYSTEMD=On \
          -DFLB_OUT_KAFKA=On \
          -DFLB_OUT_PGSQL=On ../

RUN make -j $(getconf _NPROCESSORS_ONLN)
RUN install bin/fluent-bit /fluent-bit/bin/

# Configuration files
COPY conf/fluent-bit.conf \
     conf/fluent-bit-custom.conf \
     conf/parsers.conf \
     conf/parsers_ambassador.conf \
     conf/parsers_java.conf \
     conf/parsers_extra.conf \
     conf/parsers_openstack.conf \
     conf/parsers_cinder.conf \
     conf/plugins.conf \
     /fluent-bit/etc/

FROM golang:1.10.1-alpine3.7 as buildergo
WORKDIR /go/src
COPY fluentbitdaemon.go .
COPY fluentbitdisable.go .

RUN apk update && apk add git
RUN go get github.com/golang/glog
RUN CGO_ENABLED=0 go build -o fluentbitdaemon ./fluentbitdaemon.go
RUN CGO_ENABLED=0 go build -o fluentbitdisable ./fluentbitdisable.go

FROM gcr.io/distroless/cc-debian10
LABEL maintainer="Eduardo Silva <eduardo@treasure-data.com>"
LABEL Description="Fluent Bit docker image" Vendor="Fluent Organization" Version="1.1"

COPY --from=builderc /usr/lib/x86_64-linux-gnu/*sasl* /usr/lib/x86_64-linux-gnu/
COPY --from=builderc /usr/lib/x86_64-linux-gnu/libz* /usr/lib/x86_64-linux-gnu/
COPY --from=builderc /lib/x86_64-linux-gnu/libz* /lib/x86_64-linux-gnu/
COPY --from=builderc /usr/lib/x86_64-linux-gnu/libssl.so* /usr/lib/x86_64-linux-gnu/
COPY --from=builderc /usr/lib/x86_64-linux-gnu/libcrypto.so* /usr/lib/x86_64-linux-gnu/

# These below are all needed for systemd
COPY --from=builderc /lib/x86_64-linux-gnu/libsystemd* /lib/x86_64-linux-gnu/
COPY --from=builderc /lib/x86_64-linux-gnu/libselinux.so* /lib/x86_64-linux-gnu/
COPY --from=builderc /lib/x86_64-linux-gnu/liblzma.so* /lib/x86_64-linux-gnu/
COPY --from=builderc /usr/lib/x86_64-linux-gnu/liblz4.so* /usr/lib/x86_64-linux-gnu/
COPY --from=builderc /lib/x86_64-linux-gnu/libgcrypt.so* /lib/x86_64-linux-gnu/
COPY --from=builderc /lib/x86_64-linux-gnu/libpcre.so* /lib/x86_64-linux-gnu/
COPY --from=builderc /lib/x86_64-linux-gnu/libgpg-error.so* /lib/x86_64-linux-gnu/

COPY --from=builderc /fluent-bit /fluent-bit

COPY --from=builderc /usr/lib/x86_64-linux-gnu/libpq.so* /usr/lib/x86_64-linux-gnu/
COPY --from=builderc /usr/lib/x86_64-linux-gnu/libgssapi* /usr/lib/x86_64-linux-gnu/
COPY --from=builderc /usr/lib/x86_64-linux-gnu/libldap* /usr/lib/x86_64-linux-gnu/
COPY --from=builderc /usr/lib/x86_64-linux-gnu/libkrb* /usr/lib/x86_64-linux-gnu/
COPY --from=builderc /usr/lib/x86_64-linux-gnu/libk5crypto* /usr/lib/x86_64-linux-gnu/
COPY --from=builderc /usr/lib/x86_64-linux-gnu/liblber* /usr/lib/x86_64-linux-gnu/
COPY --from=builderc /usr/lib/x86_64-linux-gnu/libgnutls* /usr/lib/x86_64-linux-gnu/
COPY --from=builderc /usr/lib/x86_64-linux-gnu/libp11-kit* /usr/lib/x86_64-linux-gnu/
COPY --from=builderc /usr/lib/x86_64-linux-gnu/libidn* /usr/lib/x86_64-linux-gnu/
COPY --from=builderc /lib/x86_64-linux-gnu/libidn* /usr/lib/x86_64-linux-gnu/
COPY --from=builderc /usr/lib/x86_64-linux-gnu/libunistring* /usr/lib/x86_64-linux-gnu/
COPY --from=builderc /usr/lib/x86_64-linux-gnu/libtasn1* /usr/lib/x86_64-linux-gnu/
COPY --from=builderc /usr/lib/x86_64-linux-gnu/libnettle* /usr/lib/x86_64-linux-gnu/
COPY --from=builderc /usr/lib/x86_64-linux-gnu/libhogweed* /usr/lib/x86_64-linux-gnu/
COPY --from=builderc /usr/lib/x86_64-linux-gnu/libgmp* /usr/lib/x86_64-linux-gnu/
COPY --from=builderc /usr/lib/x86_64-linux-gnu/libffi* /usr/lib/x86_64-linux-gnu/
COPY --from=builderc /lib/x86_64-linux-gnu/libcom_err* /lib/x86_64-linux-gnu/
COPY --from=builderc /lib/x86_64-linux-gnu/libkeyutils* /lib/x86_64-linux-gnu/

COPY --from=builderc /fluent-bit /fluent-bit

COPY --from=buildergo /go/src/fluentbitdaemon /fluent-bit/bin/fluentbitdaemon
COPY --from=buildergo /go/src/fluentbitdisable /fluent-bit/bin/fluentbitdisable

#
EXPOSE 2020

# Entry point
CMD ["/fluent-bit/bin/fluentbitdaemon"]
