FROM golang:1.23-alpine3.20 AS builder

ARG XRAYVER='v1.8.24'

RUN apk add --no-cache bash git build-base curl

WORKDIR /go/src/XTLS/Xray-core
RUN git clone https://github.com/XTLS/Xray-core.git . && \
    git checkout ${XRAYVER} && \
    go build -o xray -trimpath -ldflags "-s -w -buildid=" ./main

RUN cd /tmp; curl -sSLO https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
RUN cd /tmp; curl -sSLO https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
    

FROM nginx:stable-alpine3.20

ARG ACMEVER='2.9.0'

COPY --from=builder /go/src/XTLS/Xray-core/xray /usr/local/bin/
COPY --from=builder /tmp/geosite.dat /usr/local/bin/
COPY --from=builder /tmp/geoip.dat /usr/local/bin/

RUN apk add --no-cache bash openssl curl socat jq moreutils libcap-setcap
RUN cd /root; curl -sSL "https://github.com/acmesh-official/acme.sh/archive/refs/tags/${ACMEVER}.tar.gz"|tar zxvf -
RUN cd /root; ln -s acme.sh-${ACMEVER} acme.sh; mkdir .acme.sh
RUN setcap CAP_NET_BIND_SERVICE=+eip /usr/sbin/nginx

COPY site-ssl.conf.tpl  /etc/nginx/conf.d/
COPY nginx-stream.tpl   /etc/nginx/conf.d/
COPY nginx-proxy.tpl    /etc/nginx/conf.d/
COPY nginx-grpc.tpl     /etc/nginx/conf.d/
COPY nginx-ws.tpl       /etc/nginx/conf.d/

ADD server-lgp.sh   /server-lgp.sh
ADD server-lgr.sh   /server-lgr.sh
ADD server-lgt.sh   /server-lgt.sh

ADD server-lsp.sh   /server-lsp.sh
ADD server-lst.sh   /server-lst.sh

ADD server-ltr.sh   /server-ltr.sh
ADD server-ltt.sh   /server-ltt.sh

ADD server-lwp.sh   /server-lwp.sh
ADD server-lwt.sh   /server-lwt.sh

ADD server-mtt.sh   /server-mtt.sh
ADD server-mwp.sh   /server-mwp.sh
ADD server-mwt.sh   /server-mwt.sh

ADD server-twp.sh   /server-twp.sh
ADD server-ttt.sh   /server-ttt.sh
ADD server-twt.sh   /server-twt.sh

ADD server-nginx.sh /server-nginx.sh
ADD fallback.sh     /fallback.sh
ADD addusertj.sh    /addusertj.sh
ADD adduser.sh      /adduser.sh

ADD run.sh          /run.sh

RUN chmod 755 /*.sh

ENTRYPOINT ["/run.sh"]
