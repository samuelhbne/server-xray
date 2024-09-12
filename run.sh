#!/bin/bash

DIR=`dirname $0`
DIR="$(cd $DIR; pwd)"
CERTHOME="/root/.acme.sh"
XCONF=/tmp/server-xray.json

usage() {
    echo "server-xray <server-options>"
    echo "    --lgp     <VLESS-GRPC-PLN option>     p=11443,u=id1,u=id2...,s=svcname"
    echo "    --lgr     <VLESS-GRPC-RLTY option>    p=12443,u=id1,u=id2...,s=svcname,d=dest.com,pub=xx,prv=yy[,shortId=ab]"
    echo "    --lgt     <VLESS-GRPC-TLS option>     p=13443,u=id1,u=id2...,s=svcname,d=domain.com"
    echo "    --lsp     <VLESS-SPLT-PLN option>     p=14443,u=id1,u=id2...,w=/webpath"
    echo "    --lst     <VLESS-SPLT-TLS option>     p=16443,u=id1,u=id2...,w=/webpath,d=domain.com"
    echo "    --ltr     <VLESS-TCP-RLTY option>     p=17443,u=id1,u=id2...,d=dest.com,pub=xx,prv=yy[,shortId=ab],[xtls]"
    echo "    --ltrx    <VLESS-TCP-RLTY option>     p=17443,u=id1,u=id2...,d=dest.com,pub=xx,prv=yy[,shortId=ab]"
    echo "    --ltt     <VLESS-TCP-TLS option>      p=18443,u=id1,u=id2...,d=domain.com,[xtls]"
    echo "    --lttx    <VLESS-TCP-TLS option>      p=18443,u=id1,u=id2...,d=domain.com"
    echo "    --lwp     <VLESS-WS-PLN option>       p=19443,u=id1,u=id2...,w=/wskpath"
    echo "    --lwt     <VLESS-WS-TLS option>       p=22443,u=id1,u=id2...,w=/wskpath,d=domain.com"
    echo "    --mtt     <VMESS-TCP-TLS option>      p=23443,u=id1,u=id2...,d=domain.com"
    echo "    --mwp     <VMESS-WS-PLN option>       p=24443,u=id1,u=id2...,w=/wskpath"
    echo "    --mwt     <VMESS-WS-TLS option>       p=25443,u=id1,u=id2...,w=/wskpath,d=domain.com"
    echo "    --ttt     <TROJAN-TCP-TLS option>     p=26443,u=pw1,u=pw2...,d=domain.com"
    echo "    --twp     <TROJAN-WS-PLN option>      p=27443,u=pw1,u=pw2...,w=/wskpath"
    echo "    --twt     <TROJAN-WS-TLS option>      p=28443,u=pw1,u=pw2...,w=/wskpath,d=domain.com"
    echo "    --ng-server   <nginx-server-options>  p=8443,d=domain0.com,d=domain1.com..."
    echo "    --ng-proxy    <nginx-proxy-options>   d=domain0.com,d=domain1.com,p=port-backend,l=location,n=ws|grpc|splt"
    echo "    --st-port     <stream-port-number>    443"
    echo "    --st-map      <stream-map-options>    sni=domain.com,ups=127.0.0.1:8443"
    echo "    --domain-block <domain-rule>          Add a domain rule for routing-server block, like geosite:category-ads-all"
    echo "    --ip-block    <ip-rule>               Add a ip-addr rule for routing block, like geoip:private"
    echo "    --cn-block                            Add routing rules to avoid domains and IPs located in China being proxied"
    echo "    -u|--user     <global-user-options>   u=id0,u=id1..."
    echo "    -k|--hook     <hook-url>              DDNS update or notifing URL to be hit"
    echo "    -r|--request-domain <domain-name>     Domain name to request for letsencrypt cert"
    echo "    -c|--cert-home <cert-home-dir>        Reading TLS certs from folder <cert-home-dir>/<domain-name>/"
    echo "    -i|--stdin                            Read config from STDIN instead of auto generation"
    echo "    -j|--json                             Json snippet to merge into the config. Say '{"log":{"loglevel":"info"}'"
    echo "    -d|--debug                            Start in debug mode with verbose output"
}

Jrules='{"rules":[]}'

