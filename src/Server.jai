BUFFER_SIZE :: 1024 * 1024 * 4;
REQUEST_BUFFER_SIZE :: 65536;
MAX_THREADS :: 8;
TIMEOUT_SECONDS :: 10;

Buffer :: #type [BUFFER_SIZE+1] u8;
Request_Buffer :: #type [REQUEST_BUFFER_SIZE+1] u8;

server_requested_shutdown := false;

Server :: struct {
    port:         u16;
    wsa:          WSAData;
    running:      bool;
    thread_group: Thread_Group;
}

listen :: (
    listen_port      := 80,
    before           := #code,null,
    after            := #code,null,
    $POORLY_THREADED := false,
    caller_code      := #caller_code
) #expand {
    using server: Server;
    port = cast(u16) listen_port;
    num_threads := 1;
    #if POORLY_THREADED {
        num_cpus := get_number_of_processors();
        #if OS == .WINDOWS || OS == .LINUX then num_cpus /= 2;
        num_threads = max(num_cpus-1, 2);
    }
    print("Starting HTTP server with %1 thread%2 on port %3.\n",
    /* 1 */ num_threads,
    /* 2 */ ifx num_threads != 1 then "s",
    /* 3 */ port
    );
    #if POORLY_THREADED {
        init(*thread_group, num_threads, resolve_in_thread, enable_work_stealing=true);
        thread_group.name = "server";
        thread_group.logging = true;
    }
