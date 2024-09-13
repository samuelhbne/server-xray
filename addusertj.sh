#!/bin/bash

usage() {
    echo "Usage: adduser -p <port-num> -u <user> -c <email-comment> -f <flow-type>" >&2
}

TEMP=`getopt -o c:f:p:u: --long comment:flow:port:,user: -n "$0" -- $@`
if [ $? != 0 ] ; then usage; exit 1 ; fi

eval set -- "$TEMP"
while true ; do
    case "$1" in
        -c|--comment)
            comment="$2"
            shift 2
            ;;
        -f|flow)
            flow="$2"
            shift 2
            ;;
        -p|--port)
            port="$2"
            shift 2
            ;;
        -u|--user)
            user="$2"
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

IFS=':'
uopt=(${user})
uopt=(${uopt[@]})

psw="${uopt[0]}"
level="${uopt[1]}"
email="${uopt[2]}"

if [ -z "${psw}" ]; then
    echo "Error: Undefined UID \"$user\"" >&2
    echo "Correct user format: user=<password>[:level:email]" >&2
    echo "Like: user=mypw:0:me@g.cn" >&2
    echo "Like: user=mypw::me@g.cn" >&2
    echo "Like: user=mypw:0" >&2
    echo "Like: user=mypw" >&2
    exit 1
fi

if [ -z "${level}" ]; then
    level=0
fi

if [ -z "${email}" ]; then
    email="${psw}@${comment}"
fi

jq --arg port "${port}" --arg psw "${psw}" --arg level "${level}" --arg email "${email}" --arg flow "${flow}" \
'( .inbounds[] | select(.port == ($port|tonumber)) | .settings.clients ) += [ {"password":$psw, "flow":$flow, "level":($level|tonumber), "email":$email} ] ' \
