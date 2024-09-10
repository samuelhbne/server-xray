#!/bin/bash

DIR=`dirname $0`

usage() {
    echo "TROJAN-WS-PLAIN builder"
    echo "Usage: server-twp <x=xray-config-file>,<p=listen-port>,<w=wskpath>,<u=pw0>,<u=pw1>..."
}

options=(`echo $1 |tr ',' ' '`)
for option in "${options[@]}"
do
    kv=(`echo $option |tr '=' ' '`)
    case "${kv[0]}" in
        p|port)
            port="${kv[1]}"
            ;;
        u|user)
            xuser+=("${kv[1]}")
            ;;
        w|wpath)
            wspath="${kv[1]}"
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

if [ -z "${wspath}" ]; then
    echo "Error: wspath undefined."
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
cat $XCONF |jq --arg port "${port}" '.inbounds +=[{"port":($port|tonumber), "protocol":"trojan", "settings":{"clients":[]}}]' |sponge $XCONF
cat $XCONF |jq --arg port "${port}" '( .inbounds[] | select(.port == ($port|tonumber)) | .settings.decryption ) += "none" '  |sponge $XCONF

# User settings
for xu in "${xuser[@]}"
do
    cat $XCONF | ${DIR}/addusertj.sh -p $port -u ${xu} -c twp.$domain $flowopt | sponge $XCONF
done

# Network settings
cat $XCONF |jq --arg port "${port}" --arg wspath "${wspath}" \
'( .inbounds[] | select(.port == ($port|tonumber)) | .streamSettings ) += {"network":"ws","wsSettings":{"path":$wspath}} ' \
|sponge $XCONF

# Plain settings
cat $XCONF |jq --arg port "${port}" \
'( .inbounds[] | select(.port == ($port|tonumber)) | .streamSettings ) += {"security":"none" } ' \
|sponge $XCONF
