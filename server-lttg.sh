#!/bin/bash

usage() {
    echo "Usage: server-gttn <xconf=xray-config-file>,<certpath=cert-path-root>,<port=443>,<domain=mydomain.com>,<user=xxx-xxx[:0[:a@mail.com]]>,<service=svcname>,<gport=65443>"
}

options=(`echo $1 |tr ',' ' '`)
for option in "${options[@]}"
do
    kv=(`echo $option |tr '=' ' '`)
    case "${kv[0]}" in
        x|xconf)
            xconf="${kv[1]}"
            ;;
        c|certpath)
            certpath+=("${kv[1]}")
            ;;
        p|port)
            port="${kv[1]}"
            ;;
        d|domain)
            domain="${kv[1]}"
            ;;
        u|user)
            xuser+=("${kv[1]}")
            ;;
        g|gport)
            gport="${kv[1]}"
            ;;
        s|service)
            service="${kv[1]}"
            ;;
    esac
done

if [ -z "${certpath}" ]; then
    echo "Error: certpath undefined."
    usage
    exit 1
fi

if [ -z "${xconf}" ]; then
    echo "Error: xconf undefined."
    usage
    exit 1
fi

if [ -z "${port}" ]; then
    echo "Error: port undefined."
    usage
    exit 1
fi

if [ -z "${gport}" ]; then
    echo "Error: gport undefined."
    usage
    exit 1
fi

if [ -z "${domain}" ]; then
    echo "Error: domain undefined."
    usage
    exit 1
fi

if [ -z "${xuser}" ]; then
    echo "Error: user undefined."
    usage
    exit 1
fi

XCONF=$xconf
cat $XCONF |jq --arg gport "${gport}" '.inbounds +=[{"port":($gport|tonumber), "protocol":"vless", "settings":{"clients":[]}}]' |sponge $XCONF

for xu in "${xuser[@]}"
do
    IFS=':'
    uopt=(${xu})
    uopt=(${uopt[@]})

    if [ -z "${uopt[0]}" ]; then
        echo "Incorrect user format: ${xu}"
        echo "Correct user format: user=<uuid>[:level:email]"
        echo "Like: user=805b2209-c26f-48d6-ba52-07b7d894f962:0:me@g.cn"
        echo "Like: user=805b2209-c26f-48d6-ba52-07b7d894f962::me@g.cn"
        echo "Like: user=805b2209-c26f-48d6-ba52-07b7d894f962:0"
        echo "Like: user=805b2209-c26f-48d6-ba52-07b7d894f962"
        exit 1
    fi
    if [ -z "${uopt[1]}" ]; then
        uopt[1]=0
    fi
    if [ -z "${uopt[2]}" ]; then
        uopt[2]="nobody@g.cn"
    fi
    cat $XCONF |jq --arg gport "${gport}" --arg uid "${uopt[0]}" --arg level "${uopt[1]}" --arg email "${uopt[2]}" \
    '( .inbounds[] | select(.port == ($gport|tonumber)) | .settings.clients ) += [ {"id":$uid, "level":($level|tonumber), "email":$email} ] ' \
    |sponge $XCONF
done

cat $XCONF |jq --arg gport "${gport}" \
'( .inbounds[] | select(.port == ($gport|tonumber)) | .settings.decryption ) += "none" ' \
|sponge $XCONF

cat $XCONF |jq --arg gport "${gport}" --arg service "${service}" \
'( .inbounds[] | select(.port == ($gport|tonumber)) | .streamSettings ) += {"network":"grpc", "grpcSettings":{"serviceName":$service} } ' \
|sponge $XCONF

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

TPL="site-ssl-grpc.conf.tpl"

ESC_CERTFILE=$(printf '%s\n' "${fullchain}" | sed -e 's/[]\/$*.^[]/\\&/g')
ESC_PRVKEYFILE=$(printf '%s\n' "${prvkey}" | sed -e 's/[]\/$*.^[]/\\&/g')
ESC_GSVC=$(printf '%s\n' "${service}" | sed -e 's/[]\/$*.^[]/\\&/g')
cat ${TPL} \
    | sed "s/CERTFILE/${ESC_CERTFILE}/g" \
    | sed "s/PRVKEYFILE/${ESC_PRVKEYFILE}/g" \
    | sed "s/NGDOMAIN/${domain}/g" \
    | sed "s/NGPORT/${port}/g" \
    | sed "s/GPORT/${gport}/g" \
    | sed "s/GSVC/${ESC_GSVC}/g" \
    >site-xray.conf
