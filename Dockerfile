FROM golang:1.21-alpine as builder

ARG XRAYVER='v1.8.4'

RUN apk add --no-cache bash git build-base

WORKDIR /go/src/XTLS/Xray-core
RUN git clone https://github.com/XTLS/Xray-core.git . && \
    git checkout ${XRAYVER} && \
    go build -o xray -trimpath -ldflags "-s -w -buildid=" ./main


FROM alpine:3.18

ARG ACMEVER='2.9.0'

COPY --from=builder /go/src/XTLS/Xray-core/xray /usr/local/bin/

RUN apk add --no-cache bash nginx openssl curl socat jq moreutils
RUN cd /root; curl -sSL "https://github.com/acmesh-official/acme.sh/archive/refs/tags/${ACMEVER}.tar.gz"|tar zxvf -
RUN cd /root; ln -s acme.sh-${ACMEVER} acme.sh; mkdir .acme.sh

COPY site-ssl.conf.tpl /etc/nginx/http.d/
COPY grpc.tpl /etc/nginx/http.d/
COPY ws.tpl /etc/nginx/http.d/
ADD run.sh                  /run.sh
ADD server-ltx.sh           /server-ltx.sh
ADD server-ltt.sh           /server-ltt.sh
ADD server-lttw.sh          /server-lttw.sh
ADD server-ltpw.sh          /server-ltpw.sh
ADD server-mtt.sh           /server-mtt.sh
ADD server-mttw.sh          /server-mttw.sh
ADD server-mtpw.sh          /server-mtpw.sh
ADD server-ttt.sh           /server-ttt.sh
ADD server-tttw.sh          /server-tttw.sh
ADD server-ttpw.sh          /server-ttpw.sh
ADD server-lttg.sh          /server-lttg.sh
ADD server-ltpg.sh          /server-ltpg.sh
ADD server-nginx.sh         /server-nginx.sh

RUN chmod 755 /*.sh

ENTRYPOINT ["/run.sh"]
