#!/bin/bash

usage() {
    echo "Usage: server-msw <x=xray-config-file>,<c=cert-home-dir>,<p=listen-port>,<d=mydomain.com>,<u=xxx-xxx[:0[:a@mail.com]]>,<w=websocket-path>"
}

options=(`echo $1 |tr ',' ' '`)
for option in "${options[@]}"
do
    kv=(`echo $option |tr '=' ' '`)
    case "${kv[0]}" in
        x|xconf)
            xconf="${kv[1]}"
            ;;
        c|certhome)
            certhome="${kv[1]}"
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
        w|wpath)
            wspath="${kv[1]}"
            ;;
        f|fallback)
            fallback+=("${kv[1]}")
            ;;
    esac
done

if [ -z "${certhome}" ]; then
    echo "Error: certhome undefined."
    usage
    exit 1
fi

if [ -z "${xconf}" ]; then
    echo "Error: xconf undefined."
    usage
    exit 1
fi

if [ -z "${port}" ]; then
    port=443
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

if [ -z "${wspath}" ]; then
    echo "Error: wspath undefined."
    usage
    exit 1
fi

if ! [ "${port}" -eq "${port}" ] 2>/dev/null; then >&2 echo "Port number must be numeric"; exit 1; fi

XCONF=$xconf
# Remove existing port number if existing.
cat $XCONF |jq --arg port "${port}" 'del( .inbounds[] | select(.port == ($port|tonumber)) )' |sponge $XCONF
cat $XCONF |jq --arg port "${port}" '.inbounds +=[{"port":($port|tonumber), "protocol":"vmess", "settings":{"clients":[]}}]' |sponge $XCONF

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

for fb in "${fallback[@]}"
do
    IFS=':'
    fopt=(${fb})
    fopt=(${fopt[@]})

    fhost="${fopt[0]}"
    fport="${fopt[1]}"
    fpath="${fopt[2]}"

    if [ -z "${fport}" ]; then
        echo "Incorrect fallback format: ${fb}"
        echo "Correct fallback: fallback=[host]<:port>[:path]"
        echo "Like: fallback=baidu.com:443:/websocket"
        echo "Like: fallback=:1443:/websocket"
        echo "Like: fallback=:1443"
        exit 1
    fi

    if [ -z "${fhost}" ]; then
        if [ -z "${fpath}" ]; then
            Jfallback=`echo '{}' |jq --arg fport "${fport}" --arg fpath "${fpath}" '. += {"dest":($fport|tonumber), "xver":1}'`
        else
            Jfallback=`echo '{}' |jq --arg fport "${fport}" --arg fpath "${fpath}" '. += {"dest":($fport|tonumber), "path":$fpath, "xver":1}'`
        fi
    else
        if [ -z "${fpath}" ]; then
            fdest="${fhost}:${fport}"
            Jfallback=`echo '{}' |jq --arg fdest "${fdest}" --arg fpath "${fpath}" '. += {"dest":$fdest, "xver":1}'`
        else
            Jfallback=`echo '{}' |jq --arg fdest "${fdest}" --arg fpath "${fpath}" '. += {"dest":$fdest, "path":$fpath, "xver":1}'`
        fi
    fi

    cat $XCONF |jq --arg port "${port}" --argjson jfallback "$Jfallback" \
    '( .inbounds[] | select(.port == ($port|tonumber)) | .settings.fallbacks ) += [ $jfallback ] ' \
    |sponge $XCONF
done

cat $XCONF |jq --arg port "${port}" \
'( .inbounds[] | select(.port == ($port|tonumber)) | .streamSettings ) += {"network":"ws", "security":"tls" } ' \
|sponge $XCONF

cat $XCONF |jq --arg port "${port}" \
'( .inbounds[] | select(.port == ($port|tonumber)) | .streamSettings ) += {"tlsSettings":{"alpn":["http/1.1"]} } ' \
|sponge $XCONF

cat $XCONF |jq --arg port "${port}" --arg wspath "${wspath}" \
'( .inbounds[] | select(.port == ($port|tonumber)) | .streamSettings ) += {"wsSettings":{"path":$wspath}} ' \
|sponge $XCONF

if [ -f "${certhome}/${domain}/fullchain.cer" ] && [ -f "${certhome}/${domain}/${domain}.key" ]; then
    fullchain="${certhome}/${domain}/fullchain.cer"
    prvkey="${certhome}/${domain}/${domain}.key"
fi

if [ ! -f "${fullchain}" ] || [ ! -f "${prvkey}" ]; then
    echo "TLS cert missing?"
    echo "Abort."
    exit 2
fi

cat $XCONF |jq --arg port "${port}" --arg fullchain "${fullchain}" --arg prvkey "${prvkey}" \
'( .inbounds[] | select(.port == ($port|tonumber)) | .streamSettings.tlsSettings ) += {"certificates":[{"certificateFile":$fullchain, "keyFile":$prvkey}]} ' \
|sponge $XCONF
