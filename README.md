# server-xray

[Xray](https://github.com/XTLS/Xray-core) is a low detectable VPN. server-xray is a Xray server container that runs Xray with config file generated from command line options directly hence remove the necessity of Xray config modification.

Please have a look over the sibling project [proxy-xray](https://github.com/samuelhbne/proxy-xray) if you'd like to set a Xray client.

![docker-build](https://github.com/samuelhbne/server-xray/workflows/docker-buildx-latest/badge.svg)
![docker-build](https://github.com/samuelhbne/server-xray/workflows/docker-buildx-dev/badge.svg)

## How to start the container

The following command will:

1. Update DDNS record of mydomain.duckdns.org pointing the current host
2. Request a new Lesencrypt TLS cert for this domain
3. Start VLESS-TCP-XTLS server on port 443

```shell
$ docker run --name server-xray -p 80:80 -p 443:2443 -d samuelhbne/server-xray \
--lx p=2443,d=mydomain.duckdns.org,u=myid,f=:8080 \
-k https://duckdns.org/update/mydomain/c9711c65-db21-4f8c-a790-2c32c93bde8c \
-r mydomain.duckdns.org
...
```

### NOTE 1

- Please replace the port 443 (-p 443:2443) with the port number you choose for incoming connection.
- Port 80 export (-p 80:80) is necessary for Letsencrypt cert requesting, so don't miss it.
- Please replace "myid" with an id string or a standard UUID ("MyMobile", "b77af52c-2a93-4b3e-8538-f9f91114ba00" etc.) you set for client auth.
- Please replace "mydomain.duckdns.org" with the domain-name of yours.
- You can optionally assign a HOOK-URL to update the DDNS to the current server IP.

## How to verify if server-xray is running properly

Try to connect the server from Xray compatible mobile app like [v2rayNG](https://github.com/2dust/v2rayNG) for Android or [Shadowrocket](https://apps.apple.com/us/app/shadowrocket/id932747118) for iOS with the host-name, port, id etc. set above. Or verify it from Ubuntu / Debian / Raspbian client host follow the instructions below.

### Verifying server-xray connection with proxy-xray

```shell
$ docker run --name proxy-xray -p 1080:1080 -d samuelhbne/proxy-xray \
--lx myid@mydomain.duckdns.org:443
...

$ curl -sSx socks5h://127.0.0.1:1080 https://checkip.amazonaws.com
12.34.56.78
```

### NOTE 2

#### How it works

- proxy-xray created a SOCKS5 proxy that tunneling traffic through your Xray server.
- curl query was sent to checkip.amazonaws.com via the SOCKS5 proxy served by proxy-xray.
- Like this: curl --> proxy-xray --> server-xray --> checkip.amazonaws.com website.
- You should get the public IP address of server-xray if all go well.
- Please have a look over the sibling project [proxy-xray](https://github.com/samuelhbne/proxy-xray) for more details.

## Full usage

```shell
$ docker run --rm samuelhbne/server-xray
server-xray <server-options>
    --lx  <VLESS-XTLS option>         [p=443,]d=domain.com,u=id[:level[:email]]
    --ls  <VLESS-TLS option>          [p=443,]d=domain.com,u=id[:level[:email]]
    --ms  <VMESS-TLS option>          [p=443,]d=domain.com,u=id[:level[:email]]
    --ts  <TROJAN-TLS option>         [p=443,]d=domain.com,u=psw[:level[:email]]
    --lsg <VLESS-TLS-GRPC option>     [p=443,]d=domain.com,u=id[:level[:email]],s=svcname
    --lss <VLESS-TLS-SPLT option>     [p=443,]d=domain.com,u=id[:level[:email]],w=/webpath
    --lsw <VLESS-TLS-WS option>       [p=443,]d=domain.com,u=id[:level[:email]],w=/wspath
    --msw <VMESS-TLS-WS option>       [p=443,]d=domain.com,u=id[:level[:email]],w=/wspath
    --tsw <TROJAN-TLS-WS option>      [p=443,]d=domain.com,u=psw[:level[:email]],w=/wspath
    --lpg <VLESS-PLN-GRPC option>     [p=443,]u=id[:level[:email]],s=svcname
    --lps <VLESS-PLN-SPLT option>     [p=443,]u=id[:level[:email]],w=/webpath
    --lpw <VLESS-PLN-WS option>       [p=443,]u=id[:level[:email]],w=/wspath
    --mpw <VMESS-PLN-WS option>       [p=443,]u=id[:level[:email]],w=/wspath
    --tpw <TROJAN-PLN-WS option>      [p=443,]u=psw[:level[:email]],w=/wspath
    --ng-opt <nginx-options>          [p=443,]d=domain0.com[,d=domain1.com][...]
    --ng-proxy <nginx-proxy-options>  [d=domain0.com,][d=domain1.com,][...][h=127.0.0.1,]p=port-backend,l=location,n=ws|grpc|splt
    -u|--user <global-user-options>   u=id0[:level[:email]][,u=id1][...]
    -k|--hook <hook-url>              DDNS update or notifing URL to be hit
    -r|--request-domain <domain-name> Domain name to request for letsencrypt cert
    -c|--cert-home <cert-home-dir>    Reading TLS certs from folder <cert-home-dir>/<domain-name>/
    -i|--stdin                        Read config from STDIN instead of auto generation
    -d|--debug                        Start in debug mode with verbose output
```

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

### NOTE 3

Port 80 must be exported for TLS domain ownership verification

```shell
$ docker run --name server-xray -p 80:80 -p 443:443 -p 8443:8443 -d samuelhbne/server-xray \
--lx p=443,d=domain1.duckdns.org,u=myid,f=:8443 \
--ts p=8443,d=domain2.duckdns.org,u=trojan_pass \
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

$ curl -sSx socks5h://127.0.0.1:1080 https://checkip.amazonaws.com
12.34.56.78

$ docker exec -t proxy-xray /status.sh
VPS-Server: domain1.duckdns.org
Xray-URL: vless://myid@domain1.duckdns.org:443?security=xtls&type=tcp&flow=xtls-rprx-direct#domain1.duckdns.org:443
[QR-Code]
...
```

#### Trojan connection verifying instructions

```shell
$ docker run --name proxy-xray -p 2080:1080 -d samuelhbne/proxy-xray --ts \
trojan_pass@domain2.duckdns.org:8443

$ curl -sSx socks5h://127.0.0.1:2080 https://checkip.amazonaws.com
12.34.56.78

$ docker exec -t proxy-xray /status.sh
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
--lsw d=mydomain.duckdns.org,u=myid,w=/websocket,f=microsoft.com:80 \
-c /opt/cert
...
```

#### Websocket connection verifying instructions

```shell
$ docker run --name proxy-xray -p 1080:1080 -d samuelhbne/proxy-xray --lsw \
myid@mydomain.duckdns.org:443:/websocket

$ curl -sSx socks5h://127.0.0.1:1080 https://checkip.amazonaws.com
12.34.56.78

$ docker exec -t proxy-xray /status.sh
VPS-Server: mydomain.duckdns.org
Xray-URL: vless://myid@mydomain.duckdns.org:443?security=tls&type=ws&path=%2Fwebsocket#mydomain.duckdns.org:443
[QR-Code]
...
```

### 3. Running a Vless+TCP+PLAN+gRPC server + Nginx TLS front, with existing TLS cert

The following command will:

1. Assume to read TLS cert from /home/ubuntu/cert/mydomain.duckdns.org/fullchain.cer
2. Assume to read private key from  /home/ubuntu/cert/mydomain.duckdns.org/mydomain.duckdns.org.key
3. Assume mydomain.duckdns.org has been resolved to the current server
4. Run Xray in Vless+TCP+PLAN+gRPC mode on port 65443
5. Run nginx on port 443 as a TLS front to protect gRPC backend from detection, with the given cert
6. Only port 443 will be available for access from internet

```shell
$ docker run --name server-xray -p 443:443 -v /home/ubuntu/cert:/opt/cert -d samuelhbne/server-xray \
-c /opt/cert --ng-opt port=443,domain=mydomain.duckdns.org \
--lpg port=65443,user=myid,service=gsvc \
--ng-proxy port=65443,location=/gsvc,network=grpc

...
```

#### gRPC connection verifying instructions

```shell
$ docker run --name proxy-xray -p 1080:1080 -d samuelhbne/proxy-xray --lsg \
myid@mydomain.duckdns.org:443:gsvc

$ curl -sSx socks5h://127.0.0.1:1080 https://checkip.amazonaws.com
12.34.56.78

$ docker exec -t proxy-xray /status.sh
VPS-Server: mydomain.duckdns.org
Xray-URL: vless://myid@mydomain.duckdns.org:443?security=tls&type=grpc&serviceName=/gsvc&mode=gun#mydomain.duckdns.org:443
[QR-Code]
...
```

### 4. Serve multiple services on single port, multiple domains with Nginx TLS front

The following command will:

1. Assume to read TLS cert from /home/ubuntu/cert/domain*.duckdns.org/fullchain.cer
2. Assume to read private key from  /home/ubuntu/cert/domain*.duckdns.org/domain*.duckdns.org.key
3. Assume domain0.duckdns.org and domain1.duckdns.org has been resolved to the current server
4. Run Vless+TCP+PLAN+gRPC service on port 55443, location /svc0, serve all domains
5. Run Vless+TCP+PLAN+WebSocket service on port 53443, location /ws1, serve all domains
6. Run Trojan+TCP+PLAN+WebSocket service on port 51443, location /ws2, serve only domain1.duckdns.org
7. Run nginx on port 443 as a TLS front with the given certs for 2 domains, proxy 3 services with 3 locations
8. Only port 443 will be available for access from internet

```shell
$ docker run --name server-xray -p 443:443 -v /home/ubuntu/cert:/opt/cert -d samuelhbne/server-xray \
-c /opt/cert \
--ng-opt p=443,d=domain0.duckdns.org,d=domain1.duckdns.org \
--lpg p=55443,u=myid0,s=svc0 \
--lpw p=53443,u=myid1,w=/ws1 \
--tpw p=51443,u=myid2,w=/ws2 \
--ng-proxy p=55443,l=/svc0,n=grpc \
--ng-proxy p=53443,l=/ws1,n=ws \
--ng-proxy d=domain1.duckdns.org,p=51443,l=/ws2,n=ws
...
```

### NOTE 4

Only PLAN (NON-TLS) services (--lpg, --lpw, --mpw, -tpw) can be proxied by Nginx.

#### Multiple service connection verifying instructions

```shell
$ docker run --name proxy-gsvc -p 1080:1080 -d samuelhbne/proxy-xray --lsg myid0@domain0.duckdns.org:443:/gsvc
$ docker run --name proxy-vless -p 2080:1080 -d samuelhbne/proxy-xray --lsw myid1@domain1.duckdns.org:443:/ws1
$ docker run --name proxy-trojan -p 3080:1080 -d samuelhbne/proxy-xray --tsw myid2@domain0.duckdns.org:443:/ws2

$ curl -sSx socks5h://127.0.0.1:1080 https://checkip.amazonaws.com
12.34.56.78

$ curl -sSx socks5h://127.0.0.1:2080 https://checkip.amazonaws.com
12.34.56.78

$ curl -sSx socks5h://127.0.0.1:3080 https://checkip.amazonaws.com
12.34.56.78
...
```

### 5. Running server-xray container in debug mode for connection issue diagnosis

The following instruction start server-trojan in debug mode. Output Xray config file and the log to console for connection diagnosis.

```shell
$ docker run --rm -p 80:80 -p 443:443 samuelhbne/server-xray \
-k https://duckdns.org/update/mydomain/c9711c65-db21-4f8c-a790-2c32c93bde8c \
--msw d=mydomain.duckdns.org,u=myid,w=/websocket,f=microsoft.com:80 \
-r mydomain.duckdns.org --debug
...
```

## Build server-xray docker image from source

### Build the docker image matches the current host architecture

```shell
$ git clone https://github.com/samuelhbne/server-xray.git
$ cd server-xray
$ docker build -t samuelhbne/server-xray .
...
```

### Cross-compile docker image for the platforms with different architecture

Please refer the [official doc](https://github.com/docker/buildx) for docker-buildx installation

```shell
docker buildx build --platform=linux/arm/v7 --output type=docker -t samuelhbne/server-xray:armv7 .
docker buildx build --platform=linux/arm/v6 --output type=docker -t samuelhbne/server-xray:armv6 .
docker buildx build --platform=linux/arm64 --output type=docker -t samuelhbne/server-xray:arm64 .
docker buildx build --platform=linux/amd64 --output type=docker -t samuelhbne/server-xray:amd64 .
```

## Credits

Thanks to [RPRX](https://github.com/RPRX) for the [Xray](https://github.com/XTLS/Xray-core) project.
