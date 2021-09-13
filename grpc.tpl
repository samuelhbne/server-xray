    location LOCATION {
        if ($content_type !~ "application/grpc") {
            return 404;
        }
        client_max_body_size    0;
        client_body_timeout     1071906480m;
        grpc_read_timeout       1071906480m;
        grpc_pass               grpc://127.0.0.1:PORT;
    }