server {
    listen                  NGPORT ssl http2;
    listen                  [::]:NGPORT ssl http2;
    server_name             NGDOMAIN;
    ssl_certificate         CERTFILE;
    ssl_certificate_key     PRVKEYFILE;
    ssl_protocols           TLSv1.2 TLSv1.3;
    ssl_ciphers             HIGH:!aNULL:!MD5;

    client_header_timeout   1071906480m;
    keepalive_timeout       1071906480m;

    location / {
        return 404;
    }
    location GSVC {
        if ($content_type !~ "application/grpc") {
            return 404;
        }
		client_max_body_size    0;
		client_body_timeout     1071906480m;
		grpc_read_timeout       1071906480m;
		grpc_pass               grpc://127.0.0.1:GPORT;
    }
}