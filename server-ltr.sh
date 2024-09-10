#!/bin/bash

DIR=`dirname $0`

usage() {
    echo "VLESS-TCP-REALITY builder"
    echo "Usage: server-ltr <x=xray-config-file>,<c=cert-home-dir>,<p=listen-port>,[xtls],<d=dest.com>,[pub=xxx,prv=yyy],<u=id0>,<u=id1>..."
}

options=(`echo $1 |tr ',' ' '`)
for option in "${options[@]}"
do
    kv=(`echo $option |tr '=' ' '`)
    case "${kv[0]}" in
        c|certhome)
            certhome="${kv[1]}"
            ;;
        d|dest)
            dest="${kv[1]}"
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
        shortId)
            shortIds+=("${kv[1]}")
            ;;
        prv|privateKey)
            prvkey="${kv[1]}"
            ;;
        pub|publicKey)
            pubkey="${kv[1]}"
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

if [ -z "${dest}" ]; then
    echo "Error: dest undefined."
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

if [ -z "${prvkey}" ] || [ -z "${pubkey}" ] ; then
    echo "Warning: PublicKey / PrivateKey undefined, Generated new..."
    kv=(`/usr/local/bin/xray x25519|cut -d ' ' -f3|tr ' '`)
    prvkey="${kv[0]}"
    pubkey="${kv[1]}"
    echo "PublicKey: $pubkey"
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
    cat $XCONF | ${DIR}/adduser.sh -p $port -u ${xu} -c ltr.$dest $flowopt | sponge $XCONF
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

# Reality settings
cat $XCONF |jq --arg port "${port}" \
'( .inbounds[] | select(.port == ($port|tonumber)) | .streamSettings ) += {"security":"reality"} ' \
|sponge $XCONF

cat $XCONF |jq --arg port "${port}" --arg dest "${dest}" --arg pubkey "${pubkey}" --arg prvkey "${prvkey}" \
'( .inbounds[] | select(.port == ($port|tonumber)) | .streamSettings ) += {"realitySettings":{"show":true,"dest":"\($dest):443","serverNames":[$dest,""],"privateKey":$prvkey,"publicKey":$pubkey,"shortIds":[""]} } ' \
|sponge $XCONF

cat $XCONF |jq '( .inbounds[] | select(.port == ($port|tonumber)) | .streamSettings.realitySettings.shortIds ) +=$ARGS.positional' \
--arg port "${port}" --args ${shortIds[@]} \
|sponge $XCONF
