#!/bin/bash

DIR=`dirname $0`
DIR="$(cd $DIR; pwd)"
SITE_TPL="site-ssl.conf.tpl"
STREAM_TPL="nginx-stream.tpl"
NGCONF="/etc/nginx/nginx.conf"

usage() {
    echo "server-nginx --ng-server <c=certhome,d=domain>[,p=443] --ng-proxy <p=xport,l=location,n=grpc|ws|splt>[,h=127.0.0.1]"
    echo "    --ng-proxy    <p=port-backend,l=location-path,n=grpc|ws|splt>[,h=127.0.0.1][,d=host-domain]"
    echo "    --ng-server   <c=cert-home-dir,d=host-domain>[,p=443],[proxy_acpt]"
    echo "    --st-map      <sni=domain.com,ups=127.0.0.1:8443>"
    echo "    --st-server   [p=443],[proxy_pass]"
}

TEMP=`getopt -o m:n:p:s:x: --long ng-server:,ng-proxy:,st-server:,st-map: -n "$0" -- $@`
if [ $? != 0 ] ; then usage; exit 1 ; fi

eval set -- "$TEMP"
while true ; do
    case "$1" in
        # Multiple Nginx domain servers Allowed
        -n|--ng-server)
            NGSVR+=("$2")
            shift 2
            ;;
        # Multiple Nginx proxy locations Allowed
        -x|--ng-proxy)
            NGPROXY+=("$2")
            shift 2
            ;;
        # Only SINGLE Stream server Allowed
        -s|--st-server)
            STSVR="$2"
            shift 2
            ;;
        # Multiple Nginx SNI map items Allowed
        -m|--st-map)
            STMAP+=("$2")
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

if [ -z "${NGSVR}" ] && [ -z "${STPORT}" ]; then
    echo "No Stream/Server defined. Quit.";
    usage;
    exit 1;
fi

# Running as root to enable transparent stream.
# sed -i 's/^user \+nginx;$/user  root;/g' /etc/nginx/nginx.conf
# mkdir -p /run/nginx/

cd /etc/nginx/conf.d/
if [ -f /etc/nginx/conf.d/default.conf ]; then
    mv default.conf default.conf.disable
fi

# Remove all lines generated previously after #STREAM_TAG tag.
sed -i '/\#STREAM_TAG/q' /etc/nginx/nginx.conf
# Remove #STREAM_TAG tag
sed -i '/\#STREAM_TAG/d' /etc/nginx/nginx.conf
# Remove temp files generated previously.
rm /tmp/stmap.conf; rm /tmp/stups.conf; rm /tmp/stproxy.conf

if [ -n "${STSVR}" ]; then
options=(`echo $STSVR |tr ',' ' '`)
    for option in "${options[@]}"
    do
        kv=(`echo $option |tr '=' ' '`)
        case "${kv[0]}" in
            p|port)
                STPORT="${kv[1]}"
                ;;
            x|proxy_pass)
                STPROXY_PASS=1
                ;;
        esac
    done

    if [ -z "${STPORT}" ]; then STPORT=443; fi
    if ! [ "${STPORT}" -eq "${STPORT}" ] 2>/dev/null; then
        >&2 echo "Stream port number must be numeric";
        exit 1;
    fi

    # Attach the stream configuration to the tail of nginx.conf
    cat ${STREAM_TPL} >> /etc/nginx/nginx.conf
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
        # Named the upstream as yahoo_com for SNI yahoo.com
        upsname=`echo $sni|sed 's/\./_/g'`
        echo "        $sni $upsname;"       >>/tmp/stmap.conf
        echo "    upstream $upsname {"      >>/tmp/stups.conf
        echo "        server $upstream;"    >>/tmp/stups.conf
        echo "    }"                        >>/tmp/stups.conf
    done

    # Add map.conf down to #XMAP_TAG tag
    sed -i '/#XMAP_TAG/r /tmp/stmap.conf' /etc/nginx/nginx.conf
    # Add ups.conf down to #XUPSTREAM_TAG tag
    sed -i '/#XUPSTREAM_TAG/r /tmp/stups.conf' /etc/nginx/nginx.conf
    sed -i "s/STPORT/${STPORT}/g" /etc/nginx/nginx.conf
    # Add "proxy_protocol=on" down to #STPROXY_PASS_TAG tag
    if [ -n "${STPROXY_PASS}" ]; then
        echo "        proxy_protocol on;" >/tmp/stproxy.conf
        sed -i '/#STPROXY_PASS_TAG/r /tmp/stproxy.conf' /etc/nginx/nginx.conf
    fi
    echo "Generated /etc/nginx/nginx.conf ====>"
    cat /etc/nginx/nginx.conf
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
            proxy_acpt)
                NGPROTOCOL="proxy_protocol"
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
    cat "${SITE_TPL}" \
        | sed "s/CERTFILE/${ESC_CERTFILE}/g" \
        | sed "s/PRVKEYFILE/${ESC_PRVKEYFILE}/g" \
        | sed "s/NGDOMAIN/${domain}/g" \
        | sed "s/NGPORT/${port}/g" \
        | sed "s/NGPROTOCOL/${NGPROTOCOL}/g" \
        >"${domain}.conf"
    # Applying proxy log format instead of main format when --ng-server proxy_pass was set
    if [ -n "${NGPROTOCOL}" ]; then
        sed -i '/access_log/s/main/proxy/' "${domain}.conf"
        sed -i 's/remote_addr/proxy_protocol_addr/g' "${domain}.conf"
        sed -i 's/proxy_add_x_forwarded_for/proxy_protocol_addr/g' "${domain}.conf"
    fi
    echo "Generated /etc/nginx/conf.d/${domain}.conf ====>"
    cat /etc/nginx/conf.d/${domain}.conf
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
        # Add tpl file content down to #LOCATION tag
        case "${xnetwork}" in
            ws|websocket)
                sed -i '/#XLOCATION_TAG/r nginx-ws.tpl' ${domain}.conf
                ;;
            grpc)
                sed -i '/#XLOCATION_TAG/r nginx-grpc.tpl' ${domain}.conf
                ;;
            splt|proxy)
                sed -i '/#XLOCATION_TAG/r nginx-proxy.tpl' ${domain}.conf
                ;;
        esac
        ESC_LOCATION=$(printf '%s\n' "${xlocation}" | sed -e 's/[]\/$*.^[]/\\&/g')
        sed -i "s/HOST/${xhost}/g" ${domain}.conf
        sed -i "s/PORT/${xport}/g" ${domain}.conf
        sed -i "s/WEBPATH/${ESC_LOCATION}/g" ${domain}.conf
        # Applying proxy log format instead of main format when --ng-server proxy_pass was set
        if [ -n "${NGPROTOCOL}" ]; then
            sed -i '/access_log/s/main/proxy/' "${domain}.conf"
            sed -i 's/remote_addr/proxy_protocol_addr/g' "${domain}.conf"
            sed -i 's/proxy_add_x_forwarded_for/proxy_protocol_addr/g' "${domain}.conf"
        fi
        echo "Generated /etc/nginx/conf.d/${domain}.conf ====>"
        cat /etc/nginx/conf.d/${domain}.conf
    done
done
exit 0
