#!/bin/bash

DIR=`dirname $0`
DIR="$(cd $DIR; pwd)"
XCONF=/tmp/server-xray.json

usage() {
    echo "server-xray --<ltx|ltt|lttw|mtt|mttw|ttt> <options> [-r|--request-domain <domain-name>] [-c|--cert-path <cert-path-root>] [-k|--hook <hook-url>]"
    echo "    -k|--hook <hook-url>               [Optional] DDNS update or notifing URL to be hit. Multiple allowed"
    echo "    -r|--request-domain <domain-name>  [Optional] Domain name to request for letsencrypt cert. Multiple allowed"
    echo "    -c|--cert-path <cert-path-root>    [Optional] Reading TLS certs from folder <cert-path-root>/<domain-name>/. Multiple allowed"
    echo "    --ltx  <VLESS-TCP-XTLS option>     p=443,d=domain0.com,u=uuid[:level[:email]][,f=[fallback-host]:fb-port:[fb-path]]"
    echo "    --ltt  <VLESS-TCP-TLS option>      p=1443,d=domain1.com,u=uuid[:level[:email]][,f=[fallback-host]:fb-port:[fb-path]]"
    echo "    --lttw <VLESS-TCP-TLS-WS option>   p=2443,d=domain2.com,u=uuid[:level[:email]][,f=[fallback-host]:fb-port:[fb-path]],w=/webpath"
    echo "    --lttg <VLESS-TCP-TLS-GRPC option> p=7443,d=domain0.com,u=uuid[:level[:email]],s=svcname,g=grpcport"
    echo "    --mtt  <VMESS-TCP-TLS option>      p=3443,d=domain3.com,u=uuid[:level[:email]][,f=[fallback-host]:fb-port:[fb-path]]"
    echo "    --mttw <VMESS-TCP-TLS-WS option>   p=4443,d=domain4.com,u=uuid[:level[:email]][,f=[fallback-host]:fb-port:[fb-path]],w=/webpath"
    echo "    --ttt  <TROJAN-TCP-TLS option>     p=5443,d=domain5.com,u=passwd[:email][,f=[fallback-host]:fb-port:[fb-path]]"
    echo "    --tttw <TROJAN-TCP-TLS-WS option>  p=6443,d=domain5.com,u=passwd[:email][,f=[fallback-host]:fb-port:[fb-path]],w=/webpath"
#   echo "    --ssa  <Shadowsocks-AEAD option>   port=8443,user=password1:method1[,user=password2:method2]"
#   echo "    --sst  <Shadowsocks-TCP option>    port=9443,user=passwd,method=xxxx"
    echo "    --stdin                            Read XRay config from stdin instead of auto generation"
}

TEMP=`getopt -o k:r:c:d --long hook:,request-domain:,cert-path:,ltx:,ltt:,lttw:,mtt:,mttw:,ttt:,tttw:,lttg:,ssa:,sst:stdin,debug -n "$0" -- $@`
if [ $? != 0 ] ; then usage; exit 1 ; fi

eval set -- "$TEMP"
while true ; do
    case "$1" in
        -k|--hook)
            HOOKURL+=("$2")
            shift 2
            ;;
        -r|--request-domain)
            CERTDOMAIN+=("$2")
            shift 2
            ;;        
        -c|--cert-path)
            CERTPATH+="$2"
            shift 2
            ;;
        -d|--debug)
            DEBUG=1
            shift 1
            ;;
        --ltx|--ltt|--lttw|--lttg|--mtt|--mttw|--ttt|--tttw)
            if [ "$1" = "--lttg" ]; then NGINX=1; fi
            SVC=`echo $1|tr -d '\-\-'`
            SVCMD+=("${DIR}server-${SVC}.sh $2")
            shift 2
            ;;
        --stdin)
            STDINCONF=1
            shift 2
            ;;
		--)
			shift
			break
			;;
        *)
            echo "Get: $1"
            usage;
            exit 1
            ;;
    esac
done

if [ -n "${HOOKURL}" ]; then
    for URL in "${HOOKURL[@]}"
    do
        echo "curl -sSL $URL"
        curl -sSL "$URL"
        echo
    done
    echo "Wait 10s for hook updates..."
    sleep 10
fi

if [ -n "${CERTDOMAIN}" ]; then
    for DOMAIN in "${CERTDOMAIN[@]}"
    do
        TRY=0
        while [ ! -f "/root/.acme.sh/${DOMAIN}/fullchain.cer" ] || [ ! -f "/root/.acme.sh/${DOMAIN}/${DOMAIN}.key" ]
        do
            echo "Requesting TLS cert for ${DOMAIN} ..."
            /root/.acme.sh/acme.sh --issue --standalone -d ${DOMAIN}
            ((TRY++))
            if [ "${TRY}" -ge 3 ]; then
                echo "Requesting TLS cert for ${DOMAIN} failed. Check log please."
                exit 3
            fi
            echo "Wait 10 seconds before checking cert again..."
            sleep 10
        done
    done
fi

echo '{"log":{"loglevel":"warning"}, "inbounds":[], "outbounds":[{"protocol":"freedom"}]}' |jq .|sponge $XCONF

xopt="xconf=$XCONF"
CERTPATH+=("/root/.acme.sh")
for cp in "${CERTPATH[@]}"
do
    xopt="$xopt,certpath=$cp"
done

if [ -n "${SVCMD}" ]; then
    for svcmd in "${SVCMD[@]}"
    do
        svcmd="$svcmd,$xopt"
        $svcmd
        if [[ $? -ne 0 ]]; then
            echo
            echo "Command failed: $svcmd"
            exit 1
        fi
    done
    if [ "${DEBUG}" = "1" ]; then
        cat $XCONF |jq '.log.loglevel |="debug"' |sponge $XCONF
        echo
        cat $XCONF
        echo
    fi
    if [ "${NGINX}" = "1" ]; then nginx; fi
    exec /usr/local/bin/xray -c $XCONF
else
    if [ "${STDINCONF}" = "1" ]; then
        exec /usr/local/bin/xray
    else
        echo "Mode selection option missing."
        usage
        exit 1
    fi
fi
