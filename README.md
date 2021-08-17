# server-xray

Yet another unofficial [xray](https://github.com/XTLS/Xray-core) server container with x86 and arm/arm64 (Raspberry Pi) support.

![docker-build](https://github.com/samuelhbne/server-xray/workflows/docker-buildx-latest/badge.svg)

## [Optional] How to build server-xray docker image

```shell
$ git clone https://github.com/samuelhbne/server-xray.git
$ cd server-xray
$ docker build -t samuelhbne/server-xray:amd64 -f Dockerfile.amd64 .
...
```

### NOTE1

- Please replace "amd64" with the arch match the current box accordingly. For example: "arm64" for AWS ARM64 platform like A1, t4g instance or 64bit Ubuntu on Raspberry Pi. "arm" for 32bit Raspbian.

## How to start the container

```shell
$ docker run --rm -it samuelhbne/server-xray:amd64
server-xray --<ltx|ltt|lttw|mtt|mttw|ttt> <options> [-r|--request-domain <domain-name>] [-c|--cert-path <cert-path-root>] [-k|--hook <hook-url>]
    -k|--hook <hook-url>               [Optional] DDNS update or notifing URL to be hit. Multiple allowed
    -r|--request-domain <domain-name>  [Optional] Domain name to request for letsencrypt cert. Multiple allowed
    -c|--cert-path <cert-path-root>    [Optional] Reading TLS certs from folder <cert-path-root>/<domain-name>/. Multiple allowed
    --ltx  <VLESS-TCP-XTLS option>     p=443,d=domain0.com,u=uuid[:level[:email]][,f=[fallback-host]:fb-port:[fb-path]]
    --ltt  <VLESS-TCP-TLS option>      p=1443,d=domain1.com,u=uuid[:level[:email]][,f=[fallback-host]:fb-port:[fb-path]]
    --lttw <VLESS-TCP-TLS-WS option>   p=2443,d=domain2.com,u=uuid[:level[:email]][,f=[fallback-host]:fb-port:[fb-path]],w=/webpath
    --lttg <VLESS-TCP-TLS-GRPC option> p=3443,d=domain0.com,u=uuid[:level[:email]],s=svcname,g=grpcport
    --mtt  <VMESS-TCP-TLS option>      p=4443,d=domain3.com,u=uuid[:level[:email]][,f=[fallback-host]:fb-port:[fb-path]]
    --mttw <VMESS-TCP-TLS-WS option>   p=5443,d=domain4.com,u=uuid[:level[:email]][,f=[fallback-host]:fb-port:[fb-path]],w=/webpath
    --ttt  <TROJAN-TCP-TLS option>     p=6443,d=domain5.com,u=passwd[:email][,f=[fallback-host]:fb-port:[fb-path]]
    --tttw <TROJAN-TCP-TLS-WS option>  p=7443,d=domain5.com,u=passwd[:email][,f=[fallback-host]:fb-port:[fb-path]],w=/webpath
    --stdin                            Read XRay config from stdin instead of auto generation

$ docker run --name server-xray -p 80:80 -p 8443:443 -d samuelhbne/server-xray:amd64 --ltx p=443,d=mydomain.duckdns.org,u=bec24d96-410f-4723-8b3b-46987a1d9ed8,f=:80 -k https://duckdns.org/update/mydomain/c9711c65-db21-4f8c-a790-2c32c93bde8c -r mydomain.duckdns.org
...
```

### NOTE2

- Please replace "amd64" with the arch that match your server. For example: "arm64" for ARM64v8 platform like AWS t4g instance or 64bit Ubuntu on Raspberry Pi. "arm" for 32bit Raspbian.
- Please replace the container port 8443 export (-p 8443:443) with the TCP port number you want to listen for Xray service.
- The container port 80 export (-p 80:80) is necessary for Letsencrypt cert requesting, so don't remove it.
- Please replace "bec24d96-410f-4723-8b3b-46987a1d9ed8" with the uuid you want to set for Xray client auth.
- Please replace mydomain.duckdns.org with the domain-name for Letsencrypt cert request.
- You can optionally assign a HOOK-URL to update the DDNS domain-name pointing to the current server public IP address.

## How to verify if server-xray is running properly

Try to connect the server from Xray compatible mobile app like [v2rayNG](https://github.com/2dust/v2rayNG) for Android or [Shadowrocket](https://apps.apple.com/us/app/shadowrocket/id932747118) for iOS with the host-name, port, UUID etc. set above. Or verify it from Ubuntu / Debian / Raspbian client host follow the instructions below.

### Please run the following instructions from Ubuntu / Debian / Raspbian client host for verifying

```shell
$ docker run --rm -it samuelhbne/proxy-xray:amd64
proxy-xray --<ltx|ltt|lttw|mtt|mttw|ttt|tttw|ssa|sst|stdin> [options]
    --ltx  <VLESS-TCP-XTLS option>        uuid@xray-host:port
    --ltt  <VLESS-TCP-TLS option>         uuid@xray-host:port
    --lttw <VLESS-TCP-TLS-WS option>      uuid@xray-host:port:/webpath
    --lttg <VLESS-TCP-TLS-GRPC option>    uuid@xray-host:port:/svcpath
    --mtt  <VMESS-TCP-TLS option>         uuid@xray-host:port
    --mttw <VMESS-TCP-TLS-WS option>      uuid@xray-host:port:/webpath
    --ttt  <TROJAN-TCP-TLS option>        password@xray-host:port
    --tttw <TROJAN-TCP-TLS-WS option>     password@xray-host:port:/webpath
    --stdin                               Read XRay config from stdin instead of auto generation

$ docker run --name proxy-xray -p 1080:1080 -p 65353:53/udp -p 8123:8123 -d samuelhbne/proxy-xray:amd64 --ltx bec24d96-410f-4723-8b3b-46987a1d9ed8@nvda.duckdns.org:8443
...

$ curl -sSx socks5h://127.0.0.1:1080 http://ifconfig.co
12.34.56.78
```

### NOTE4

- First we ran proxy-xray as SOCKS5 proxy that tunneling traffic through your Xray server.
- Then launching curl with client-IP address query through the proxy.
- This query was sent through your server with server-xray running.
- You should get the public IP address of your server with server-xray running if all good.
- Please have a look over the sibling project [proxy-xray](https://github.com/samuelhbne/proxy-xray) for more details.

## How to stop and remove the running container

```shell
$ docker stop server-xray
...
$ docker rm server-xray
...
```
