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

handle_request :: inline (socket: Socket) {
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
    listen_socket, incoming_socket: Socket;
    client_address, server_address: sockaddr_in = ---;
    if WSAStartup(WINSOCK_VERSION, *wsa) != 0 {
        log("Failed to init WinSock!");
    }
    listen_socket = socket(AF_INET, SOCK_STREAM, 0);
    if listen_socket < 0 {
        log("failed to init socket!");
    }
    server_address.sin_family = AF_INET;
    server_address.sin_addr.s_addr = htonl(INADDR_ANY);
    server_address.sin_port = htons(port);
    if bind(listen_socket, cast(*sockaddr) *server_address, size_of(type_of(server_address))) < 0 {
        log("Failed to bind port!");
    }
    if listen(listen_socket, 64) < 0 {
        log("Failed to listen to port!");
    }

    length: int;
    while running {
        length = size_of(type_of(client_address));
        incoming_socket = accept(listen_socket, cast(*sockaddr) *client_address, *length);
        if incoming_socket < 0 {
            print("Error!");
        }
        else {
            handle_request(incoming_socket);
        }
        shutdown(incoming_socket, SD_BOTH);
    }
}
