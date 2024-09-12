
#STSTUB
stream {
    map $ssl_preread_server_name $stream_map {
        #MAPSTUB
    }

    #UPSSTUB

    server {
        listen STPORT reuseport;
        proxy_pass $stream_map;
        ssl_preread on;
    }
}
