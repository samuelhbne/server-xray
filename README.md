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
    --ltx  <VLESS-TCP-XTLS option>     p=443,d=mydomain.com,u=uuid[:level[:email]][,f=[fallback-host]:fb-port:[fb-path]]
    --ltt  <VLESS-TCP-TLS option>      p=443,d=mydomain.com,u=uuid[:level[:email]][,f=[fallback-host]:fb-port:[fb-path]]
    --lttw <VLESS-TCP-TLS-WS option>   p=443,d=mydomain.com,u=uuid[:level[:email]][,f=[fallback-host]:fb-port:[fb-path]],w=/webpath
    --lttg <VLESS-TCP-TLS-GRPC option> p=443,d=mydomain.com,u=uuid[:level[:email]],s=/svcpath,g=grpcport
    --mtt  <VMESS-TCP-TLS option>      p=443,d=mydomain.com,u=uuid[:level[:email]][,f=[fallback-host]:fb-port:[fb-path]]
    --mttw <VMESS-TCP-TLS-WS option>   p=443,d=mydomain.com,u=uuid[:level[:email]][,f=[fallback-host]:fb-port:[fb-path]],w=/webpath
    --ttt  <TROJAN-TCP-TLS option>     p=443,d=mydomain.com,u=passwd[:email][,f=[fallback-host]:fb-port:[fb-path]]
    --tttw <TROJAN-TCP-TLS-WS option>  p=443,d=mydomain.com,u=passwd[:email][,f=[fallback-host]:fb-port:[fb-path]],w=/webpath
    --stdin                            Read XRay config from stdin instead of auto generation

$ docker run --name server-xray -p 80:80 -p 8443:443 -d samuelhbne/server-xray:amd64 --ltx p=443,d=mydomain.duckdns.org,u=bec24d96-410f-4723-8b3b-46987a1d9ed8,f=:8080 -r mydomain.duckdns.org
...
```

### NOTE2

- Please replace "amd64" with the arch that match your server. For example: "arm64" for ARM64v8 platform like AWS t4g instance or 64bit Ubuntu on Raspberry Pi. "arm" for 32bit Raspbian.
- Please replace the container port 8443 export (-p 8443:443) with the TCP port number you want to listen for Xray service.
- The container port 80 export (-p 80:80) is necessary for Letsencrypt cert requesting, so don't remove it.
- Please replace "bec24d96-410f-4723-8b3b-46987a1d9ed8" with the uuid you want to set for Xray client auth.
- Please replace mydomain.duckdns.org with the domain-name for Letsencrypt cert request.
- You can optionally assign a HOOK-URL to update the DDNS domain-name pointing to the current server public IP address.

## Examples

### 1. Running a XTLS server with DDNS auto-update and Letsencrypt cert auto-request

The following command will:

1. Update mydomain.duckdns.org to the current IP address
2. Request TLS cert from Letsencrypt
3. Run Xray in Vless+TLS+Websocket mode on port 1443 with the cert given above
4. Fallback the connection to local port 8080 if client handshake failed

```shell
$ docker run --name server-xray -p 80:80 -p 443:1443 -d samuelhbne/server-xray:amd64 \
--lttx p=1443,d=mydomain.duckdns.org,u=bec24d96-410f-4723-8b3b-46987a1d9ed8,f=:8080 \
-k https://duckdns.org/update/mydomain/c9711c65-db21-4f8c-a790-2c32c93bde8c \
-r mydomain.duckdns.org
...
```

#### Note1

The service port 1443 was exported as 443 for client accesss from internet

#### Note2

Port 80 must be exported for domain ownership verification during Letsencrypt cert requesting

### 2. Running a Vless+TLS+Websocket server with given TLS cert

The following command will:

1. Assume to read TLS cert from /home/ubuntu/cert/mydomain.duckdns.org/fullchain.cer
2. Assume to read private key from  /home/ubuntu/cert/mydomain.duckdns.org/mydomain.duckdns.org.key
3. Assume mydomain.duckdns.org has been resolved to the current server
4. Run Xray in Vless+TLS+Websocket mode on port 2443 with the given cert
5. Fallback to microsoft.com if client handshake failed (Anti-detection)

```shell
$ docker run --name server-xray -p 443:2443 -v /home/ubuntu/cert:/opt/cert -d samuelhbne/server-xray:amd64 \
--lttw p=2443,d=mydomain.duckdns.org,u=bec24d96-410f-4723-8b3b-46987a1d9ed8,w=/websocket,f=microsoft.com:80 \
-c /opt/cert
...
```

### 3. Running a Vless+TLS+gRPC server with Nginx in front of, with given TLS cert

The following command will:

1. Assume to read TLS cert from /home/ubuntu/cert/mydomain.duckdns.org/fullchain.cer
2. Assume to read private key from  /home/ubuntu/cert/mydomain.duckdns.org/mydomain.duckdns.org.key
3. Assume mydomain.duckdns.org has been resolved to the current server
4. Run Xray in Vless+TLS+gRPC mode on port 65443 with the given cert
5. Run nginx on port 443 as a front to protect gRPC backend from detection
6. Only port 443 will be available for access from internet

```shell
$ docker run --name server-xray -p 443:443 -v /home/ubuntu/cert:/opt/cert -d samuelhbne/server-xray:amd64 \
-c /opt/cert --lttg port=443,domain=mydomain.duckdns.org,user=bec24d96-410f-4723-8b3b-46987a1d9ed8,service=/gsvc,gport=65443
...
```

## How to verify if server-xray is running properly

Try to connect the server from Xray compatible mobile app like [v2rayNG](https://github.com/2dust/v2rayNG) for Android or [Shadowrocket](https://apps.apple.com/us/app/shadowrocket/id932747118) for iOS with the host-name, port, UUID etc. set above. Or verify it from Ubuntu / Debian / Raspbian client host follow the instructions below.

### Verifying server-xray connection with proxy-xray

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

- First we ran proxy-xray which created a SOCKS5 proxy that tunneling traffic through your Xray server.
- Then a curl qery was sent to ifconfig.co through the Xray server via the socks5 port served by proxy-xray.
- Like this: curl --> proxy-xray --> server-xray --> ifconfig.co website.
- You should get the public IP address of your Xray server if all go well.
- Please have a look over the sibling project [proxy-xray](https://github.com/samuelhbne/proxy-xray) for more details.

## How to stop and remove the running container

```shell
$ docker stop server-xray
...
$ docker rm server-xray
...
```