// this goofy thing prevents CTRL+C from killing the server immediately, so we can clean up & stuff
    {
        kernel32 :: #system_library "kernel32";
        SetConsoleCtrlHandler  :: (HandlerRoutine: (fdwCtrlType: u32) -> s32, Add: s32 ) -> s32 #foreign kernel32;
        Routine :: (fdwCtrlType: u32) -> s32 #c_call {
            if  fdwCtrlType == xx 0 ||
                fdwCtrlType == xx 1 ||
                fdwCtrlType == xx 2 ||
                fdwCtrlType == xx 5 ||
                fdwCtrlType == xx 6
            {
                write_string("\n\nShutting server down...\n\n");
                server_requested_shutdown = true;
                return xx 1;
            }
            return xx 0;
        }
        SetConsoleCtrlHandler(xx Routine, 1);
    }
    running = true;
    listen_socket, incoming_socket: Socket;
    client_address, server_address: sockaddr_in = ---;
    if WSAStartup(WINSOCK_VERSION, *wsa) != 0 { log("Failed to init WinSock!"); return; }
    defer WSACleanup();
    listen_socket = socket(AF_INET, SOCK_STREAM, 0);
    if listen_socket < 0 { log("failed to init socket!"); return; }
    server_address.sin_family = AF_INET;
    server_address.sin_addr.s_addr = htonl(INADDR_ANY);
    server_address.sin_port = htons(port);
    {
        socket_mode: u32 = 1;
        if ioctlsocket(listen_socket, FIONBIO, *socket_mode) < 0 log("Failed to set socket mode!");
    }
    if bind(listen_socket, cast(*sockaddr) *server_address, size_of(type_of(server_address))) < 0 { log("Failed to bind port!"); return; }
    if listen(listen_socket, 64) < 0 { log("Failed to listen to port!"); return; }
    #if POORLY_THREADED { start(*thread_group); defer shutdown(*thread_group); }
    length: int;
    while running && !server_requested_shutdown {
        #if POORLY_THREADED {
            results := get_completed_work(*thread_group);
            for results {
                using r := cast(*Request_Resolution(Client)) it;
                deinit(*req); deinit(*res);
                free(r);
                #insert,scope(caller_code) after;
            }
            length = size_of(type_of(client_address));
            incoming_socket = accept(listen_socket, cast(*sockaddr) *client_address, *length);
            if incoming_socket != INVALID_SOCKET {
                #insert,scope(caller_code) before;
                work := New(Request_Resolution(Client));
                work.client.socket = incoming_socket;
                add_work(*thread_group, work, tprint("%", incoming_socket));
            }
        } else {
            length = size_of(type_of(client_address));
            incoming_socket = accept(listen_socket, cast(*sockaddr) *client_address, *length);
            if incoming_socket != INVALID_SOCKET {
                #insert,scope(caller_code) before;
                using work := New(Request_Resolution);
                client.socket = incoming_socket;
                resolve(work);
                deinit(*req); deinit(*res);
                free(work);
                #insert,scope(caller_code) after;
            }
        }
    }
}
get_http_response_string :: inline (using res: *Response) -> string {
    header_string: string;
    builder: String_Builder;
    for headers append(*builder, tprint("%: %\r\n", it_index, it));
    for cookies append(*builder, tprint("Set-Cookie: %=%; Path=/\r\n", it_index, it));
    header_string = builder_to_string(*builder, allocator=temp);
    return tprint("HTTP/1.0 % %\r\n%\r\n%", status, get_http_status_string(status), header_string, body);
}
get_http_status_string :: (status: HTTP_Status) -> string {
    if status == {
        case 100; return "Continue"; case 101; return "Switching Protocols";
        case 103; return "Early Hints";
        case 200; return "OK"; case 201; return "Created"; case 202; return
        "Accepted"; case 204; return "No Content"; case 205; return
        "Reset Content"; case 206; return "Partial Content";
        case 300; return "Multiple Choice"; case 301;
        return "Moved Permanently"; case 302; return "Found"; case 303; return
        "See Other"; case 304; return "Not Modified"; case 307; return
        "Temporary Redirect"; case 308; return "Permanent Redirect";
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
resolve_in_thread :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
    return resolve(cast(*Request_Resolution(Client)) work);
}
resolve :: (request_resolution: *$T/Request_Resolution) -> Thread_Continue_Status {
    using request_resolution;

    defer memory_visualizer_per_frame_update();
    defer reset_temporary_storage();
    defer shutdown(client.socket, SD_BOTH);

    request_buffer: Request_Buffer;
    waiting := true;
    start_time := get_time();
    while waiting {
        current_time := get_time();
        if server_requested_shutdown || current_time - start_time >= TIMEOUT_SECONDS { log("timed out."); return .CONTINUE; }
        bytes_received := recv(client.socket, request_buffer.data, REQUEST_BUFFER_SIZE, 0);
        if bytes_received < 0 {
            err := WSAGetLastError();
            if err == {
                case WSAEWOULDBLOCK; continue;
                case; log("recv error: %", err); return .CONTINUE;
            };
        }
        if bytes_received < REQUEST_BUFFER_SIZE then request_buffer[bytes_received] = 0;
        else request_buffer[REQUEST_BUFFER_SIZE] = 0;
        waiting = false;
    }

    new_context := context;
    new_context.reqres = request_resolution;
    push_context new_context {
        // parse request
        req.raw = to_string(request_buffer.data);
        req_string := req.raw;
        log("---------- ---------- ---------- ----------");
        method_end := find_index_from_left(req_string, " ");
        if method_end < 0 return .CONTINUE;
        if slice(req_string, 0, method_end) == {
            case "GET"; req.uri.method = .GET;
            case "POST"; req.uri.method = .POST;
            case; req.uri.method = .PATCH; // ???
        }
        req_string = slice(req_string, method_end + 1, req_string.count);
        path_end := find_index_from_left(req_string, " ");
        if path_end < 0 return .CONTINUE;
        req.uri.path = slice(req_string, 0, path_end);
        req_string = slice(req_string, path_end + 1, req_string.count);
        http_end := find_index_from_left(req_string, "\r\n");
        if http_end < 0 return .CONTINUE;
        req_string = slice(req_string, http_end, req_string.count);

        section: enum {
            HEADERS;
            BODY;
        } = .HEADERS; //TODO
        parse_body := false;

        for split(req_string, "\r\n") {
            kv := split(it, ": ");
            if kv.count == 2 {
                table_add(*req.uri.headers, kv[0], kv[1]);
                // parse subdomain
                if kv[0] == {
                    case "Host";
                        found, left := split_from_left(kv[1], HOSTNAME);
                        if found && left.count > 0 then req.uri.subdomain = slice(left, 0, left.count-1);
                    case "Content-Type";
                        if kv[1] == "application/x-www-form-urlencoded" then parse_body = true;
                    case "Cookie";
                        for split(kv[1], "; ") {
                            kv := split(it, "=");
                            if kv.count == 2 {
                                if kv[0] == {
                                    case SESSION_TOKEN; load_or_reset_session(kv[1]);
                                    case UNSEEN_TOASTS_TOKEN; for split(decode_uri_component(kv[1]), UNSEEN_TOASTS_SEPARATOR) toast(it);
                                }
                                table_add(*req.cookies, kv[0], kv[1]);
                            }
                        }
                }
            }
            else if parse_body {
                for split(it, "&") {
                    kv = split(it, "=");
                    if kv.count == 2 {
                        key := decode_form(kv[0]);
                        value := decode_form(kv[1]);
                        table_set(*req.form_data, key, value);
                        param_set(key, value);
                    }
                }
            }
        }
        cookie_unset(UNSEEN_TOASTS_TOKEN);

        proc: Route.Proc;
        /*cache_filename := "";
        should_read_from_cache := false;
        should_write_to_cache := false;*/
        params: Table(string, string);
        defer deinit(*params);

        // parse query string & ignore it for routing
        path_without_query_string: string;
        query_string_begin := find_index_from_left(req.uri.path, #char "?");
        if query_string_begin >= 0 {
            path_without_query_string = slice(req.uri.path, 0, query_string_begin);
            query_string := decode_uri_component(slice(req.uri.path, query_string_begin+1, req.uri.path.count));
            req.uri.query = query_string;
            for split(query_string, "&") {
                second: *string;
                kv := split(it, "=");
                if kv.count == {
                    case 1; second = *kv[0];
                    case 2; second = *kv[1];
                }
                table_set(*req.uri.query_params, kv[0], <<second);
                param_set(kv[0], <<second);
            }
        }
        else path_without_query_string = req.uri.path;

        // routing
        for * route: routes {
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
                        end_of_param := find_index_of_any_from_left(str, Route.PATH_SEPARATORS);
                        if end_of_param < 0 then end_of_param = str.count;
                        if end_of_param == 0 break;
                        table_add(*params, route.params[current_param], slice(str, 0, end_of_param));
                        str = slice(str, end_of_param, str.count);
                        current_param += 1;
                }
            }
            if str == "" && n == route.stretches.count {
                for params table_set(*req.params, it_index, it);

                /*if route.cache_settings.seconds != 0 {
                    cache_filename = get_cached_rendering_filename_for_route(route);
                    path := path_strip_filename(cache_filename);
                    make_directory_if_it_does_not_exist(path);
                    now := current_time_consensus();
                    log(#string XX
last_cached:                          %1
cache_settings.seconds:               %2
last_cached + cache_settings.seconds: %3
now:                                  %4
XX,                 /* 1 */ route.last_cached,
                    /* 2 */ route.cache_settings.seconds,
                    /* 3 */ route.last_cached + to_apollo(xx route.cache_settings.seconds),
                    /* 4 */ now
                    );
                    if route.last_cached == APOLLO_TIME_INVALID || route.last_cached + to_apollo(xx route.cache_settings.seconds) <= now {
                        should_write_to_cache = true;
                    }
                    else {
                        if file_exists(cache_filename) {
                            should_read_from_cache = true;
                        }
                        else should_write_to_cache = true;
                    }
                    if should_read_from_cache then route.last_cached = now;

                    if should_read_from_cache then log("reading from cache");
                    if should_write_to_\cache then log("writing to cache");

                    log("route: %\ncache: %", route.path, cache_filename);
                }*/

                proc = route.proc;
                break;
            }
        }

        // process client
        for before_routes it();
        if proc then proc(); else log("No proc...? %\n", req.uri.path);
        for after_routes it();

        response_string : /*string;
        if should_read_from_cache then response_string = read_entire_file(cache_filename);
        else response_string*/ = get_http_response_string(*res);
        //if should_write_to_cache write_entire_file(cache_filename, response_string);
        buffer_length := cast(s32) response_string.count;
        for 0..BUFFER_SIZE buffer[it] = 0;
        memcpy(buffer.data, response_string.data, buffer_length);
        buffer[buffer_length] = 0;
        if send(client.socket, buffer.data, buffer_length, 0) < 0 log("ERROR");
    }
    
    return .CONTINUE;
}

#import "System";
#import "Thread";
#load "Winsock.jai";

