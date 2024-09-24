#!/bin/bash

DIR=`dirname $0`

usage() {
    >&2 echo "TROJAN-WS-PLAIN server builder"
    >&2 echo "Usage: server-twp <w=wskpath>,<d=domain.com>,<p=listen-port>,<u=id0>,<u=id1>...,[proxy_acpt],[fallback=host:port:path]"
    >&2 echo "Fallback format: fallback=[host]<:port>[:/path] Like: 'baidu.com:443:/path', ':1443:/path', ':1443'"
    >&2 echo "User format: user=<uid>[:level:email]"
}

options=(`echo $1 |tr ',' ' '`)
for option in "${options[@]}"
do
    kv=(`echo $option |tr '=' ' '`)
    case "${kv[0]}" in
        d|domain)
            domain="${kv[1]}"
            ;;
        f|fallback)
            fallback+=("${kv[1]}")
            ;;
        p|port)
            port="${kv[1]}"
            ;;
        proxy_acpt)
            acceptProxyProtocol=true
            ;;
        u|user)
            xuser+=("${kv[1]}")
            ;;
        w|wpath)
            wspath="${kv[1]}"
            ;;
    esac
done

if [ -z "${domain}" ]; then
    >&2 echo "Error: Domain undefined."
    usage; exit 1
fi

if [ -z "${port}" ]; then
    >&2 echo "Error: Port undefined."
    usage; exit 1 ;
fi

if [ -z "${wspath}" ]; then
    >&2 echo "Error: wspath undefined."
    usage; exit 1
fi

if [ -z "${xuser}" ]; then
    >&2 echo "Error: User undefined."
    usage; exit 1
fi

if ! [ "${port}" -eq "${port}" ] 2>/dev/null; then >&2 echo "Port number must be numeric"; exit 1; fi

# inbound frame
inbound=`jq -nc --arg port "${port}" '{"port":$port,"protocol":"trojan","settings":{"decryption":"none"}}'`

# User settings
for user in "${xuser[@]}"
do
    IFS=':'; uopt=(${user}); uopt=(${uopt[@]})
    uid="${uopt[0]}"; level="${uopt[1]}"; email="${uopt[2]}"
    unset IFS
    if [ -z "${uid}" ]; then >&2 echo "Incorrect user format: $user"; usage; exit 1; fi
    if [ -z "${level}" ]; then level=0; fi
    if [ -z "${email}" ]; then email="${uid}@twp.$domain"; fi
    inbound=`echo $inbound| jq -c --arg uid "${uid}" --arg flow "${flow}" --arg level "${level}" --arg email "${email}" \
    '.settings.clients += [{"password":$uid,"level":($level|tonumber),"email":$email,"flow":$flow}]'`
done

# StreamSettings
if [ -n "${acceptProxyProtocol}" ]; then
    inbound=`echo $inbound| jq -c '.settings.streamSettings.sockopt += {"acceptProxyProtocol":true}'`
fi

# Network settings
inbound=`echo $inbound| jq -c --arg wspath "${wspath}" '.settings.streamSettings += {"network":"ws","wsSettings":{"path":$wspath}}'`

# Security settings
inbound=`echo $inbound| jq -c '.settings.streamSettings += {"security":"none"}'`

# Fallback settings
for fb in "${fallback[@]}"
do
    IFS=':'; fopt=(${fb}); fopt=(${fopt[@]})
    fhost="${fopt[0]}"; fport="${fopt[1]}"; fpath="${fopt[2]}"
    unset IFS
    if [ -z "${fport}" ]; then
        >&2 echo "Incorrect fallback format: ${fallback}"
        usage; exit 1
    fi
    if [ -z "${fhost}" ]; then fhost="127.0.0.1"; fi
    fdest="$fhost:$fport"
    Jfb=`jq -nc --arg fdest "${fdest}" --arg fpath "${fpath}" '. |= {"dest":$fdest,"path":$fpath,"xver":1}'`
    inbound=`echo $inbound| jq -c --argjson Jfb "${Jfb}" '.settings.fallbacks += [$Jfb]'`
done

echo $inbound
exit 0






}

options=(`echo $1 |tr ',' ' '`)
for option in "${options[@]}"
do
    kv=(`echo $option |tr '=' ' '`)
    case "${kv[0]}" in
        d|domain)
            domain="${kv[1]}"
            ;;
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
cat $XCONF |jq --arg port "${port}" '.inbounds +=[{"port":($port|tonumber),"protocol":"trojan","settings":{"clients":[]}}]' |sponge $XCONF
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
