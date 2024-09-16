#STREAM_TAG
stream {
    map $ssl_preread_server_name $stream_map {
        #XMAP_TAG
    }

    #XUPSTREAM_TAG

    server {
        listen STPORT reuseport;
        listen [::]:STPORT reuseport;
        proxy_pass $stream_map;
        #STPROXY_PASS_TAG
        ssl_preread on;
    }
}
