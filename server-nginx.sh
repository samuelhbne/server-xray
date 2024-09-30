#!/bin/bash

SITE_TPL="nginx-site.tpl"
STREAM_TPL="nginx-stream.tpl"
NGCONF="/etc/nginx/nginx.conf"

usage() {
    >&2 echo "server-nginx --ng-server <c=certhome,d=domain>[,p=443] --ng-proxy <p=xport,l=location,n=grpc|ws|splt>[,h=127.0.0.1]"
    >&2 echo "    --ng-proxy    <p=port-backend,l=location-path,n=grpc|ws|splt>[,h=127.0.0.1][,d=host-domain]"
    >&2 echo "    --ng-server   <c=cert-home-dir,d=domain0.com,d=domain1.com>[,p=443],[proxy_acpt]"
    >&2 echo "    --st-map      <sni=domain.com,ups=127.0.0.1:8443>"
    >&2 echo "    --st-server   [p=443],[proxy_pass]"
}

TEMP=$(getopt -o m:n:p:s:x: --long ng-server:,ng-proxy:,st-server:,st-map: -n "$0" -- "$@")
if [ $? != 0 ] ; then usage; exit 1 ; fi

eval set -- "$TEMP"
while true ; do
    case "$1" in
        -n|--ng-server)
            # Multiple Nginx domain servers Allowed
            NGSVR+=("$2")
            shift 2
            ;;
        -x|--ng-proxy)
            # Multiple Nginx proxy locations Allowed
            NGPROXY+=("$2")
            shift 2
            ;;
        -s|--st-server)
            # Only SINGLE Stream server Allowed
            STSVR="$2"
            shift 2
            ;;
        -m|--st-map)
            # Multiple Nginx SNI map items Allowed
            STMAP+=("$2")
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            >&2 echo -e "Unrecogonised opt: $1\n"
            usage; exit 1
            ;;
    esac
done

if [ "${#NGSVR[@]}" -eq 0 ] && [ -z "${STSVR}" ]; then
    >&2 echo -e "No Stream/Server defined. Quit.\n";
    usage; exit 1;
fi

# Running as root to enable transparent stream.
# sed -i 's/^user \+nginx;$/user  root;/g' $NGCONF

cd /etc/nginx/conf.d/
if [ -f /etc/nginx/conf.d/default.conf ]; then
    mv default.conf default.conf.disable
fi

# Remove all lines generated previously after #STREAM_TAG tag.
sed -i '/\#STREAM_TAG/q' $NGCONF
# Remove #STREAM_TAG tag
sed -i '/\#STREAM_TAG/d' $NGCONF

# Generate Nginx Stream server configuration.
if [ -n "${STSVR}" ]; then
options=($(echo $STSVR |tr ',' ' '))
    for option in "${options[@]}"
    do
        kv=($(echo $option |tr '=' ' '))
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
    if ! [ "${STPORT}" -eq "${STPORT}" ] 2>/dev/null; then >&2 echo "Stream port number must be numeric"; exit 1; fi

    # Attaching the stream configuration template to the tail of nginx.conf
    cat ${STREAM_TPL} >> $NGCONF
    for stmap in "${STMAP[@]}"
    do
        options=($(echo $stmap |tr ',' ' '))
        for option in "${options[@]}"
        do
            kv=($(echo $option |tr '=' ' '))
            case "${kv[0]}" in
                sni)
                    sni="${kv[1]}"
                    ;;
                ups|upstream)
                    upstream="${kv[1]}"
                    ;;
            esac
        done
        # Naming the upstream as yahoo_com_jp for SNI yahoo.com.jp
        upsname="${sni//\./_}"
        echo "        $sni $upsname;"       >>/tmp/stmap.conf
        echo "    upstream $upsname {"      >>/tmp/stups.conf
        echo "        server $upstream;"    >>/tmp/stups.conf
        echo "    }"                        >>/tmp/stups.conf
    done

    # Adding map.conf down to #XMAP_TAG tag
    sed -i '/#XMAP_TAG/r /tmp/stmap.conf' $NGCONF
    # Adding ups.conf down to #XUPSTREAM_TAG tag
    sed -i '/#XUPSTREAM_TAG/r /tmp/stups.conf' $NGCONF
    sed -i "s/STPORT/${STPORT}/g" $NGCONF
    # Adding "proxy_protocol=on" down to #STPROXY_PASS_TAG tag
    if [ -n "${STPROXY_PASS}" ]; then
        echo "        proxy_protocol on;" >/tmp/stproxy.conf
        sed -i '/#STPROXY_PASS_TAG/r /tmp/stproxy.conf' $NGCONF
    fi
    rm -rf /tmp/stmap.conf; rm -rf /tmp/stups.conf; rm -rf /tmp/stproxy.conf
    echo "Generated $NGCONF ====>"
    cat $NGCONF
fi

