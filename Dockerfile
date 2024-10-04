FROM golang:1.23-alpine3.20 AS builder

ARG XRAYVER='v1.8.24'

RUN apk add --no-cache bash git build-base curl

WORKDIR /go/src/XTLS/Xray-core
RUN git clone https://github.com/XTLS/Xray-core.git . && \
    git checkout ${XRAYVER} && \
    go build -o xray -trimpath -ldflags "-s -w -buildid=" ./main

RUN curl -sSLO https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
RUN curl -sSLO https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
    

FROM nginx:stable-alpine3.20

ARG ACMEVER='2.9.0'

COPY --from=builder /go/src/XTLS/Xray-core/xray         /usr/local/bin/
COPY --from=builder /go/src/XTLS/Xray-core/geoip.dat    /usr/local/bin/
COPY --from=builder /go/src/XTLS/Xray-core/geosite.dat  /usr/local/bin/

WORKDIR /root
RUN apk add --no-cache bash openssl curl socat jq moreutils libcap-setcap
RUN curl -sSL "https://github.com/acmesh-official/acme.sh/archive/refs/tags/${ACMEVER}.tar.gz"|tar zxvf -
RUN ln -s acme.sh-${ACMEVER} acme.sh; mkdir .acme.sh
RUN setcap CAP_NET_BIND_SERVICE=+eip /usr/sbin/nginx

COPY nginx-site.tpl     /etc/nginx/conf.d/
COPY nginx-stream.tpl   /etc/nginx/conf.d/
COPY nginx-proxy.tpl    /etc/nginx/conf.d/
COPY nginx-grpc.tpl     /etc/nginx/conf.d/
COPY nginx-ws.tpl       /etc/nginx/conf.d/
COPY proxy-log-fmt.tpl  /etc/nginx/conf.d/000-proxy-log-fmt.conf

COPY server-lgp.sh      /server-lgp.sh
COPY server-lgr.sh      /server-lgr.sh
COPY server-lgt.sh      /server-lgt.sh

COPY server-lsp.sh      /server-lsp.sh
COPY server-lst.sh      /server-lst.sh

COPY server-ltr.sh      /server-ltr.sh
COPY server-ltt.sh      /server-ltt.sh

COPY server-lwp.sh      /server-lwp.sh
COPY server-lwt.sh      /server-lwt.sh

COPY server-mtt.sh      /server-mtt.sh
COPY server-mwp.sh      /server-mwp.sh
COPY server-mwt.sh      /server-mwt.sh

COPY server-twp.sh      /server-twp.sh
COPY server-ttt.sh      /server-ttt.sh
COPY server-twt.sh      /server-twt.sh

COPY server-nginx.sh    /server-nginx.sh

COPY run.sh             /run.sh

RUN chmod 755 /*.sh

ENTRYPOINT ["/run.sh"]
