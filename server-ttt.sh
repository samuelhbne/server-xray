#!/bin/bash

DIR=`dirname $0`

usage() {
    echo "TROJAN-TCP-TLS builder"
    echo "Usage: server-ttt <x=xray-config-file>,<c=cert-home-dir>,<p=listen-port>,<d=domain.com>,<u=pw0>,<u=pw1>..."
}

options=(`echo $1 |tr ',' ' '`)
for option in "${options[@]}"
do
    kv=(`echo $option |tr '=' ' '`)
    case "${kv[0]}" in
    case "${kv[0]}" in
        c|certhome)
            certhome="${kv[1]}"
            ;;
        d|domain)
            domain="${kv[1]}"
            ;;
        f|fallback)
            fallback+=("${kv[1]}")
            ;;
        flow)
            flow="${kv[1]}"
            ;;
        p|port)
            port="${kv[1]}"
            ;;
        u|user)
            xuser+=("${kv[1]}")
            ;;
        x|xconf)
            xconf="${kv[1]}"
            ;;
        xtls)
            flow="xtls-rprx-vision"
            ;;
    esac
done

if [ -z "${certhome}" ]; then
    echo "Error: certhome undefined."
    usage
    exit 1
fi

if [ -z "${domain}" ]; then
    echo "Error: domain undefined."
    usage
    exit 1
fi

if [ -n "${flow}" ]; then
    flowopt="-f ${flow}"
fi

if [ -z "${port}" ]; then
    echo "Error: port undefined."
    usage
    exit 1 ;
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

if [ -f "${certhome}/${domain}/fullchain.cer" ] && [ -f "${certhome}/${domain}/${domain}.key" ]; then
    fullchain="${certhome}/${domain}/fullchain.cer"
    prvkey="${certhome}/${domain}/${domain}.key"
fi

if [ ! -f "${fullchain}" ] || [ ! -f "${prvkey}" ]; then
    echo "TLS cert missing?"
    echo "Abort."
    exit 2
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
    cat $XCONF | ${DIR}/addusertj.sh -p $port -u ${xu} -c ttt.$dest $flowopt | sponge $XCONF
done

# Fallback settings
for fb in "${fallback[@]}"
do
    cat $XCONF |${DIR}/fallback.sh -p $port -f ${fb} | sponge $XCONF
done

# Network settings
cat $XCONF |jq --arg port "${port}" \
'( .inbounds[] | select(.port == ($port|tonumber)) | .streamSettings ) += {"network":"tcp"} ' \
|sponge $XCONF

# TLS settings
cat $XCONF |jq --arg port "${port}" \
'( .inbounds[] | select(.port == ($port|tonumber)) | .streamSettings ) += {"security":"tls"} ' \
|sponge $XCONF

cat $XCONF |jq --arg port "${port}" \
'( .inbounds[] | select(.port == ($port|tonumber)) | .streamSettings ) += {"tlsSettings":{}} ' \
|sponge $XCONF

cat $XCONF |jq --arg port "${port}" --arg fullchain "${fullchain}" --arg prvkey "${prvkey}" \
'( .inbounds[] | select(.port == ($port|tonumber)) | .streamSettings.tlsSettings ) += {"certificates":[{"certificateFile":$fullchain, "keyFile":$prvkey}]} ' \
|sponge $XCONF
