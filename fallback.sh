#!/bin/bash

usage() {
    echo "Usage: fallback -p <port-num> -f <fallback-dest>" >&2
}

TEMP=`getopt -o f:p: --long port:,fallback: -n "$0" -- $@`
if [ $? != 0 ] ; then usage; exit 1 ; fi

eval set -- "$TEMP"
while true ; do
    case "$1" in
        -p|--port)
            port="$2"
            shift 2
            ;;
        -f|--fallback)
            fallback="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage;
            exit 1
            ;;
    esac
done

if [ -z "${port}" ]; then
    echo "Error: port undefined." >&2
    usage
    exit 1 ;
fi

if [ -z "${fallback}" ]; then
    echo "Error: fallback undefined." >&2
    usage
    exit 1 ;
fi

IFS=':'
fopt=(${fallback})
fopt=(${fopt[@]})

fhost="${fopt[0]}"
fport="${fopt[1]}"
fpath="${fopt[2]}"
fdest=$fhost:$fport

if [ -z "${fport}" ]; then
    echo "Incorrect fallback format: ${fallback}"
    echo "Correct fallback: fallback=[host]<:port>[:path]"
    echo "Like: fallback=baidu.com:443:/path"
    echo "Like: fallback=:1443:/path"
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

jq --arg port "${port}" --argjson jfallback "$Jfallback" \
'( .inbounds[] | select(.port == ($port|tonumber)) | .settings.fallbacks ) += [ $jfallback ] ' \
