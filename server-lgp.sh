#!/bin/bash

usage() {
    >&2 echo -e "VLESS-GRPC-PLAIN server builder"
    >&2 echo -e "Usage: server-lgp <s=svcname>,<d=domain.com>,<p=listen-port>,<u=id0>,<u=id1>...,[proxy_acpt],[fallback=host:port:path]"
    >&2 echo -e "Fallback format: fallback=[host]<:port>[:/path] Like: 'baidu.com:443:/path', ':1443:/path', ':1443'"
    >&2 echo -e "User format: user|u=<uid>[:level:email]"
}

IFS=',' read -ra options <<< "$1"
for option in "${options[@]}"
do
    IFS='=' read -ra kv <<< "$option"
    case "${kv[0]}" in
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
        proxy_acpt)
            acceptProxyProtocol=true
            ;;
        s|serviceName)
            serviceName="${kv[1]}"
            ;;
        u|user)
            xuser+=("${kv[1]}")
            ;;
    esac
done
unset IFS

if [ -z "${domain}" ]; then
    >&2 echo -e "Error: Domain undefined.\n"
    usage; exit 1
fi

if [ -z "${port}" ]; then
    >&2 echo -e "Error: Port undefined.\n"
    usage; exit 1 ;
fi

if [ -z "${serviceName}" ]; then
    >&2 echo -e "Error: serviceName undefined.\n"
    usage; exit 1
fi

if [ "${#xuser[@]}" -eq 0 ]; then
    >&2 echo -e "Error: User undefined.\n"
    usage; exit 1
fi

if ! [ "${port}" -eq "${port}" ] 2>/dev/null; then >&2 echo -e "Error: Port number must be numeric.\n"; exit 1; fi

# inbound frame
inbound=$(jq -nc --arg port "${port}" '{"port":($port|tonumber),"protocol":"vless","settings":{"decryption":"none"}}')

# User settings
for user in "${xuser[@]}"
do
    IFS=':'; uopt=("${user}"); uopt=("${uopt[@]}")
    uid="${uopt[0]}"; level="${uopt[1]}"; email="${uopt[2]}"
    unset IFS
    if [ -z "${uid}" ]; then >&2 echo -e "Incorrect user format: $user\n"; usage; exit 1; fi
    if [ -z "${level}" ]; then level=0; fi
    if [ -z "${email}" ]; then email="${uid}@lgp.$domain"; fi
    inbound=$(echo $inbound| jq -c --arg uid "${uid}" --arg flow "${flow}" --arg level "${level}" --arg email "${email}" \
    '.settings.clients += [{"id":$uid,"level":($level|tonumber),"email":$email,"flow":$flow}]')
done

# StreamSettings
if [ -n "${acceptProxyProtocol}" ]; then
    inbound=$(echo $inbound| jq -c '.streamSettings.sockopt += {"acceptProxyProtocol":true}')
fi

# Network settings
inbound=$(echo $inbound| jq -c --arg serviceName "${serviceName}" '.streamSettings += {"network":"grpc","grpcSettings":{"serviceName":$serviceName}}')

# Security settings
inbound=$(echo $inbound| jq -c '.streamSettings += {"security":"none"}')

# Fallback settings
for fb in "${fallback[@]}"
do
    IFS=':'; fopt=("${fb}"); fopt=("${fopt[@]}")
    fhost="${fopt[0]}"; fport="${fopt[1]}"; fpath="${fopt[2]}"
    unset IFS
    if [ -z "${fport}" ]; then >&2 echo -e "Incorrect fallback format: $fb\n"; usage; exit 1; fi
    if [ -z "${fhost}" ]; then fhost="127.0.0.1"; fi
    fdest="$fhost:$fport"
    Jfb=$(jq -nc --arg fdest "${fdest}" --arg fpath "${fpath}" '. |= {"dest":$fdest,"path":$fpath,"xver":1}')
    inbound=$(echo $inbound| jq -c --argjson Jfb "${Jfb}" '.settings.fallbacks += [$Jfb]')
done

echo "$inbound"
exit 0
