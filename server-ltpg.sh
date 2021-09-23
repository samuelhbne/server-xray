#!/bin/bash

usage() {
    echo "Usage: server-lttg <xconf=xray-config-file>,<port=443>,<user=xxx-xxx[:0[:a@mail.com]]>,<service=svcname>"
}

options=(`echo $1 |tr ',' ' '`)
for option in "${options[@]}"
do
    kv=(`echo $option |tr '=' ' '`)
    case "${kv[0]}" in
        x|xconf)
            xconf="${kv[1]}"
            ;;
        p|port)
            port="${kv[1]}"
            ;;
        u|user)
            xuser+=("${kv[1]}")
            ;;
        s|service)
            service="${kv[1]}"
            ;;
    esac
done

if [ -z "${xconf}" ]; then
    echo "Error: xconf undefined."
    usage
    exit 1
fi

if [ -z "${port}" ]; then
    port=443
fi

if [ -z "${xuser}" ]; then
    echo "Error: user undefined."
    usage
    exit 1
fi

if ! [ "${port}" -eq "${port}" ] 2>/dev/null; then >&2 echo "Port number must be numeric"; exit 1; fi

XCONF=$xconf
# Remove existing port number if existing.
cat $XCONF |jq --arg port "${port}" 'del( .inbounds[] | select(.port == ($port|tonumber)) )' |sponge $XCONF
cat $XCONF |jq --arg port "${port}" '.inbounds +=[{"port":($port|tonumber), "protocol":"vless", "settings":{"clients":[]}}]' |sponge $XCONF

for xu in "${xuser[@]}"
do
    IFS=':'
    uopt=(${xu})
    uopt=(${uopt[@]})

    if [ -z "${uopt[0]}" ]; then
        echo "Incorrect user format: ${xu}"
        echo "Correct user format: user=<uid>[:level:email]"
        echo "Like: user=myid:0:me@g.cn"
        echo "Like: user=myid::me@g.cn"
        echo "Like: user=myid:0"
        echo "Like: user=myid"
        exit 1
    fi
    if [ -z "${uopt[1]}" ]; then
        uopt[1]=0
    fi
    cat $XCONF |jq --arg port "${port}" --arg uid "${uopt[0]}" --arg level "${uopt[1]}" --arg email "${uopt[2]}" \
    '( .inbounds[] | select(.port == ($port|tonumber)) | .settings.clients ) += [ {"id":$uid, "level":($level|tonumber), "email":$email} ] ' \
    |sponge $XCONF
done

cat $XCONF |jq --arg port "${port}" \
'( .inbounds[] | select(.port == ($port|tonumber)) | .settings.decryption ) += "none" ' \
|sponge $XCONF

cat $XCONF |jq --arg port "${port}" --arg service "${service}" \
'( .inbounds[] | select(.port == ($port|tonumber)) | .streamSettings ) += {"network":"grpc", "grpcSettings":{"serviceName":$service}, "security":"none"} ' \
|sponge $XCONF
