#!/bin/bash

DIR=`dirname $0`
DIR="$(cd $DIR; pwd)"
XCONF=/tmp/server-xray.json

usage() {
    echo "server-xray <server-options>"
    echo "    --ltx  <VLESS-TCP-XTLS option>        [p=443,]d=domain.com,u=id[:level[:email]][,f=[fb-host]:fb-port:[fb-path]]"
    echo "    --ltt  <VLESS-TCP-TLS option>         [p=443,]d=domain.com,u=id[:level[:email]][,f=[fb-host]:fb-port:[fb-path]]"
    echo "    --lttw <VLESS-TCP-TLS-WS option>      [p=443,]d=domain.com,u=id[:level[:email]][,f=[fb-host]:fb-port:[fb-path]],w=/webpath"
    echo "    --ltpw <VLESS-TCP-PLAIN-WS option>    [p=443,]u=id[:level[:email]][,f=[fb-host]:fb-port:[fb-path]],w=/webpath"
    echo "    --lttg <VLESS-TCP-TLS-GRPC option>    [p=443,]d=domain.com,u=id[:level[:email]],s=svcname"
    echo "    --ltpg <VLESS-TCP-PLAIN-GRPC option>  [p=443,]u=id[:level[:email]],s=svcname"
    echo "    --mtt  <VMESS-TCP-TLS option>         [p=443,]d=domain.com,u=id[:level[:email]][,f=[fb-host]:fb-port:[fb-path]]"
    echo "    --mttw <VMESS-TCP-TLS-WS option>      [p=443,]d=domain.com,u=id[:level[:email]][,f=[fb-host]:fb-port:[fb-path]],w=/webpath"
    echo "    --mtpw <VMESS-TCP-PLAIN-WS option>    [p=443,]u=id[:level[:email]][,f=[fb-host]:fb-port:[fb-path]],w=/webpath"
    echo "    --ttt  <TROJAN-TCP-TLS option>        [p=443,]d=domain.com,u=psw[:level[:email]][,f=[fb-host]:fb-port:[fb-path]]"
    echo "    --tttw <TROJAN-TCP-TLS-WS option>     [p=443,]d=domain.com,u=psw[:level[:email]][,f=[fb-host]:fb-port:[fb-path]],w=/webpath"
    echo "    --ttpw <TROJAN-TCP-PLAIN-WS option>   [p=443,]u=psw[:level[:email]][,f=[fb-host]:fb-port:[fb-path]],w=/webpath"
#   echo "    --ssa  <Shadowsocks-AEAD option>      [port=443,]user=password1:method1[,user=password2:method2]"
#   echo "    --sst  <Shadowsocks-TCP option>       [port=443,]user=passwd,method=xxxx"
    echo "    --ng-opt <nginx-options>              [p=443,]d=domain0.com[,d=domain1.com]"
    echo "    --ng-proxy <nginx-proxy-options>      [d=domain0.com,][d=domain1.com][h=127.0.0.1,]p=port-backend,l=location,n=ws|grpc"
    echo "    -u|--user <global-user-options>       u=id0[:level[:email]][,u=id1...]"
    echo "    -k|--hook <hook-url>                  [Optional] DDNS update or notifing URL to be hit"
    echo "    -r|--request-domain <domain-name>     [Optional] Domain name to request for letsencrypt cert"
    echo "    -c|--cert-path <cert-path-root>       [Optional] Reading TLS certs from folder <cert-path-root>/<domain-name>/"
    echo "    -i|--stdin                            [Optional] Read config from stdin instead of auto generation"
    echo "    -d|--debug                            [Optional] Start in debug mode with verbose output"
}

TEMP=`getopt -o u:k:r:c:di --long user:,hook:,request-domain:,cert-path:,ltx:,ltt:,lttw:,ltpw:,mtt:,mttw:,mtpw:,ttt:,tttw:,ttpw:,lttg:,ltpg:,ssa:,sst:,ng-opt:,ng-proxy:,stdin,debug -n "$0" -- $@`
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
            CERTPATH+=("$2")
            shift 2
            ;;
        -i|--stdin)
            STDINCONF=1
            shift 1
            ;;
        -d|--debug)
            DEBUG=1
            shift 1
            ;;
        -u|--user)
            UOPT+=("$2")
            shift 2
            ;;
        --ltx|--ltt|--lttw|--ltpw|--lttg|--ltpg|--mtt|--mttw|--mtpw|--ttt|--tttw|--ttpw)
            SVC=`echo $1|tr -d '\-\-'`
            SVCMD+=("${DIR}server-${SVC}.sh $2")
            shift 2
            ;;
        --ng-opt)
            NGOPT+=("$2")
            shift 2
            ;;
        --ng-proxy)
            NGPROXY+=("$2")
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Unknown option: $1"
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
for uopt in "${UOPT[@]}"
do
    xopt="$xopt,$uopt"
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

    if [ -n "${NGOPT}" ]; then
        ngcmd="${DIR}server-nginx.sh"
        for ngopt in "${NGOPT[@]}"
        do
            ngcmd="${ngcmd} --ng-opt ${ngopt},$xopt"
        done
        for ngproxy in "${NGPROXY[@]}"
        do
            ngcmd="${ngcmd} --ng-proxy ${ngproxy}"
        done
        $ngcmd
        nginx;
    fi

    exec /usr/local/bin/xray -c $XCONF

else
    if [ "${STDINCONF}" = "1" ]; then
        exec /usr/local/bin/xray
    else
        usage
        exit 1
    fi
fi