TEMP=`getopt -o u:k:r:c:j:di --long lgp:,lgr:,lgt:,lsp:,lst:,ltr:,ltrx:,ltt:,lttx:,lwp:,lwt:,mtt:,mwp:,mwt:,ttt:,twp:,twt:,user:,hook:,request-domain:,cert-home:,ip-block:,domain-block:,cn-block,ng-server:,ng-proxy:,st-port:,st-map:,json:,stdin,debug -n "$0" -- $@`
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
        -c|--cert-home)
            CERTHOME="$2"
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
        -j|--json)
            INJECT+=("$2")
            shift 2
            ;;
        --lgp|--lgr|--lgt|--lsp|--lst|--ltr|--ltt|--lwp|--lwt|--mtt|--mwp|--mwt|--ttt|--twp|--twt)
            SVC=`echo $1|tr -d '\-\-'`
            SVCMD+=("${DIR}/server-${SVC}.sh $2")
            shift 2
            ;;
        # Alias options
        --ltrx|--lttx)
            SVC=`echo $1|tr -d '\-\-'|tr -d x`
            SVCMD+=("${DIR}/server-${SVC}.sh $2,xtls")
            shift 2
            ;;
        --domain-block)
            Jrules=`echo "${Jrules}" | jq --arg blkdomain "$2" \
            '.rules += [{"type":"field", "outboundTag":"block", "domain":[$blkdomain]}]'`
            shift 2
            ;;
        --ip-block)
            Jrules=`echo "${Jrules}" | jq --arg blkip "$2" \
            '.rules += [{"type":"field", "outboundTag":"block", "ip":[$blkip]}]'`
            shift 2
            ;;
        --cn-block)
            Jrules=`echo "${Jrules}" | jq --arg igndomain "geosite:geolocation-cn" \
            '.rules += [{"type":"field", "outboundTag":"block", "domain":[$igndomain]}]'`
            Jrules=`echo "${Jrules}" | jq --arg igndomain "geosite:cn" \
            '.rules += [{"type":"field", "outboundTag":"block", "domain":[$igndomain]}]'`
            Jrules=`echo "${Jrules}" | jq --arg ignip "geoip:cn" \
            '.rules += [{"type":"field", "outboundTag":"block", "ip":[$ignip]}]'`
            shift 1
            ;;
        --ng-server)
            NGSVR+=("$2")
            shift 2
            ;;
        --ng-proxy)
            NGPROXY+=("$2")
            shift 2
            ;;
        --st-port)
            STPORT="$2"
            shift 2
            ;;
        --st-map)
            STMAP+=("$2")
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
    echo "Wait 30s for hook updates..."
    sleep 30
fi

if [ -n "${CERTDOMAIN}" ]; then
    for DOMAIN in "${CERTDOMAIN[@]}"
    do
        TRY=0
        while [ ! -f "/${CERTHOME}/${DOMAIN}/fullchain.cer" ] || [ ! -f "/${CERTHOME}/${DOMAIN}/${DOMAIN}.key" ]
        do
            echo "Requesting TLS cert for ${DOMAIN} ..."
            echo "/root/acme.sh/acme.sh --cert-home ${CERTHOME} --issue --standalone -d ${DOMAIN} --debug"
            /root/acme.sh/acme.sh --cert-home "${CERTHOME}" --issue --standalone -d ${DOMAIN} --debug
            ((TRY++))
            if [ "${TRY}" -ge 3 ]; then
                echo "Requesting TLS cert for ${DOMAIN} failed. Check log please."
                exit 3
            fi
            echo "Wait 30 seconds before checking cert again..."
            sleep 30
        done
    done
fi

echo '{"log":{"loglevel":"warning"}, "inbounds":[], "outbounds":[{"protocol":"freedom"}]}' |jq .|sponge $XCONF

xopt="xconf=$XCONF"
xopt="$xopt,certhome=$CERTHOME"
for uopt in "${UOPT[@]}"
do
    xopt="$xopt,$uopt"
done

# Add routing config
Jrouting='{"routing": {"domainStrategy":"AsIs"}}'
Jrouting=`echo "${Jrouting}" |jq --argjson jrules "${Jrules}" '.routing += $jrules'`
cat $XCONF| jq --argjson jrouting "${Jrouting}" '. += $jrouting' | sponge $XCONF

# Run Xray only. Read Xray config from STDIN
if [ "${STDINCONF}" = "1" ]; then
    exec /usr/local/bin/xray
fi

if [ -z "${SVCMD}" ]; then
    echo "No Xray service creation found. Quit."
    exit 1
fi

# Start Nginx if necessary
if [ -n "${STPORT}" ]; then
    NGOPT="--st-port ${STPORT}"
    for mapopt in "${STMAP[@]}"
    do
        NGOPT="${NGOPT} --st-map $mapopt"
    done
fi

if [ -n "${NGSVR}" ]; then
    for svropt in "${NGSVR[@]}"
    do
        NGOPT="${NGOPT} --ng-server ${svropt},$xopt"
    done
    for pxyopt in "${NGPROXY[@]}"
    do
        NGOPT="${NGOPT} --ng-proxy ${pxyopt}"
    done
fi

if [ -n "${NGOPT}" ]; then
    ngcmd="${DIR}/server-nginx.sh $NGOPT"
    $ngcmd
    ret=$?; if [ $ret != 0 ]; then
        echo ""
        echo "Nginx config generation failed from the following cmd:\n$ngcmd";
        echo "Please check log for details"
        exit $ret;
    fi
    killall nginx
    nginx;
fi

# Xray service config generation
for svcmd in "${SVCMD[@]}"
do
    svcmd="$svcmd,$xopt"
    $svcmd
    if [[ $? -ne 0 ]]; then
        echo
        echo "Service creation command failed: $svcmd"
        exit 1
    fi
done

if [ "${DEBUG}" = "1" ]; then
    cat $XCONF |jq '.log.loglevel |="debug"' |sponge $XCONF
    echo
fi

if [ -n "${INJECT}" ]; then
    for JSON_IN in "${INJECT[@]}"
    do
        echo "${JSON_IN}"|jq -ec >/tmp/merge.json
        if [[ $? -ne 0 ]]; then
            echo "Invalid json ${JSON_IN}"
            exit 1
        fi
        jq -s '.[0] * .[1]' $XCONF /tmp/merge.json |sponge $XCONF
    done
fi

cat $XCONF
echo
exec /usr/local/bin/xray -c $XCONF

fi
