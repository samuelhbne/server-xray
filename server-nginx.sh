#!/bin/bash

DIR=`dirname $0`
DIR="$(cd $DIR; pwd)"

usage() {
    echo "Usage: server-nginx --ng-opt <nginx-options> --ng-proxy <nginx-proxy-options>"
}

TEMP=`getopt -o o:x: --long ng-opt:,ng-proxy: -n "$0" -- $@`
if [ $? != 0 ] ; then usage; exit 1 ; fi

eval set -- "$TEMP"
while true ; do
    case "$1" in
        -o|--ng-opt)
            NGOPT="$2"
            shift 2
            ;;
        -x|--ng-proxy)
            NGPROXY+=("$2")
            shift 2
            ;;        
        --)
            shift
            break
            ;;
        *)
            echo "Unrecogonised opt: $1"
            usage;
            exit 1
            ;;
    esac
done

options=(`echo $NGOPT |tr ',' ' '`)
for option in "${options[@]}"
do
    kv=(`echo $option |tr '=' ' '`)
    case "${kv[0]}" in
        c|certpath)
            certpath+=("${kv[1]}")
            ;;
        p|port)
            port="${kv[1]}"
            ;;
        d|domain)
            domain="${kv[1]}"
            ;;
    esac
done

if [ -z "${certpath}" ]; then
    echo "Error: certpath undefined."
    usage
    exit 1
fi

if [ -z "${port}" ]; then
    port=443
fi

if [ -z "${domain}" ]; then
    echo "Error: domain undefined."
    usage
    exit 1
fi

if ! [ "${port}" -eq "${port}" ] 2>/dev/null; then >&2 echo "Port number must be numeric"; exit 1; fi

for certroot in "${certpath[@]}"
do
    if [ -f "${certroot}/${domain}/fullchain.cer" ] && [ -f "${certroot}/${domain}/${domain}.key" ]; then
        fullchain="${certroot}/${domain}/fullchain.cer"
        prvkey="${certroot}/${domain}/${domain}.key"
        break
    fi
done

if [ ! -f "${fullchain}" ] || [ ! -f "${prvkey}" ]; then
    echo "TLS cert missing?"
    echo "Abort."
    exit 2
fi

# Running as root to enable low port listening. Necessary for Fargate or k8s.
sed -i 's/^user nginx;$/user root;/g' /etc/nginx/nginx.conf
mkdir -p /run/nginx/

cd /etc/nginx/http.d/

if [ -f /etc/nginx/http.d/default.conf ]; then
    mv default.conf default.conf.disable
fi

TPL="site-ssl.conf.tpl"

ESC_CERTFILE=$(printf '%s\n' "${fullchain}" | sed -e 's/[]\/$*.^[]/\\&/g')
ESC_PRVKEYFILE=$(printf '%s\n' "${prvkey}" | sed -e 's/[]\/$*.^[]/\\&/g')
cat ${TPL} \
    | sed "s/CERTFILE/${ESC_CERTFILE}/g" \
    | sed "s/PRVKEYFILE/${ESC_PRVKEYFILE}/g" \
    | sed "s/NGDOMAIN/${domain}/g" \
    | sed "s/NGPORT/${port}/g" \
    >site-xray.conf

for ngproxy in "${NGPROXY[@]}"
do
    options=(`echo $ngproxy |tr ',' ' '`)
    for option in "${options[@]}"
    do
        kv=(`echo $option |tr '=' ' '`)
        case "${kv[0]}" in
            h|host)
                xhost="${kv[1]}"
                ;;
            p|port)
                xport="${kv[1]}"
                ;;
            l|location)
                xlocation="${kv[1]}"
                ;;
            n|network)
                xnetwork="${kv[1]}"
                ;;
        esac
    done

    # Replace the last(only) single line '}' with specific tpl file, hence insert a new section into the Nginx config file
    case "${xnetwork}" in
        ws|websocket)
            sed -i -e "/^\}$/r ws.tpl" -e "/^\}$/d" site-xray.conf
            ;;
        grpc)
            sed -i -e "/^\}$/r grpc.tpl" -e "/^\}$/d" site-xray.conf
            ;;
    esac
    # Then add '}' to the end of the Nginx config file
    echo -e "\n}" >> site-xray.conf
    ESC_LOCATION=$(printf '%s\n' "${xlocation}" | sed -e 's/[]\/$*.^[]/\\&/g')
    sed -i "s/PORT/${xport}/g" site-xray.conf
    sed -i "s/LOCATION/${ESC_LOCATION}/g" site-xray.conf
done
