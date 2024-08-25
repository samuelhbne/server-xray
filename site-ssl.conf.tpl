server {
    listen                  NGPORT quic;
    listen                  NGPORT ssl;
    listen                  [::]:NGPORT ssl;
    http2                   on;
    server_name             NGDOMAIN;
    ssl_certificate         CERTFILE;
    ssl_certificate_key     PRVKEYFILE;
    ssl_protocols           TLSv1.2 TLSv1.3;
    ssl_ciphers             HIGH:!aNULL:!MD5;
    add_header              Alt-Svc 'h3=":443"; ma=86400';
    proxy_set_header        X-Real-IP $remote_addr;
    proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;

    client_header_timeout   1071906480m;
    keepalive_timeout       1071906480m;

    location / {
        return 404;
    }

}