#!/bin/bash

DIR=`dirname $0`

usage() {
    echo "VLESS-GRPC-PLAIN builder"
    echo "Usage: server-lgp <x=xray-config-file>,<p=listen-port>,<s=svcname>,<u=id0>,<u=id1>..."
}

options=(`echo $1 |tr ',' ' '`)
for option in "${options[@]}"
do
    kv=(`echo $option |tr '=' ' '`)
    case "${kv[0]}" in
        p|port)
            port="${kv[1]}"
            ;;
        s|service)
            service="${kv[1]}"
            ;;
        u|user)
            xuser+=("${kv[1]}")
            ;;
        x|xconf)
            xconf="${kv[1]}"
            ;;
    esac
done

if [ -z "${port}" ]; then
    echo "Error: port undefined."
    usage
    exit 1 ;
fi

if [ -z "${service}" ]; then
    echo "Error: service undefined."
    usage
    exit 1
fi

if [ -z "${xuser}" ]; then
    echo "Error: user undefined."
    usage
    exit 1
fi

if [ -z "${xconf}" ]; then
    echo "Error: xconf undefined."
    usage
    exit 1
fi

if ! [ "${port}" -eq "${port}" ] 2>/dev/null; then >&2 echo "Port number must be numeric"; exit 1; fi

XCONF=$xconf
# Remove existing port number if existing.
cat $XCONF |jq --arg port "${port}" 'del( .inbounds[] | select(.port == ($port|tonumber)) )' |sponge $XCONF

# Add inbound element
cat $XCONF |jq --arg port "${port}" '.inbounds +=[{"port":($port|tonumber), "protocol":"vless", "settings":{"clients":[]}}]' |sponge $XCONF
cat $XCONF |jq --arg port "${port}" '( .inbounds[] | select(.port == ($port|tonumber)) | .settings.decryption ) += "none" '  |sponge $XCONF

# User settings
for xu in "${xuser[@]}"
do
    cat $XCONF | ${DIR}/adduser.sh -p $port -u ${xu} -c lgp.$domain $flowopt | sponge $XCONF
done

# Network settings
cat $XCONF |jq --arg port "${port}" --arg service "${service}" \
'( .inbounds[] | select(.port == ($port|tonumber)) | .streamSettings ) += {"network":"grpc","grpcSettings":{"serviceName":$service} } ' \
|sponge $XCONF

# Plain settings
cat $XCONF |jq --arg port "${port}" \
'( .inbounds[] | select(.port == ($port|tonumber)) | .streamSettings ) += {"security":"none" } ' \
|sponge $XCONF
