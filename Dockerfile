FROM golang:1.22-alpine3.20 AS builder

ARG XRAYVER='v1.8.23'

RUN apk add --no-cache bash git build-base

WORKDIR /go/src/XTLS/Xray-core
RUN git clone https://github.com/XTLS/Xray-core.git . && \
    git checkout ${XRAYVER} && \
    go build -o xray -trimpath -ldflags "-s -w -buildid=" ./main

RUN cd /tmp; wget -c -t3 -T30 https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
RUN cd /tmp; wget -c -t3 -T30 https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
    

FROM nginx:stable-alpine3.20

ARG ACMEVER='2.9.0'

COPY --from=builder /go/src/XTLS/Xray-core/xray /usr/local/bin/
COPY --from=builder /tmp/geosite.dat /usr/local/bin/
COPY --from=builder /tmp/geoip.dat /usr/local/bin/

RUN apk add --no-cache bash openssl curl socat jq moreutils libcap-setcap
RUN cd /root; curl -sSL "https://github.com/acmesh-official/acme.sh/archive/refs/tags/${ACMEVER}.tar.gz"|tar zxvf -
RUN cd /root; ln -s acme.sh-${ACMEVER} acme.sh; mkdir .acme.sh
RUN setcap CAP_NET_BIND_SERVICE=+eip /usr/sbin/nginx

COPY site-ssl.conf.tpl /etc/nginx/conf.d/
COPY nginx-proxy.tpl /etc/nginx/conf.d/
COPY nginx-grpc.tpl /etc/nginx/conf.d/
COPY nginx-ws.tpl /etc/nginx/conf.d/

ADD server-lx.sh            /server-lx.sh
ADD server-ls.sh            /server-ls.sh
ADD server-ms.sh            /server-ms.sh
ADD server-ts.sh            /server-ts.sh

ADD server-lsw.sh           /server-lsw.sh
ADD server-lsg.sh           /server-lsg.sh
ADD server-lss.sh           /server-lss.sh

ADD server-msw.sh           /server-msw.sh
ADD server-tsw.sh           /server-tsw.sh

ADD server-lpw.sh           /server-lpw.sh
ADD server-lpg.sh           /server-lpg.sh
ADD server-lps.sh           /server-lps.sh

ADD server-mpw.sh           /server-mpw.sh
ADD server-tpw.sh           /server-tpw.sh

ADD server-nginx.sh         /server-nginx.sh

ADD run.sh                  /run.sh

RUN chmod 755 /*.sh

ENTRYPOINT ["/run.sh"]
