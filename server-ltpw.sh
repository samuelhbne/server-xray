#!/bin/bash

usage() {
    echo "Usage: server-ltpw <xconf=xray-config-file>,<port=443>,<user=myid[:0[:a@mail.com]]>,<path=websocket-path>[,fallback=www.baidu.com:443:/html][,fallback=:2443:/websocket2]"
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
        w|wpath)
            wspath="${kv[1]}"
            ;;
        f|fallback)
            fallback+=("${kv[1]}")
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

if [ -z "${wspath}" ]; then
    echo "Error: wspath undefined."
    usage
    exit 1
fi

if ! [ "${port}" -eq "${port}" ] 2>/dev/null; then >&2 echo "Port number must be numeric"; exit 1; fi

XCONF=$xconf
cat $XCONF |jq --arg port "${port}" '.inbounds +=[{"port":($port|tonumber), "protocol":"vless", "settings":{"clients":[]}}]' |sponge $XCONF

for xu in "${xuser[@]}"
do
    IFS=':'
    uopt=(${xu})
    uopt=(${uopt[@]})

    if [ -z "${uopt[0]}" ]; then
        echo "Incorrect user format: ${xu}"
        echo "Correct user format: user=<uid>[:level:email]"
        echo "Like: user=myid:0:nobody@g.cn"
        echo "Like: user=myid::nobody@g.cn"
        echo "Like: user=myid:0"
        echo "Like: user=myid"
        exit 1
    fi
    if [ -z "${uopt[1]}" ]; then
        uopt[1]=0
    fi
    if [ -z "${uopt[2]}" ]; then
        uopt[2]="nobody@g.cn"
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
'( .inbounds[] | select(.port == ($port|tonumber)) | .streamSettings ) += {"network":"ws", "security":"none" } ' \
|sponge $XCONF

cat $XCONF |jq --arg port "${port}" --arg wspath "${wspath}" \
'( .inbounds[] | select(.port == ($port|tonumber)) | .streamSettings ) += {"wsSettings":{"path":$wspath}} ' \
|sponge $XCONF
