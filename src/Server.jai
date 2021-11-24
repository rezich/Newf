//------------------------------------------------------------------------------
// Server
BUFFER_SIZE :: 65536;

Server :: struct {
    port: u16;
    wsa: WSAData;
    running: bool;
    thread_group: Thread_Group;
}

listen :: (port: u16=80) {
    server: Server;
    server.port = port;
    num_cpus := get_number_of_processors();
    #if OS == .WINDOWS || OS == .LINUX then num_cpus /= 2;
    num_threads := max(num_cpus-1, 2);
    print("Creating server with % threads.\n", num_threads);
    init(*server.thread_group, num_threads, process_client);
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
        return;
    }
    defer WSACleanup();
    listen_socket = socket(AF_INET, SOCK_STREAM, 0);
    if listen_socket < 0 {
        log("failed to init socket!");
        return;
    }
    server_address.sin_family = AF_INET;
    server_address.sin_addr.s_addr = htonl(INADDR_ANY);
    server_address.sin_port = htons(port);
    {
        socket_mode: u32 = 1;
        if ioctlsocket(listen_socket, FIONBIO, *socket_mode) < 0 log("Failed to set socket mode!");
    }
    if bind(listen_socket, cast(*sockaddr) *server_address, size_of(type_of(server_address))) < 0 {
        log("Failed to bind port!");
        return;
    }
    if listen(listen_socket, 64) < 0 {
        log("Failed to listen to port!");
        return;
    }

    length: int;
    while running {
        length = size_of(type_of(client_address));
        incoming_socket = accept(listen_socket, cast(*sockaddr) *client_address, *length);
        defer shutdown(incoming_socket, SD_BOTH);
        if incoming_socket < 0 then print("Error!");
        else handle_request(incoming_socket);
    }

    handle_request :: inline (socket: Socket) {
        buffer: [BUFFER_SIZE + 1] u8;
        nbytes := recv(socket, buffer.data, BUFFER_SIZE, 0);
        if nbytes <= 0 return;
        if nbytes > 0 && nbytes < BUFFER_SIZE then buffer[nbytes] = 0;
        else buffer[0] = 0;

        // parse request
        req: Request;
        defer uninit(*req);
        req_string := to_string(buffer.data);
        print("%\n", req_string);
        method_end := find_index_from_left(req_string, " ");
        if method_end < 0 return;
        if slice(req_string, 0, method_end) == {
            case "GET"; req.uri.method = .GET;
            case "POST"; req.uri.method = .POST;
            case; req.uri.method = .PATCH; // ???
        }
        req_string = slice(req_string, method_end + 1, req_string.count);
        path_end := find_index_from_left(req_string, " ");
        if path_end < 0 return;
        req.uri.path = slice(req_string, 0, path_end);
        req_string = slice(req_string, path_end + 1, req_string.count);
        http_end := find_index_from_left(req_string, "\r\n");
        if http_end < 0 return;
        req_string = slice(req_string, http_end, req_string.count);
        for split(req_string, "\r\n") {
            kv := split(it, ": ");
            if kv.count == 2 {
                table_add(*req.uri.headers, kv[0], kv[1]);
                // parse subdomain
                if kv[0] == "Host" {
                    found, left := split_from_left(kv[1], HOSTNAME);
                    if found && left.count > 0 then req.uri.subdomain = slice(left, 0, left.count-1);
                }
            }
            else {
                kv = split(it, "=");
                if kv.count == 2 Set(decode_form(kv[0]), decode_form(kv[1]));
            }
        }

        res: Response;
        defer uninit(*res);
        proc: Response_Proc;

        params: Table(string, string);
        defer uninit(*params);

        // parse query string & ignore it for routing
        path_without_query_string: string;
        query_string_begin := find_index_from_left(req.uri.path, #char "?");
        if query_string_begin >= 0 {
            path_without_query_string = slice(req.uri.path, 0, query_string_begin);
            query_string := decode_url(slice(req.uri.path, query_string_begin+1, req.uri.path.count));
            req.uri.query = query_string;
            for split(query_string, "&") {
                second: *string;
                kv := split(it, "=");
                if kv.count == {
                    case 1; second = *kv[0];
                    case 2; second = *kv[1];
                }
                table_set(*req.uri.query_params, kv[0], <<second);
                Set(kv[0], <<second);
            }
        }
        else path_without_query_string = req.uri.path;

        // routing
        for route: routes {
            if req.uri.method != route.method continue;
            if routes_match_subdomains && req.uri.subdomain != route.subdomain && route.subdomain != "*" continue;
            table_reset(*params);
            str := path_without_query_string;
            n := 0;
            current_param := 0;
            end_of_param: int;
            while str != "" && n < route.stretches.count {
                stretch := *route.stretches[n];
                defer n += 1;
                if stretch.type == {
                    case .WILDCARD;
                        str = "";
                    case .PATH;
                        if !begins_with(str, stretch.text) continue;
                        str = slice(str, stretch.text.count, str.count);
                    case .PARAM;
                        end_of_param := find_index_of_any_from_left(str, ROUTE_PATH_SEPARATORS);
                        if end_of_param < 0 then end_of_param = str.count;
                        if end_of_param == 0 break;
                        table_add(*params, route.params[current_param], slice(str, 0, end_of_param));
                        str = slice(str, end_of_param, str.count);
                        current_param += 1;
                }
            }
            if str == "" && n == route.stretches.count {
                for params table_set(*req.params, it_index, it);
                proc = route.response;
                break;
            }
        }

        // set builtin params
        Set("HOSTNAME", HOSTNAME);

        // process client
        for before_plugins it(*req, *res);
        if proc then proc(*req, *res); else print("No proc...?\n");
        for after_plugins it(*req, *res);

        for 0..BUFFER_SIZE buffer[it] = 0;

        response := get_http_response_string(*res);
        memcpy(buffer.data, response.data, response.count);
        buffer[response.count] = 0;
        send(socket, buffer.data, cast(s32) response.count, 0);
        reset_temporary_storage();
    }
}
get_http_response_string :: inline (using res: *Response) -> string {
    header_string: string;
    builder: String_Builder; defer free_buffers(*builder);
    for headers append(*builder, tprint("%: %\r\n", it_index, it));
    header_string = builder_to_string(*builder);
    return tprint("HTTP/1.0 % %\r\n%\r\n%", status, get_http_status_string(status), header_string, body);
}
get_http_status_string :: (status: HTTP_Status) -> string {
    if status == {
        case 100; return "Continue"; case 101; return "Switching Protocols";
        case 103; return "Early Hints";
        case 200; return "OK"; case 201; return "Created"; case 202; return
        "Accepted"; case 204; return "No Content"; case 205; return
        "Reset Content"; case 206; return "Partial Content";
        case 300; return "Multiple Choice"; case 301; return "Moved Permanently";
        case 302; return "Found"; case 303; return "See Other"; case 304; return
        "Not Modified"; case 307; return "Temporary Redirect"; case 308; return
        "Permanent Redirect";
        case 400; return "Bad Request"; case 401; return "Unauthorized"; case
        403; return "Forbidden"; case 404; return "Not Found"; case 405; return
        "Method Not Allowed"; case 406; return "Not Acceptable"; case 408;
        return "Request Timeout"; case 409; return "Conflict"; case 410; return
        "Gone"; case 411; return "Length Required"; case 412; return
        "Precondition Failed"; case 413; return "Payload Too Large"; case 414;
        return "URI Too Long"; case 415; return "Unsupported Media Type"; case
        416; return "Range Not Satisfiable"; case 417; return
        "Expectation Failed"; case 418; return "I'm a teapot"; case 421; return
        "Misdirected Request"; case 426; return "Upgrade Required"; case 428;
        return "Precondition Required"; case 429; return "Too Many Requests";
        case 431; return "Request Header Fields Too Large"; case 451; return 
        "Unavailable For Legal Reasons";
        case 500; return "Internal Server Error"; case 501; return
        "Not Implemented"; case 502; return "Bad Gateway"; case 503; return
        "Service Unavailable"; case 504; return "Gateway Timeout"; case 505;
        return "HTTP Version Not Supported"; case 506; return
        "Variant Also Negotiates"; case 510; return "Not Extended"; case 511;
        return "Network Authentication Required";
    }
    return "";
}
//------------------------------------------------------------------------------
// Client
Client :: struct {
    req: Request;
    res: Response;
}

#load "Winsock.jai";
