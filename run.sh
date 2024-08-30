#!/bin/bash

#while :; do sleep 2073600; done

DIR=`dirname $0`
DIR="$(cd $DIR; pwd)"
CERTHOME="/root/.acme.sh"
XCONF=/tmp/server-xray.json

usage() {
    echo "server-xray <server-options>"
    echo "    --lx  <VLESS-XTLS option>         [p=443,]d=domain.com,u=id[:level[:email]]"
    echo "    --ls  <VLESS-TLS option>          [p=443,]d=domain.com,u=id[:level[:email]]"
    echo "    --ms  <VMESS-TLS option>          [p=443,]d=domain.com,u=id[:level[:email]]"
    echo "    --ts  <TROJAN-TLS option>         [p=443,]d=domain.com,u=psw[:level[:email]]"
    echo "    --lsg <VLESS-TLS-GRPC option>     [p=443,]d=domain.com,u=id[:level[:email]],s=svcname"
    echo "    --lss <VLESS-TLS-SPLT option>     [p=443,]d=domain.com,u=id[:level[:email]],w=/webpath"
    echo "    --lsw <VLESS-TLS-WS option>       [p=443,]d=domain.com,u=id[:level[:email]],w=/wspath"
    echo "    --msw <VMESS-TLS-WS option>       [p=443,]d=domain.com,u=id[:level[:email]],w=/wspath"
    echo "    --tsw <TROJAN-TLS-WS option>      [p=443,]d=domain.com,u=psw[:level[:email]],w=/wspath"
    echo "    --lpg <VLESS-PLN-GRPC option>     [p=443,]u=id[:level[:email]],s=svcname"
    echo "    --lps <VLESS-PLN-SPLT option>     [p=443,]u=id[:level[:email]],w=/webpath"
    echo "    --lpw <VLESS-PLN-WS option>       [p=443,]u=id[:level[:email]],w=/wspath"
    echo "    --mpw <VMESS-PLN-WS option>       [p=443,]u=id[:level[:email]],w=/wspath"
    echo "    --tpw <TROJAN-PLN-WS option>      [p=443,]u=psw[:level[:email]],w=/wspath"
    echo "    --ng-opt <nginx-options>          [p=443,]d=domain0.com[,d=domain1.com][...]"
    echo "    --ng-proxy <nginx-proxy-options>  [d=domain0.com,][d=domain1.com,]p=port-backend,l=location,n=ws|grpc|splt"
    echo "    --domain-block <domain-rule>      Add a domain rule for routing block, like geosite:category-ads-all"
    echo "    --ip-block <ip-rule>              Add a ip-addr rule for routing block, like geoip:private"
    echo "    --cn-block                        Add routing rules to avoid domains and IPs located in China being proxied"
    echo "    -u|--user  <global-user-options>  u=id0[:level[:email]][,u=id1][...]"
    echo "    -k|--hook  <hook-url>             DDNS update or notifing URL to be hit"
    echo "    -r|--request-domain <domain-name> Domain name to request for letsencrypt cert"
    echo "    -c|--cert-home <cert-home-dir>    Reading TLS certs from folder <cert-home-dir>/<domain-name>/"
    echo "    -i|--stdin                        Read config from STDIN instead of auto generation"
    echo "    -j|--json                         '{"log":{"loglevel":"info"}' Json snippet to merge into the config"
    echo "    -d|--debug                        Start in debug mode with verbose output"
}

Jrules='{"rules":[]}'

TEMP=`getopt -o u:k:r:c:j:di --long user:,hook:,request-domain:,cert-home:,ip-block:,domain-block:,cn-block,lx:,ls:,ms:,ts:,lsg:,lss:,lsw:,msw:,tsw:,lpg:,lps:,lpw:,mpw:,tpw:,ng-opt:,ng-proxy:,json:,stdin,debug -n "$0" -- $@`
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
        --lx|--ls|--ms|--ts|--lsg|--lss|--lsw|--msw|--tsw|--lpg|--lps|--lpw|--mpw|--tpw)
            SVC=`echo $1|tr -d '\-\-'`
            SVCMD+=("${DIR}server-${SVC}.sh $2")
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
        ret=$?; if [ $ret != 0 ] ; then echo "\nNon-zero result $ret from the following cmd:\n$ngcmd"; exit $ret ; fi
        nginx;
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

    exec /usr/local/bin/xray -c $XCONF

else
    if [ "${STDINCONF}" = "1" ]; then
        exec /usr/local/bin/xray
    else
        usage
        exit 1
    fi
fi