# Generating Nginx site server configurations.
for ngsvr in "${NGSVR[@]}"
do
    unset certhome NGPROTOCOL
    # removing site default config file if any. 
    rm -rf /etc/nginx/conf.d/00_default_*.conf
    options=($(echo $ngsvr |tr ',' ' '))
    for option in "${options[@]}"
    do
        kv=($(echo $option |tr '=' ' '))
        case "${kv[0]}" in
            c|certhome)
                certhome="${kv[1]}"
                ;;
            p|port)
                port="${kv[1]}"
                ;;
            d|domain)
                SITEDOMAINS+=("${kv[1]}")
                # Add each server domain into full domain list
                ALLDOMAINS+=("${kv[1]}")
                ;;
            proxy_acpt)
                NGPROTOCOL="proxy_protocol"
                ;;
        esac
    done

    if [ -z "${certhome}" ]; then echo -e "Error: Nginx certhome undefined.\n"; usage; exit 1; fi
    if [ "${#SITEDOMAINS[@]}" -eq 0 ]; then echo -e "Error: Nginx site domain undefined.\n"; usage; exit 1; fi
    if [ -z "${port}" ]; then port=443; fi
    if ! [ "${port}" -eq "${port}" ] 2>/dev/null; then >&2 echo -e "Port number must be numeric. \n"; exit 1; fi

    # Generating default site config for every --ngserver invocation
    # to avoid domain name leaking against bot probing.
    default_domain="00_default_${port}"
    (
        mkdir "${certhome}/${default_domain}"; cd "${certhome}/${default_domain}"
        # Generating self-signed cert for default domain.
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "${default_domain}.key" -out fullchain.cer -subj "/C=US/ST=NV/L=Vegas/O=Internic/CN=localhost"
    )
    SITEDOMAINS+=("${default_domain}")
    # Generating site config files for each domain including default domain.
    for site_domain in "${SITEDOMAINS[@]}"
    do
        fullchain="${certhome}/${site_domain}/fullchain.cer"
        prvkey="${certhome}/${site_domain}/${site_domain}.key"
        if [ ! -f "${fullchain}" ] || [ ! -f "${prvkey}" ]; then >&2 echo -e "${site_domain} TLS cert missing?\nAbort.\n"; exit 2; fi

        ESC_CERTFILE=$(printf '%s\n' "${fullchain}" | sed -e 's/[]\/$*.^[]/\\&/g')
        ESC_PRVKEYFILE=$(printf '%s\n' "${prvkey}" | sed -e 's/[]\/$*.^[]/\\&/g')
        cat "${SITE_TPL}" \
            | sed "s/CERTFILE/${ESC_CERTFILE}/g" \
            | sed "s/PRVKEYFILE/${ESC_PRVKEYFILE}/g" \
            | sed "s/NGDOMAIN/${site_domain}/g" \
            | sed "s/NGPORT/${port}/g" \
            | sed "s/NGPROTOCOL/${NGPROTOCOL}/g" \
            >"${site_domain}.conf"
        # Applying proxy log format instead of main format when --ng-server proxy_pass was set
        if [ -n "${NGPROTOCOL}" ]; then
            sed -i '/access_log/s/main/proxy/' "${site_domain}.conf"
            sed -i 's/remote_addr/proxy_protocol_addr/g' "${site_domain}.conf"
            sed -i 's/proxy_add_x_forwarded_for/proxy_protocol_addr/g' "${site_domain}.conf"
        fi
        echo "Generated /etc/nginx/conf.d/${site_domain}.conf ====>"
        cat /etc/nginx/conf.d/${site_domain}.conf
    done
done

# Adding proxy locations into site domain conf files
for ngproxy in "${NGPROXY[@]}"
do
    unset XDOMAINS xhost xport xlocation xnetwork
    options=($(echo $ngproxy |tr ',' ' '))
    for option in "${options[@]}"
    do
        kv=($(echo $option |tr '=' ' '))
        case "${kv[0]}" in
            d|domain)
                XDOMAINS+=("${kv[1]}")
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
    if [ "${#XDOMAINS[@]}" -eq 0 ]; then XDOMAINS=("${ALLDOMAINS[@]}"); fi
    if [ -z "${xnetwork}" ]; then echo "Missing network: $ngproxy"; usage; exit 1; fi
    if [ -z "${xlocation}" ]; then echo "Missing location: $ngproxy"; usage; exit 1; fi
    if [ -z "${xport}" ]; then echo "Missing port: $ngproxy"; usage; exit 1; fi
    if ! [ "${xport}" -eq "${xport}" ] 2>/dev/null; then >&2 echo "Port number must be numeric"; exit 1; fi

    for xdomain in "${XDOMAINS[@]}"
    do
        if ! [ -f "${xdomain}.conf" ]; then echo "Assigned proxy domain ${xdomain} not found"; usage; exit 1; fi
        # Add tpl file content down to #LOCATION tag
        case "${xnetwork}" in
            ws|websocket)
                sed -i '/#XLOCATION_TAG/r nginx-ws.tpl' ${xdomain}.conf
                ;;
            grpc)
                sed -i '/#XLOCATION_TAG/r nginx-grpc.tpl' ${xdomain}.conf
                ;;
            splt|proxy)
                sed -i '/#XLOCATION_TAG/r nginx-proxy.tpl' ${xdomain}.conf
                ;;
        esac
        ESC_LOCATION=$(printf '%s\n' "${xlocation}" | sed -e 's/[]\/$*.^[]/\\&/g')
        sed -i "s/HOST/${xhost}/g" ${xdomain}.conf
        sed -i "s/PORT/${xport}/g" ${xdomain}.conf
        sed -i "s/WEBPATH/${ESC_LOCATION}/g" ${xdomain}.conf
        # Applying proxy log format instead of main format when --ng-server proxy_pass was set
        if [ -n "${NGPROTOCOL}" ]; then
            sed -i '/access_log/s/main/proxy/' "${xdomain}.conf"
            sed -i 's/remote_addr/proxy_protocol_addr/g' "${xdomain}.conf"
            sed -i 's/proxy_add_x_forwarded_for/proxy_protocol_addr/g' "${xdomain}.conf"
        fi
        echo "Generated /etc/nginx/conf.d/${xdomain}.conf ====>"
        cat /etc/nginx/conf.d/${xdomain}.conf
    done
done
exit 0
