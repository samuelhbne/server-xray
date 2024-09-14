#STSTUB
stream {
    map $ssl_preread_server_name $stream_map {
        #XMAP-TAG
    }

    #XUPSTREAM-TAG

    server {
        listen STPORT reuseport;
        proxy_pass $stream_map;
        # proxy_bind $remote_addr transparent;
        ssl_preread on;
    }
}
