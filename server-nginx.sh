#!/bin/bash

DIR=`dirname $0`
DIR="$(cd $DIR; pwd)"
TPL="site-ssl.conf.tpl"
STPL="nginx-stream.tpl"
NGCONF="/etc/nginx/nginx.conf"

usage() {
    echo "server-nginx --ng-server <c=certhome,d=domain>[,p=443] --ng-proxy <p=xport,l=location,n=grpc|ws|splt>[,h=127.0.0.1]"
    echo "    --ng-server   <c=cert-home-dir,d=host-domain>[,p=443]"
    echo "    --ng-proxy    <p=port-backend,l=location-path,n=grpc|ws|splt>[,h=127.0.0.1][,d=host-domain]"
    echo "    --st-port     <port-num>"
    echo "    --st-map      <sni=domain.com,ups=127.0.0.1:8443>"
}

TEMP=`getopt -o m:p:s:x: --long ng-server:,ng-proxy:,st-map:,st-port: -n "$0" -- $@`
if [ $? != 0 ] ; then usage; exit 1 ; fi

eval set -- "$TEMP"
while true ; do
    case "$1" in
        -m|--st-map)
            STMAP+=("$2")
            shift 2
            ;;
        -p|--st-port)
            STPORT="$2"
            shift 2
            ;;
        -s|--ng-server)
            NGSVR+=("$2")
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

if [ -z "${NGSVR}" ] && [ -z "${STPORT}" ]; then echo "No server/stream defined. Quit."; exit 1; fi

# Running as root to enable low port listening. Necessary for Fargate or k8s.
# sed -i 's/^user nginx;$/user root;/g' /etc/nginx/nginx.conf
#mkdir -p /run/nginx/

cd /etc/nginx/conf.d/
if [ -f /etc/nginx/conf.d/default.conf ]; then
    mv default.conf default.conf.disable
fi

if [ -n "${STPORT}" ]; then
    # Remove all lines generated previously after #STSTUB tag.
    sed -i '/\#STSTUB/q' /etc/nginx/nginx.conf
    # Remove #STSTUB tag
    sed -i '/\#STSTUB/d' /etc/nginx/nginx.conf
    rm /tmp/map.conf
    rm /tmp/ups.conf
    # Attach the stream configuration to the tail of nginx.conf
    cat ${STPL} >> /etc/nginx/nginx.conf
    for stmap in "${STMAP[@]}"
    do
        options=(`echo $stmap |tr ',' ' '`)
        for option in "${options[@]}"
        do
            kv=(`echo $option |tr '=' ' '`)
            case "${kv[0]}" in
                sni)
                    sni="${kv[1]}"
                    ;;
                ups|upstream)
                    upstream="${kv[1]}"
                    ;;
            esac
        done
        upsname=`echo $sni|sed 's/\./_/g'`
        echo "        $sni $upsname;"       >>/tmp/map.conf
        echo "    upstream $upsname {"      >>/tmp/ups.conf
        echo "        server $upstream;"    >>/tmp/ups.conf
        echo "    }"                        >>/tmp/ups.conf
    done
    sed -i '/#MAPSTUB/r /tmp/map.conf' /etc/nginx/nginx.conf
    sed -i '/#UPSSTUB/r /tmp/ups.conf' /etc/nginx/nginx.conf
    sed -i "s/STPORT/${STPORT}/g" /etc/nginx/nginx.conf
fi

for ngsvr in "${NGSVR[@]}"
do
    unset certhome
    options=(`echo $ngsvr |tr ',' ' '`)
    for option in "${options[@]}"
    do
        kv=(`echo $option |tr '=' ' '`)
        case "${kv[0]}" in
            c|certhome)
                certhome="${kv[1]}"
                ;;
            p|port)
                port="${kv[1]}"
                ;;
            d|domain)
                domain="${kv[1]}"
                DOMAIN+=("${kv[1]}")
                ;;
        esac
    done

    if [ -z "${certhome}" ]; then echo "Error: certhome undefined."; usage; exit 1; fi
    if [ -z "${domain}" ]; then echo "Error: domain undefined."; usage; exit 1; fi
    if [ -z "${port}" ]; then port=443; fi
    if ! [ "${port}" -eq "${port}" ] 2>/dev/null; then >&2 echo "Port number must be numeric"; exit 1; fi

    fullchain="${certhome}/${domain}/fullchain.cer"
    prvkey="${certhome}/${domain}/${domain}.key"
    if [ ! -f "${fullchain}" ] || [ ! -f "${prvkey}" ]; then
        echo "${domain} TLS cert missing?"
        echo "Abort."
        exit 2
    fi

    ESC_CERTFILE=$(printf '%s\n' "${fullchain}" | sed -e 's/[]\/$*.^[]/\\&/g')
    ESC_PRVKEYFILE=$(printf '%s\n' "${prvkey}" | sed -e 's/[]\/$*.^[]/\\&/g')
    cat ${TPL} \
        | sed "s/CERTFILE/${ESC_CERTFILE}/g" \
        | sed "s/PRVKEYFILE/${ESC_PRVKEYFILE}/g" \
        | sed "s/NGDOMAIN/${domain}/g" \
        | sed "s/NGPORT/${port}/g" \
        >"${domain}.conf"
done

for ngproxy in "${NGPROXY[@]}"
do
    unset xdomain xhost xport xlocation xnetwork
    options=(`echo $ngproxy |tr ',' ' '`)
    for option in "${options[@]}"
    do
        kv=(`echo $option |tr '=' ' '`)
        case "${kv[0]}" in
            d|domain)
                xdomain+=("${kv[1]}")
                ;;
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

    if [ -z "${xhost}" ]; then xhost="127.0.0.1"; fi
    if [ -z "${xdomain}" ]; then xdomain=("${DOMAIN[@]}"); fi
    if [ -z "${xnetwork}" ]; then echo "Missing network: $ngproxy"; usage; exit 1; fi
    if [ -z "${xlocation}" ]; then echo "Missing location: $ngproxy"; usage; exit 1; fi
    if [ -z "${xport}" ]; then echo "Missing port: $ngproxy"; usage; exit 1; fi
    if ! [ "${xport}" -eq "${xport}" ] 2>/dev/null; then >&2 echo "Port number must be numeric"; exit 1; fi

    for domain in "${xdomain[@]}"
    do
        if ! [ -f "${domain}.conf" ]; then echo "Assigned domain ${domain} not found"; usage; exit 1; fi
        # Replace the last(only) single line '}' with the content of tpl file, hence insert a new section into the Nginx config file
        case "${xnetwork}" in
            ws|websocket)
                sed -i -e "/^\}$/r nginx-ws.tpl" -e "/^\}$/d" ${domain}.conf
                ;;
            grpc)
                sed -i -e "/^\}$/r nginx-grpc.tpl" -e "/^\}$/d" ${domain}.conf
                ;;
            splt|proxy)
                sed -i -e "/^\}$/r nginx-proxy.tpl" -e "/^\}$/d" ${domain}.conf
                ;;
        esac
        # Then add '}' to the end of the Nginx config file
        echo -e "\n}" >> ${domain}.conf
        ESC_LOCATION=$(printf '%s\n' "${xlocation}" | sed -e 's/[]\/$*.^[]/\\&/g')
        sed -i "s/HOST/${xhost}/g" ${domain}.conf
        sed -i "s/PORT/${xport}/g" ${domain}.conf
        sed -i "s/LOCATION/${ESC_LOCATION}/g" ${domain}.conf
    done
done
exit 0
