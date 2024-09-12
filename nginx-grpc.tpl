    location LOCATION {
        if ($content_type !~ "application/grpc") {
            return 404;
        }
        client_max_body_size    0;
        client_body_timeout     1071906480m;
        grpc_read_timeout       1071906480m;
        grpc_pass               grpc://HOST:PORT;
        grpc_set_header         Host $host;
        grpc_set_header         X-Real-IP $remote_addr;
        grpc_set_header         X-Forwarded-For $proxy_add_x_forwarded_for;
    }