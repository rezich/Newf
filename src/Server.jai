#load "../modules/winsock.jai";

// this needs serious refactoring but hey it works

Server :: struct {
    port: u16;
    wsa: WSAData;
    running: bool = false;
}

create_server :: (port: u16=80) -> *Server {
    server := New(Server);
    server.port = port;
    return server;
}

handle_request :: (socket: Socket) {
    BUFSIZE :: 8096;
    buffer: [BUFSIZE + 1] u8;
    nbytes := recv(socket, buffer.data, BUFSIZE, 0);
    if nbytes <= 0 {
        print("Error! 0 bytes");
    }
    if nbytes > 0 && nbytes < BUFSIZE {
        buffer[nbytes] = 0;
    }
    else {
        buffer[0] = 0;
    }

    buffer_string := to_string(buffer.data);

    verb_end := index_of_char(buffer_string, #char " ");
    verb := slice(buffer_string, 0, verb_end);

    buffer_string = slice(buffer_string, verb_end + 1, buffer_string.count);

    path_end := index_of_char(buffer_string, #char " ");
    path := slice(buffer_string, 0, path_end);

    buffer_string = slice(buffer_string, path_end + 1, buffer_string.count);

    http_end := index_of_string(buffer_string, "\r\n") + 2;

    buffer_string = slice(buffer_string, http_end, buffer_string.count);
    
    req := make_request(request_method_from_string(verb), path);

    for split(buffer_string, "\r\n") {
        kv := split(it, ": ");
        if kv.count > 0 {
            table_add(*req.headers, kv[0], kv[1]);
        }
    }

    res := route_request(req);


    for 0..BUFSIZE {
        buffer[it] = 0;
    }
    response := tprint("HTTP/1.0 % %\r\n%\r\n\r\n%", res.status, http_status_to_string(res.status), make_header_string(res), res.body);
    memcpy(buffer.data, response.data, response.count);
    buffer[response.count] = 0;
    send(socket, buffer.data, cast(s32) response.count, 0);
    deinit(res);
    deinit(req);
}

start :: (using server: *Server) {
    running = true;
    listenfd, socketfd: Socket;
    cli_addr, serv_addr: sockaddr_in = ---;
    if WSAStartup(MAKEWORD(2,2), *wsa) != 0 {
        print("Error!");
    }
    listenfd = socket(AF_INET, SOCK_STREAM, 0);
    if listenfd < 0 {
        print("Error!");
    }
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    serv_addr.sin_port = htons(port);
    if bind(listenfd, cast(*sockaddr) *serv_addr, size_of(type_of(serv_addr))) < 0 {
        print("Error!");
    }
    if listen(listenfd, 64) < 0 {
        print("Error!");
    }

    length: int;
    while running {
        length = size_of(type_of(cli_addr));
        socketfd = accept(listenfd, cast(*sockaddr) *cli_addr, *length);
        if socketfd < 0 {
            print("Error!");
        }
        handle_request(socketfd);
        shutdown(socketfd, SD_BOTH);
    }
}
