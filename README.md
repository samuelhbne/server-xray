# server-xray

[Xray](https://github.com/XTLS/Xray-core) is a low detectable VPN. server-xray is a Xray server container that runs Xray with config file generated from command line options directly hence remove the necessity of Xray config modification.

Please have a look over the sibling project [proxy-xray](https://github.com/samuelhbne/proxy-xray) if you'd like to set a Xray client.

![docker-build](https://github.com/samuelhbne/server-xray/workflows/docker-buildx-latest/badge.svg)
![docker-build](https://github.com/samuelhbne/server-xray/workflows/docker-buildx-dev/badge.svg)

## Quick start

### 1. VLESS-TCP-TLS-XTLS server creation

The following command starts a VLESS-TCP-TLS-XTLS server on port 443, also, it update the DDNS record of mydomain.duckdns.org point to the current server, then requests a new Lesencrypt TLS cert for the domain.

```shell
$ docker run --name server-xtls -p 80:80 -p 443:443 -d samuelhbne/server-xray \
--lttx p=443,d=mydomain.duckdns.org,u=myid \
-k https://duckdns.org/update/mydomain/c9711c65-db21-4f8c-a790-2c32c93bde8c \
-r mydomain.duckdns.org
...
```

** NOTE **

- Port 80 exposure (-p 80:80) is necessary for Letsencrypt domain verification during cert requesting.

### 2. VLESS-TCP-REALITY-XTLS server creation

The following command starts a VLESS-TCP-REALITY-XTLS server on port 443. And update DDNS optionally, although IP only based connection is possible due to the nature of REALITY connection.

```shell
# Generate a x25519 via xray first
$ docker run --rm -it --entrypoint /usr/local/bin/xray samuelhbne/server-xray x25519
Private key: OGgyKdxoCbtunsvQp4UX7eos7BInETDezsuEHRF-AT4
Public key: qAaJnTE_zYWNuXuIdlpIfSt5beveuV4PyBaP76WE7jU

# Create a new VLESS-TCP-REALITY-XTLS server with the private key. Apply yahoo.com as the fake Destination
$ docker run --name server-reality-xtls -p 443:443 -d samuelhbne/server-xray \
--ltrx p=443,d=yahoo.com,u=myid,shortId=abcd,prv=OGgyKdxoCbtunsvQp4UX7eos7BInETDezsuEHRF-AT4 \
-k https://duckdns.org/update/mydomain/c9711c65-db21-4f8c-a790-2c32c93bde8c \
-r mydomain.duckdns.org
```

** NOTE **

Domain name and TLS cert are not necessary due to the nature of REALITY connection. Althouth you can obtain a  DDNS domain name to facilitate client connecting optionally.


## How to verify if the xray-server is running properly

Try to connect the server from Xray compatible mobile app like [v2rayNG](https://github.com/2dust/v2rayNG) for Android or [Shadowrocket](https://apps.apple.com/us/app/shadowrocket/id932747118) for iOS with the host-name, port, id etc. set above. Or verify it from Ubuntu / Debian / Raspbian client following the instructions below.

### Verifying VLESS-TCP-TLS-XTLS connection with [proxy-xray](https://github.com/samuelhbne/proxy-xray)

```shell
$ docker run --name proxy-xray -p 1080:1080 -d samuelhbne/proxy-xray \
--lttx myid@mydomain.duckdns.org:443
...

$ curl -sSx socks5h://127.0.0.1:1080 https://checkip.amazonaws.com
12.34.56.78
```

### Verifying VLESS-TCP-REALITY-XTLS connection with [proxy-xray](https://github.com/samuelhbne/proxy-xray)

```shell
# Create a new VLESS-TCP-REALITY-XTLS client with the public key generated above. Apply yahoo.com as the fake Destination
$ docker run --name proxy-xray -p 1080:1080 -d samuelhbne/proxy-xray \
--ltrx myid@mydomain.duckdns.org:443,d=yahoo.com,shortId=abcd,pub=qAaJnTE_zYWNuXuIdlpIfSt5beveuV4PyBaP76WE7jU
...

$ curl -sSx socks5h://127.0.0.1:1080 https://checkip.amazonaws.com
12.34.56.78
```

#### How it works

- proxy-xray created a SOCKS5 proxy that tunneling traffic through your Xray server.
- curl query was sent to checkip.amazonaws.com via the SOCKS5 proxy served by proxy-xray.
- Like this: curl --> proxy-xray --> server-xray --> checkip.amazonaws.com website.
- You should get the public IP address of server-xray if all going well.
- Please have a look over the sibling project [proxy-xray](https://github.com/samuelhbne/proxy-xray) for more details.

## Full usage

```shell
$ docker run --rm samuelhbne/server-xray
server-xray <server-options>
    --lgp  <VLESS-GRPC-PLN option>        p=11443,u=id1,u=id2...,s=svcname
    --lgr  <VLESS-GRPC-RLTY option>       p=12443,u=id1,u=id2...,s=svcname,d=dest.com,pub=xx,prv=yy[,shortId=ab]
    --lgt  <VLESS-GRPC-TLS option>        p=13443,u=id1,u=id2...,s=svcname,d=domain.com
    --lsp  <VLESS-SPLT-PLN option>        p=14443,u=id1,u=id2...,w=/webpath
    --lst  <VLESS-SPLT-TLS option>        p=16443,u=id1,u=id2...,w=/webpath,d=domain.com
    --ltr  <VLESS-TCP-RLTY option>        p=17443,u=id1,u=id2...,d=dest.com,pub=xx,prv=yy[,shortId=ab],[xtls]
    --ltrx <VLESS-TCP-RLTY-XTLS option>   p=17443,u=id1,u=id2...,d=dest.com,pub=xx,prv=yy[,shortId=ab]
    --ltt  <VLESS-TCP-TLS option>         p=18443,u=id1,u=id2...,d=domain.com,[xtls]
    --lttx <VLESS-TCP-TLS-XTLS option>    p=18443,u=id1,u=id2...,d=domain.com
    --lwp  <VLESS-WS-PLN option>          p=19443,u=id1,u=id2...,w=/wskpath
    --lwt  <VLESS-WS-TLS option>          p=22443,u=id1,u=id2...,w=/wskpath,d=domain.com
    --mtt  <VMESS-TCP-TLS option>         p=23443,u=id1,u=id2...,d=domain.com
    --mwp  <VMESS-WS-PLN option>          p=24443,u=id1,u=id2...,w=/wskpath
    --mwt  <VMESS-WS-TLS option>          p=25443,u=id1,u=id2...,w=/wskpath,d=domain.com
    --ttt  <TROJAN-TCP-TLS option>        p=26443,u=pw1,u=pw2...,d=domain.com
    --twp  <TROJAN-WS-PLN option>         p=27443,u=pw1,u=pw2...,w=/wskpath
    --twt  <TROJAN-WS-TLS option>         p=28443,u=pw1,u=pw2...,w=/wskpath,d=domain.com
    --ng-server <nginx-server-options>    p=8443,d=domain0.com,d=domain1.com...
    --ng-proxy  <nginx-proxy-options>     d=domain0.com,d=domain1.com,p=port-backend,l=location,n=ws|grpc|splt
    --st-port   <stream-port-number>      443
    --st-map    <stream-map-options>      sni=domain.com,ups=127.0.0.1:8443
    --domain-block <domain-rule>          Add a domain rule for routing-server block, like geosite:category-ads-all
    --ip-block  <ip-rule>                 Add a ip-addr rule for routing block, like geoip:private
    --cn-block                            Add routing rules to avoid domains and IPs located in China being proxied
    -u|--user   <global-user-options>     u=id0,u=id1...
    -k|--hook   <hook-url>                DDNS update or notifing URL to be hit
    -r|--request-domain <domain-name>     Domain name to request for letsencrypt cert
    -c|--cert-home <cert-home-dir>        Reading TLS certs from folder <cert-home-dir>/<domain-name>/
    -i|--stdin                            Read config from STDIN instead of auto generation
    -j|--json                             Json snippet to merge into the config. Say '{log:{loglevel:info}'
    -d|--debug                            Start in debug mode with verbose output
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
3. Create Vless-TCP-TLS-XTLS server on port 443 with the cert of domain1
4. Create Trojan-TCP-TLS server on port 8443 with the cert of domain2 as fallback

```shell
$ docker run --name server-xray -p 80:80 -p 443:443 -p 8443:8443 -d samuelhbne/server-xray \
--ltrx p=443,d=domain1.duckdns.org,u=myid,f=:8443 \
--ttt p=8443,d=domain2.duckdns.org,u=trojan_pass \
-k https://duckdns.org/update/domain1/c9711c65-db21-4f8c-a790-2c32c93bde8c \
-k https://duckdns.org/update/domain2/c9711c65-db21-4f8c-a790-2c32c93bde8c \
-r domain1.duckdns.org \
-r domain2.duckdns.org
...
```

#### Vless-TCP-TLS-XTLS connection verifying instructions

```shell
$ docker run --name proxy-xray -p 1080:1080 -d samuelhbne/proxy-xray --ltrx \
myid@mydomain.duckdns.org:443

$ curl -sSx socks5h://127.0.0.1:1080 https://checkip.amazonaws.com
12.34.56.78

$ docker exec -t proxy-xray /status.sh
VPS-Server: domain1.duckdns.org
Xray-URL: vless://myid@domain1.duckdns.org:443?security=xtls&type=tcp&flow=xtls-rprx-direct#domain1.duckdns.org:443
[QR-Code]
...
```

#### Trojan-TCP-TLS connection verifying instructions

```shell
$ docker run --name proxy-xray -p 2080:1080 -d samuelhbne/proxy-xray --ttt \
trojan_pass@domain2.duckdns.org:8443

$ curl -sSx socks5h://127.0.0.1:2080 https://checkip.amazonaws.com
12.34.56.78

$ docker exec -t proxy-xray /status.sh
VPS-Server: mydomain.duckdns.org
Xray-URL: trojan://trojan_pass@domain2.duckdns.org:8443#domain2.duckdns.org:8443
[QR-Code]
...
```

### 2. Running a Vless-Websocket-TLS server with existing TLS cert

The following command will:

1. Assume to read TLS cert from /home/ubuntu/cert/mydomain.duckdns.org/fullchain.cer
2. Assume to read private key from  /home/ubuntu/cert/mydomain.duckdns.org/mydomain.duckdns.org.key
3. Assume mydomain.duckdns.org has been resolved to the current server
4. Run Xray in Vless+TLS+Websocket mode on default port 443 with the given cert
5. Fallback to microsoft.com if client handshake failed (Anti-detection)

```shell
$ docker run --name server-xray -p 443:443 -v /home/ubuntu/cert:/opt/cert -d samuelhbne/server-xray \
--lwt d=mydomain.duckdns.org,u=myid,w=/websocket,f=microsoft.com:80 -c /opt/cert
...
```

#### Vless-Websocket-TLS connection verifying instructions

```shell
$ docker run --name proxy-xray -p 1080:1080 -d samuelhbne/proxy-xray --lwt \
myid@mydomain.duckdns.org:443:/websocket

$ curl -sSx socks5h://127.0.0.1:1080 https://checkip.amazonaws.com
12.34.56.78

$ docker exec -t proxy-xray /status.sh
VPS-Server: mydomain.duckdns.org
Xray-URL: vless://myid@mydomain.duckdns.org:443?security=tls&type=ws&path=%2Fwebsocket#mydomain.duckdns.org:443
[QR-Code]
...
```

### 3. Running a Vless-gRPC-PLAIN server and Nginx TLS front, with existing TLS cert

The following command will:

1. Assume to read TLS cert from /home/ubuntu/cert/mydomain.duckdns.org/fullchain.cer
2. Assume to read private key from  /home/ubuntu/cert/mydomain.duckdns.org/mydomain.duckdns.org.key
3. Assume mydomain.duckdns.org has been resolved to the current server
4. Run Xray in Vless+TCP+PLAIN+gRPC mode on port 65443
5. Run nginx on port 443 as a TLS front to protect gRPC backend from detection, with the given cert
6. Only port 443 will be available for access from internet

```shell
$ docker run --name server-xray -p 443:443 -v /home/ubuntu/cert:/opt/cert -d samuelhbne/server-xray \
-c /opt/cert --ng-server port=443,domain=mydomain.duckdns.org \
--lgp port=65443,user=myid,service=gsvc \
--ng-proxy port=65443,location=/gsvc,network=grpc

...
```

#### Vless-gRPC-TLS connection verifying instructions

```shell
$ docker run --name proxy-xray -p 1080:1080 -d samuelhbne/proxy-xray --lgt \
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
3. Assume domain0.duckdns.org and domain1.duckdns.org has been pointed to the current server
4. Run Vless-gRPC-PLAIN service on port 55443, location /svc0, serve on all domains
5. Run Vless-WebSocket-PLAIN service on port 53443, location /ws1, serve on all domains
6. Run Trojan-WebSocket-PLAIN service on port 51443, location /ws2, serve only on domain1.duckdns.org
7. Run nginx on port 443 as a TLS front with the given certs of the 2 domains, proxy 3 services with different locations
8. Only port 443 will be exposed for internet accessing
9. All proxy requests for IPs or websites located in China will be BLOCKED to protect users from being traced or de-anonymous.

```shell
$ docker run --name server-xray -p 443:443 -v /home/ubuntu/cert:/opt/cert -d samuelhbne/server-xray \
-c /opt/cert --cn-block \
--lgp p=55443,u=myid0,s=svc0 \
--lwp p=53443,u=myid1,w=/ws1 \
--twp p=51443,u=myid2,w=/ws2 \
--ng-server p=443,d=domain0.duckdns.org,d=domain1.duckdns.org \
--ng-proxy p=55443,l=/svc0,n=grpc \
--ng-proxy p=53443,l=/ws1,n=ws \
--ng-proxy d=domain1.duckdns.org,p=51443,l=/ws2,n=ws
...
```

### NOTE 4

Only PLAIN (NON-TLS) services (--lgp, --lwp, --mwp, -twp) can be proxied by Nginx.

NEVER EVER expose any plain services on internet directly. They are designed to be proxied by Nginx TLS front
hence all different transport portocols can be accessed via diffent web-path while only the TLS port 443 will be exposed via Nginx.

#### Multiple service connection verifying instructions

```shell
$ docker run --name proxy-gsvc -p 1080:1080 -d samuelhbne/proxy-xray --lgt myid0@domain0.duckdns.org:443:/gsvc
$ docker run --name proxy-vless -p 2080:1080 -d samuelhbne/proxy-xray --lwt myid1@domain1.duckdns.org:443:/ws1
$ docker run --name proxy-trojan -p 3080:1080 -d samuelhbne/proxy-xray --twt myid2@domain0.duckdns.org:443:/ws2

$ curl -sSx socks5h://127.0.0.1:1080 https://checkip.amazonaws.com
12.34.56.78

$ curl -sSx socks5h://127.0.0.1:2080 https://checkip.amazonaws.com
12.34.56.78

$ curl -sSx socks5h://127.0.0.1:3080 https://checkip.amazonaws.com
12.34.56.78
...
```

### 5. Serving REALITY server alongside with TLS server via Nginx Stream SNI domain name Mapping

```shell
$ docker run --name server-reality-tls -p 443:443 -v /home/ubuntu/cert:/opt/cert -d samuelhbne/server-xray \
-c /opt/cert --cn-block --debug -u u=id0,u=id1 \
--ltrx proxy_acpt,p=10443,d=yahoo.com,shortId=abcd,prv=OGgyKdxoCbtunsvQp4UX7eos7BInETDezsuEHRF-AT4 \
--st-map sni=yahoo.com,ups=127.0.0.1:10443 \
--lgp p=11443,s=grpc0 \
--ng-proxy p=11443,l=/grpc0,n=grpc \
--lwp p=12443,w=/ws0 \
--ng-proxy p=12443,w=/ws0,n=ws \
--ng-server proxy_acpt,p=8443,d=mydomain.duckdns.org \
--st-map sni=mydomain.duckdns.org,ups=127.0.0.1:8443 \
--st-server proxy_pass,p=443 \
-k https://duckdns.org/update/mydomain/c9711c65-db21-4f8c-a790-2c32c93bde8c \
-r mydomain.duckdns.org
```

-c /opt/cert --cn-block --debug -u u=id0,u=id1  

Save Letsencrypt certs in /opt/cert; Block all websites located in China; Set log level debug; Add uid id0, id1 for all services created below.

--ltrx proxy_acpt,p=10443,d=yahoo.com,shortId=abcd,prv=OGgyKdxoCbtunsvQp4UX7eos7BInETDezsuEHRF-AT4  

Create a Vless-TCP-Reality-Xtls-vision service on port 10443 with yahoo.com as fake destinaition. Accept proxy-protocol. Which is important for logging correct client address if necessary.

--st-map sni=yahoo.com,ups=127.0.0.1:10443  

Create a Nginx Stream mapping entry for the LTRX service we just created on port 10443. This entry will only be matched when clients request yahoo.com as destination SNI domain name.

--lgp p=11443,s=grpc0  

Create a Vless-gRPC-Plain service on port 11443 with gRPC name grpc0

--ng-proxy p=11443,l=/grpc0,n=grpc  

Create a Nginx proxy location on /grpc0 for the LGP service we just created on port 11443, network type is gRPC.

--lwp p=12443,w=/ws0  

Create a Vless-WebSocket-Plain service on port 12443 with websocket path /ws0

--ng-proxy p=12443,w=/ws0,n=ws  

Create a Nginx proxy location on /ws0 for the LWP service we just created on port 12443, network type is WebSocket.

--ng-server proxy_acpt,p=8443,d=mydomain.duckdns.org  

Create a Nginx TLS front server on port 8443, with domain name mydomain.duckdns.org. Contents all proxy locations we set above.

--st-map sni=mydomain.duckdns.org,ups=127.0.0.1:8443  

Create a Nginx Stream mapping entry for the Nginx TLS front server we just created on port 8443. This entry will only be matched when clients request mydomain.duckdns.org as destination SNI domain name. TIP: You can set default as the sni to match all other domain names except yahoo.com, which will be matched and directed to the LTRX services we set above.

--st-server proxy_pass,p=443  

Create a Nginx Stream Server on master port 443, directs all requests based on the SNI in requests to upstream map entries we created above with Proxy Protocol. Which is important for logging correct client address if necessary.

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
