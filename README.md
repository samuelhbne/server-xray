# server-xray

Yet another unofficial [xray](https://github.com/XTLS/Xray-core) server container with x86 and arm/arm64 (Raspberry Pi) support.

![docker-build](https://github.com/samuelhbne/server-xray/workflows/docker-buildx-latest/badge.svg)

## [Optional] How to build server-xray docker image

```shell
$ git clone https://github.com/samuelhbne/server-xray.git
$ cd server-xray
$ docker build -t samuelhbne/server-xray -f Dockerfile.amd64 .
...
```

### NOTE1

- Please replace "amd64" with the arch match the current box accordingly. For example: "arm64" for AWS ARM64 platform like A1, t4g instance or 64bit Ubuntu on Raspberry Pi. "arm" for 32bit Raspbian.

## How to start the container

```shell
$ docker run --rm -it samuelhbne/server-xray
server-xray --<ltx|ltt|lttw|mtt|mttw|ttt> <options> [-r|--request-domain <domain-name>] [-c|--cert-path <cert-path-root>] [-k|--hook <hook-url>]
    -k|--hook <hook-url>               [Optional] DDNS update or notifing URL to be hit. Multiple allowed
    -r|--request-domain <domain-name>  [Optional] Domain name to request for letsencrypt cert. Multiple allowed
    -c|--cert-path <cert-path-root>    [Optional] Reading TLS certs from folder <cert-path-root>/<domain-name>/. Multiple allowed
    --ltx  <VLESS-TCP-XTLS option>     [p=443,]d=domain.com,u=id[:level[:email]][,f=[fallback-host]:fb-port:[fb-path]]
    --ltt  <VLESS-TCP-TLS option>      [p=443,]d=domain.com,u=id[:level[:email]][,f=[fallback-host]:fb-port:[fb-path]]
    --lttw <VLESS-TCP-TLS-WS option>   [p=443,]d=domain.com,u=id[:level[:email]][,f=[fallback-host]:fb-port:[fb-path]],w=/webpath
    --lttg <VLESS-TCP-TLS-GRPC option> [p=443,]d=domain.com,u=id[:level[:email]],s=/svcpath,g=grpcport
    --mtt  <VMESS-TCP-TLS option>      [p=443,]d=domain.com,u=id[:level[:email]][,f=[fallback-host]:fb-port:[fb-path]]
    --mttw <VMESS-TCP-TLS-WS option>   [p=443,]d=domain.com,u=id[:level[:email]][,f=[fallback-host]:fb-port:[fb-path]],w=/webpath
    --ttt  <TROJAN-TCP-TLS option>     [p=443,]d=domain.com,u=passwd[:email][,f=[fallback-host]:fb-port:[fb-path]]
    --tttw <TROJAN-TCP-TLS-WS option>  [p=443,]d=domain.com,u=passwd[:email][,f=[fallback-host]:fb-port:[fb-path]],w=/webpath
    --stdin                            Read XRay config from stdin instead of auto generation

$ docker run --name server-xray -p 80:80 -p 443:2443 -d samuelhbne/server-xray \
--ltx p=2443,d=mydomain.duckdns.org,u=myid,f=:8080 -r mydomain.duckdns.org
...
```

### NOTE2

- Please replace the port 443 (-p 443:2443) with the port number you choose for Xray incoming connection.
- Port 80 export (-p 80:80) is necessary for Letsencrypt cert requesting, so don't miss it.
- Please replace "myid" with the id string or standard UUID (like "MyMobile or "b77af52c-2a93-4b3e-8538-f9f91114ba00") you set for Xray client auth.
- Please replace mydomain.duckdns.org with the domain-name of yours.
- You can optionally assign a HOOK-URL to update the DDNS.

## How to verify if server-xray is running properly

Try to connect the server from Xray compatible mobile app like [v2rayNG](https://github.com/2dust/v2rayNG) for Android or [Shadowrocket](https://apps.apple.com/us/app/shadowrocket/id932747118) for iOS with the host-name, port, id etc. set above. Or verify it from Ubuntu / Debian / Raspbian client host follow the instructions below.

### Verifying server-xray connection with proxy-xray

```shell
$ docker run --rm -it samuelhbne/proxy-xray
proxy-xray --<ltx|ltt|lttw|mtt|mttw|ttt|tttw|ssa|sst|stdin> [options]
    --ltx  <VLESS-TCP-XTLS option>        id@host:port
    --ltt  <VLESS-TCP-TLS option>         id@host:port
    --lttw <VLESS-TCP-TLS-WS option>      id@host:port:/webpath
    --lttg <VLESS-TCP-TLS-GRPC option>    id@host:port:/svcpath
    --mtt  <VMESS-TCP-TLS option>         id@host:port
    --mttw <VMESS-TCP-TLS-WS option>      id@host:port:/webpath
    --ttt  <TROJAN-TCP-TLS option>        password@host:port
    --tttw <TROJAN-TCP-TLS-WS option>     password@host:port:/webpath
    -d|--debug                            Start in debug mode with DNS server disabled
    --stdin                               Read XRay config from stdin instead of auto generation

$ docker run --name proxy-xray -p 1080:1080 -d samuelhbne/proxy-xray \
--ltx myid@mydomain.duckdns.org:443
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

## More complex examples

### 1. Running a XTLS and Trojan server with DDNS auto-update and Letsencrypt cert auto-request

The following command will:

1. Update domain1 and domain2 with the current IP address server-xray running
2. Request TLS certs from Letsencrypt for domain1 and domain2
3. Create Vless+TLS+Websocket server on port 443 with the cert of domain1
4. Create Trojan server on port 8443 with the cert of domain2 as fallback
5. Port 80 must be exported for domain ownership verification

```shell
$ docker run --name server-xray -p 80:80 -p 443:443 -p 8443:8443 -d samuelhbne/server-xray \
--ltx p=443,d=domain1.duckdns.org,u=myid,f=:8443 \
--ttt p=2443,d=domain2.duckdns.org,u=trojan_pass \
-k https://duckdns.org/update/domain1/c9711c65-db21-4f8c-a790-2c32c93bde8c \
-k https://duckdns.org/update/domain2/c9711c65-db21-4f8c-a790-2c32c93bde8c \
-r domain1.duckdns.org \
-r domain2.duckdns.org
...
```

#### XTLS connection verifying instructions

```shell
$ docker run --name proxy-xray -p 1080:1080 -d samuelhbne/proxy-xray --ltx \
myid@mydomain.duckdns.org:443

$ curl -sSx socks5h://127.0.0.1:1080 http://ifconfig.co
12.34.56.78

$ docker exec -it proxy-xray /status.sh
VPS-Server: domain1.duckdns.org
Xray-URL: vless://myid@domain1.duckdns.org:443?security=xtls&type=tcp&flow=xtls-rprx-direct#domain1.duckdns.org:443
[QR-Code]
...
```

#### Trojan connection verifying instructions

```shell
$ docker run --name proxy-xray2 -p 2080:1080 -d samuelhbne/proxy-xray --ttt \
trojan_pass@domain2.duckdns.org:8443

$ curl -sSx socks5h://127.0.0.1:2080 http://ifconfig.co
12.34.56.78

$ docker exec -it proxy-xray2 /status.sh
VPS-Server: mydomain.duckdns.org
Xray-URL: trojan://trojan_pass@domain2.duckdns.org:8443#domain2.duckdns.org:8443
[QR-Code]
...
```

### 2. Running a Vless+TLS+Websocket server with existing TLS cert

The following command will:

1. Assume to read TLS cert from /home/ubuntu/cert/mydomain.duckdns.org/fullchain.cer
2. Assume to read private key from  /home/ubuntu/cert/mydomain.duckdns.org/mydomain.duckdns.org.key
3. Assume mydomain.duckdns.org has been resolved to the current server
4. Run Xray in Vless+TLS+Websocket mode on default port 443 with the given cert
5. Fallback to microsoft.com if client handshake failed (Anti-detection)

```shell
$ docker run --name server-xray -p 443:443 -v /home/ubuntu/cert:/opt/cert -d samuelhbne/server-xray \
--lttw d=mydomain.duckdns.org,u=myid,w=/websocket,f=microsoft.com:80 \
-c /opt/cert
...
```

#### Websocket connection verifying instructions

```shell
$ docker run --name proxy-xray -p 1080:1080 -d samuelhbne/proxy-xray --lttw \
myid@mydomain.duckdns.org:443:/websocket

$ curl -sSx socks5h://127.0.0.1:1080 http://ifconfig.co
12.34.56.78

$ docker exec -it proxy-xray /status.sh
VPS-Server: mydomain.duckdns.org
Xray-URL: vless://myid@mydomain.duckdns.org:443?security=tls&type=ws&path=%2Fwebsocket#mydomain.duckdns.org:443
[QR-Code]
...
```

### 3. Running a Vless+TCP+TLS+gRPC server with Nginx in front of, with existing TLS cert

The following command will:

1. Assume to read TLS cert from /home/ubuntu/cert/mydomain.duckdns.org/fullchain.cer
2. Assume to read private key from  /home/ubuntu/cert/mydomain.duckdns.org/mydomain.duckdns.org.key
3. Assume mydomain.duckdns.org has been resolved to the current server
4. Run Xray in Vless+TCP+TLS+gRPC mode on port 65443 with the given cert
5. Run nginx on port 443 as a front to protect gRPC backend from detection
6. Only port 443 will be available for access from internet

```shell
$ docker run --name server-xray -p 443:443 -v /home/ubuntu/cert:/opt/cert -d samuelhbne/server-xray \
-c /opt/cert --lttg port=443,domain=mydomain.duckdns.org,user=myid,service=/gsvc,gport=65443
...
```

#### gRPC connection verifying instructions

```shell
$ docker run --name proxy-xray -p 1080:1080 -d samuelhbne/proxy-xray --lttg \
myid@mydomain.duckdns.org:443:/gsvc

$ curl -sSx socks5h://127.0.0.1:1080 http://ifconfig.co
12.34.56.78

$ docker exec -it proxy-xray /status.sh
VPS-Server: mydomain.duckdns.org
Xray-URL: vless://myid@mydomain.duckdns.org:443?security=tls&type=grpc&serviceName=/gsvc&mode=gun#mydomain.duckdns.org:443
[QR-Code]
...
```

### 4. Running server-ray container in debug mode for connection issue diagnosis

The following instruction start server-trojan in debug mode. Output Xray config file and the log to console for connection diagnosis. dnscrypt-proxy will be disabled to avoid flooding the log output.

```shell
$ docker run --rm -p 80:80 -p 443:443 -it samuelhbne/server-xray \
-k https://duckdns.org/update/mydomain/c9711c65-db21-4f8c-a790-2c32c93bde8c \
--mttw d=mydomain.duckdns.org,u=myid,w=/websocket,f=microsoft.com:80 \
-r mydomain.duckdns.org --debug
...
```
