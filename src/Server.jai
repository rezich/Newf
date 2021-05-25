#load "../modules/winsock.jai";

// this needs serious refactoring but hey it works

BUFFER_SIZE :: 8096;

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
    buffer: [BUFFER_SIZE + 1] u8;
    nbytes := recv(socket, buffer.data, BUFFER_SIZE, 0);
    if nbytes <= 0 {
        print("Error! 0 bytes");
    }
    if nbytes > 0 && nbytes < BUFFER_SIZE {
        buffer[nbytes] = 0;
    }
    else {
        buffer[0] = 0;
    }

    buffer_string := to_string(buffer.data);

    req := make_request(buffer_string);
    res := route_request(req);

    for 0..BUFFER_SIZE {
        buffer[it] = 0;
    }

    response := get_http_response_string(res);
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
