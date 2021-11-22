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
    stretches: [..] Stretch;
    params: [..] string;

    Stretch :: struct {
        type: Type;
        text: string;

        Type :: enum {
            WILDCARD;
            PATH;
            PARAM;
        }
    }
}

routes: [..] Route;

route :: (method: Request_Method, path: string, response: Response_Proc) {
    r: Route;
    r.method = method;
    r.response = response;
    parse_route_path(*r, path);

    for r.stretches print("S: % | %\n", it.type, it.text);

    array_add(*routes, r);

    parse_route_path :: (r: *Route, path: string) {
        if path == "*" {
            s: Route.Stretch;
            s.type = .WILDCARD;
            array_add(*r.stretches, s);
            return;
        }
        if !begins_with(path, "/") {
            print("Route error, path must begin with a forward slash\n");
            return;
        }
        if ends_with(path, "/") && path.count > 1 {
            print("Route error, path must not end with forward slash\n");
            return;
        }

        str := path;
        end, next_param_start, next_param_end: int;
        found: bool;

        while str != "" {
            next_param_start := find_index_from_left(str, ":$");
            if next_param_start == 0 {
                next_param_end := find_index_from_left(str, #char "/");
                end = ifx next_param_end != -1 then next_param_end else str.count;
                new_param := slice(str, 1, end - 1);
                s: Route.Stretch;
                if !begins_with(str, ":") || !begins_with(str, "$") {
                    print("Rout error, invalid param specifier\n");
                    return;
                }
                s.type = Route.Stretch.Type.PARAM;
                array_add(*r.stretches, s);
                array_add(*r.params, new_param);
                str = slice(str, end, str.count);
            }
            else {
                end = ifx next_param_start != -1 then next_param_start else str.count;
                s: Route.Stretch;
                s.type = .PATH;
                s.text = slice(str, 0, end);
                array_add(*r.stretches, s);
                str = slice(str, end, str.count);
            }
        }
    }
}
param :: (key: string) -> string #expand {
    val, success := table_find(`req.params, key);
    if success then return val; else return "--ERROR--";
}
//------------------------------------------------------------------------------
// Server
BUFFER_SIZE :: 65536;

Server :: struct {
    port: u16;
    wsa: WSAData;
    running: bool;
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
            if kv.count == 2 table_add(*req.uri.headers, kv[0], kv[1]);
        }

        print("%\n", req);

        res: Response;
        defer uninit(*res);
        proc: Response_Proc;

        //TODO: routing
        for routes {
            table_set(*req.params, "id", "108");
            proc = it.response;
            break;
        }

        for before_plugins it(*req, *res);
        proc(*req, *res);
        for < after_plugins it(*req, *res);

        for 0..BUFFER_SIZE buffer[it] = 0;

        response := get_http_response_string(*res);
        memcpy(buffer.data, response.data, response.count);
        buffer[response.count] = 0;
        send(socket, buffer.data, cast(s32) response.count, 0);
    }
}
//------------------------------------------------------------------------------
// Template
Template_Piece :: struct {
    type: enum {
        TEXT;
        PARAM;
    }
    text: string;
    param_id: int;
}
Template :: struct {
    body: string;
    params: [..] string;
    pieces: [..] Template_Piece;
}
Template_Variables :: #type Table(string, string);

templates: Table(string, *Template);

init_template_system :: (relative_template_path: string = "/templates", extension: string = ".template") {
    working_directory := get_working_directory();
    template_path := tprint("%1%2", working_directory, relative_template_path);
    list := file_list(template_path, true);
    for list {
        if !ends_with(it, extension) then continue;
        short_name := replace(replace(it, tprint("%/", template_path), ""), extension, "");
        contents, success := read_entire_file(it);
        if success {
            parsed := parse(contents);
            // Debug
            /*write_string("\n\n---\n");
            for parsed.pieces {
                if it.type == {
                    case .TEXT;
                        write_string("TEXT: ");
                        write_string(it.text);
                        write_string("\n");
                    case .PARAM;
                        write_string("PARAM: ");
                        print("% (%)", it.param_id, parsed.params[it.param_id]);
                        write_string("\n");
                }
            }
            write_string("\n---\n\n");*/
            table_add(*templates, short_name, parsed);
        }
        else print("failed to load template: %\n", it);
    }

    parse :: (input: string) -> *Template {
        tpl := New(Template);

        str := input;
        found: bool;

        n := 0;
        
        while true {
            start := find_index_from_left(str, "%{");
            if start < 0 break;

            end := find_index_from_left(str, "}");
            if end < 0 break;

            if end < start {
                print("ERROR PARSING TEMPLATE!\n");
                break;
            }

            new_param := slice(str, start + 2, end - start - 2);
            
            inserting_n: int;
            found, inserting_n = array_find(tpl.params, new_param);
            if !found {
                array_add(*tpl.params, new_param);
                inserting_n = n;
                n += 1;
            }
            
            text_before := slice(str, 0, start);
            if text_before.count > 0 {
                before_text: Template_Piece;
                before_text.type = .TEXT;
                before_text.text = text_before;
                array_add(*tpl.pieces, before_text);
            }

            param: Template_Piece;
            param.type = .PARAM;
            param.param_id = inserting_n;
            array_add(*tpl.pieces, param);

            str = slice(str, end + 1, str.count);
        }

        text_after := slice(str, 0, str.count);
        if text_after.count > 0 {
            after_text: Template_Piece;
            after_text.type = .TEXT;
            after_text.text = text_after;
            array_add(*tpl.pieces, after_text);
        }

        return tpl;
    }
}
render :: (template_name: string) #expand {
    set_header(`res, "Content-Type", "text/html; charset=utf-8");
    `res.body = render_to_string(`req, template_name);
}
render_to_string :: (req: *Request, template_name: string) -> string #must {
    template, success := table_find(templates, template_name);
    if !success {
        print("failed to render template: %", template_name);
    }
    output_builder: String_Builder;
    
    for template.pieces {
        if it.type == {
            case .TEXT;
                append(*output_builder, it.text);
            case .PARAM;
                value, success := table_find(req.params, template.params[it.param_id]);
                append(*output_builder, ifx success then value else "!!PARAM ERROR!!");
        }
    }
    return builder_to_string(*output_builder);
}
set :: (key: string, value: Any) #expand {
    table_set(*`req.params, key, tprint("%", value));
}
set_from_render :: (key: string, template_name: string) #expand {
    table_set(*`req.params, key, render_to_string(`req, template_name));
}
//------------------------------------------------------------------------------
xprint :: (args: ..Any) -> string {
    builder: String_Builder;
    defer free_buffers(*builder);
    for args print_to_builder(*builder, tprint("%", it));
    return builder_to_string(*builder);
}
//------------------------------------------------------------------------------
#load "Winsock.jai";

#import "File_Utilities";
#import "File";
#import "Hash_Table";
#import "String";
#import "Basic";
