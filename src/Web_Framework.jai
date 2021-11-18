Headers :: #type Table(string, string);
//------------------------------------------------------------------------------
// Request
Request_Method :: enum {
    GET;
    HEAD;
    POST;
    PUT;
    DELETE;
    CONNECT;
    OPTIONS;
    TRACE;
    PATCH;
}

Request :: struct {
    uri: struct {
        headers: Headers;
        method: Request_Method;
        scheme: string;
        path: string;
        query: string;
    }
    params: Table(string, string);
}

uninit :: (using req: *Request) {
    uninit(*uri.headers);
    uninit(*params);
}
request_method_from_string :: inline (method: string) -> Request_Method {
    if method == {
        case "GET";
            return .GET;
        case "POST";
            return .POST;
    }
    return .GET; // ???
}
//------------------------------------------------------------------------------
// Response
Response_Proc :: #type (req: *Request, res: *Response);

Response :: struct {
    headers: Headers;
    body: string;
    status: int;
}

uninit :: (using res: *Response) { uninit(*headers); }
set_header :: (using res: *Response, key: string, value: Any) {
    table_set(*headers, key, tprint("%", value));
}
make_header_string :: (using res: *Response) -> string {
    builder: String_Builder;
    for headers {
        append(*builder, tprint("%: %\r\n", it_index, it));
    }
    return builder_to_string(*builder);
}
http_status_to_string :: (status: int) -> string {
    if status == {
        case 200; return "OK";
        case 400; return "Bad Request";
        case 401; return "Unauthorized";
        case 403; return "Forbidden";
        case 404; return "Not Found";
        case 405; return "Method Not Allowed";
        case 418; return "I'm a teapot";
    }
    return "ERROR"; // ???
}
get_http_response_string :: inline (using res: *Response) -> string {
    return tprint("HTTP/1.0 % %\r\n%\r\n%", status, http_status_to_string(status), make_header_string(res), body);
}
respond :: (req: *Request, res: *Response, proc: Response_Proc) {
    new_context := context;
    push_context new_context {
        for before_plugins it(req, res);
        proc(req, res);
        for < after_plugins it(req, res);
    }
}
//------------------------------------------------------------------------------
// Plugin
Plugin_Proc :: #type (req: *Request, res: *Response);
Before_Plugin_Proc :: #type Plugin_Proc;
After_Plugin_Proc :: #type Plugin_Proc;

before_plugins: [..] Before_Plugin_Proc;
after_plugins: [..] After_Plugin_Proc;

before_route :: inline (proc: Before_Plugin_Proc) {
    array_add(*before_plugins, proc);
}
after_route :: inline (proc: After_Plugin_Proc) {
    array_add(*after_plugins, proc);
}
//------------------------------------------------------------------------------
// Route
ROUTE_PATH_SEPARATORS :: "/-.";

Route :: struct {
    method: Request_Method;
    response: Response_Proc;
}

routes: [..] Route;

route :: (method: Request_Method, path: string, response: Response_Proc) {
    r: Route;
    r.method = method;
    r.response = response;
    array_add(*routes, r);
}
//------------------------------------------------------------------------------
// Server
BUFFER_SIZE :: 65536;

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

        // parse request
        req: Request;
        defer uninit(*req);
        req_string := to_string(buffer.data);
        method_end := find_index_from_left(req_string, " ");
        if !method_end return;
        if slice(req_string, 0, method_end) == {
            case "GET"; req.uri.method = .GET;
            case "POST"; req.uri.method = .POST;
            case; req.uri.method = .PATCH; // ???
        }
        req_string = slice(req_string, method_end + 1, req_string.count);
        path_end := find_index_from_left(req_string, " ");
        if !path_end return;
        req.uri.path = slice(req_string, 0, path_end);
        req_string = slice(req_string, path_end + 1, req_string.count);
        http_end := find_index_from_left(req_string, "\r\n");
        if !http_end return;
        req_string = slice(req_string, http_end, req_string.count);
        for split(req_string, "\r\n") {
            kv := split(it, ": ");
            if kv.count == 2 table_add(*req.uri.headers, kv[0], kv[1]);
        }

        res: Response;
        defer uninit(*res);
        proc: Response_Proc;
        
        for routes {
            proc = it.response;
            break;
        }

        respond(*req, *res, proc);





        //req := make_request(buffer_string);
        //res := route_request(req);

        for 0..BUFFER_SIZE {
            buffer[it] = 0;
        }

        response := get_http_response_string(*res);
        memcpy(buffer.data, response.data, response.count);
        buffer[response.count] = 0;
        send(socket, buffer.data, cast(s32) response.count, 0);
    }
}
//------------------------------------------------------------------------------
#load "Winsock.jai";

#import "Hash_Table";
#import "String";
#import "Basic";
