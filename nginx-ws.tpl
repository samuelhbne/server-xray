    location LOCATION {
        if ($http_upgrade != "websocket") {
            return 404;
        }
        proxy_redirect      off;
        proxy_pass          http://HOST:PORT;
        proxy_set_header    Upgrade $http_upgrade;
        proxy_set_header    Connection "upgrade";
        proxy_set_header    Host $host;
        proxy_set_header    X-Real-IP $remote_addr;
        proxy_set_header    X-Forwarded-For $proxy_add_x_forwarded_for;
    }