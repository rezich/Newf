Headers :: #type Table(string, string);
//------------------------------------------------------------------------------
// Request
Query_Params :: #type Table(string, string);
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
        query_params: Query_Params;
        subdomain: string;
    }
    params: Table(string, string);
    form_data: Table(string, string);
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
HTTP_Status :: #type u16;
HTTP_Content_Type :: enum {
    HTML;
    JSON;
}

Response :: struct {
    headers: Headers;
    body: string;
    status: HTTP_Status;
}

uninit :: (using res: *Response) { uninit(*headers); }
Set_Header :: (key: string, value: Any) #expand {
    table_set(*`res.headers, key, tprint("%", value));
}
make_header_string :: (using res: *Response) -> string {
    builder: String_Builder;
    for headers {
        append(*builder, tprint("%: %\r\n", it_index, it));
    }
    return builder_to_string(*builder);
}
http_status_to_string :: (status: HTTP_Status) -> string {
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
    subdomain: string;
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
routes_match_subdomains := false;

route :: (method: Request_Method, path: string, response: Response_Proc) { route(method, "", path, response); }
route :: (method: Request_Method, subdomain: string, path: string, response: Response_Proc) {
    if subdomain != "" then routes_match_subdomains = true;
    r: Route;
    r.method = method;
    r.subdomain = subdomain;
    r.response = response;
    parse_route_path(*r, path);

    //for r.stretches print("S: % | %\n", it.type, it.text);
    //print("---\n");

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
            next_param_start := find_index_of_any_from_left(str, ":$");
            if next_param_start == 0 {
                next_param_end := find_index_from_left(str, #char "/");
                end = ifx next_param_end != -1 then next_param_end else str.count;
                new_param := slice(str, 1, end - 1);
                s: Route.Stretch;
                if !begins_with(str, ":") && !begins_with(str, "$") {
                    print("Route error, invalid param specifier\n");
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
Param :: (key: string) -> value: string = "", success: bool = true #must #expand {
    value, success := table_find(`req.params, key);
    if !success return success = false;
    return value;
}
Param_int :: (key: string) -> value: int = -1, success: bool = true #must #expand{
    string_value, key_success := table_find(`req.params, key);
    if !key_success return success = false;
    int_value, parse_success := parse_int(*string_value);
    if !parse_success return success = false;
    return int_value;
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
        print("%\n^^^\n", req_string);
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
                if kv.count == 2 {
                    Set(decode_form(kv[0]), decode_form(kv[1]));
                }
            }
        }
        // set builtin params
        Set("HOSTNAME", HOSTNAME);

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
            print("QUERY STRING: %\n", query_string);
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
            //for req.uri.query_params print("%: %\n", it_index, it);
            //print("--\n");
            //for req.params print("%: %\n", it_index, it);
        }
        else path_without_query_string = req.uri.path;
        //print("\n%\n", path_without_query_string);

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
                        str = ""; // hack?
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
                table_set(*req.params, "id", "108");
                for param, param_index: params {
                    table_set(*req.params, param_index, param);
                }
                proc = route.response;
                break;
            }
        }

        for before_plugins it(*req, *res);
        if proc then proc(*req, *res); else print("No proc...?\n");
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

templates: Table(string, Template);

init_template_system :: (relative_template_path: string = "/templates", extension: string = ".template") {
    working_directory := get_working_directory();
    template_path := tprint("%1%2", working_directory, relative_template_path);
    list := file_list(template_path, true);
    for list {
        if !ends_with(it, extension) continue;
        short_name := replace(replace(it, tprint("%/", template_path), ""), extension, "");
        contents, success := read_entire_file(it);
        if success {
            template: Template;
            found: bool;
            n := 0;
            
            while true {
                start := find_index_from_left(contents, "%{");
                if start < 0 break;

                end := find_index_from_left(contents, "}");
                if end < 0 break;

                if end < start {
                    print("ERROR PARSING TEMPLATE!\n");
                    break;
                }

                new_param := slice(contents, start + 2, end - start - 2);
                
                inserting_n: int;
                found, inserting_n = array_find(template.params, new_param);
                if !found {
                    array_add(*template.params, new_param);
                    inserting_n = n;
                    n += 1;
                }
                
                text_before := slice(contents, 0, start);
                if text_before.count > 0 {
                    before_text: Template_Piece;
                    before_text.type = .TEXT;
                    before_text.text = text_before;
                    array_add(*template.pieces, before_text);
                }

                param: Template_Piece;
                param.type = .PARAM;
                param.param_id = inserting_n;
                array_add(*template.pieces, param);

                contents = slice(contents, end + 1, contents.count);
            }

            text_after := slice(contents, 0, contents.count);
            if text_after.count > 0 {
                after_text: Template_Piece;
                after_text.type = .TEXT;
                after_text.text = text_after;
                array_add(*template.pieces, after_text);
            }
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
            table_add(*templates, short_name, template);
        }
        else print("failed to load template: %\n", it);
    }
}
Respond :: (status: HTTP_Status, body: string = "") #expand {
    `res.status = status;
    `res.body = body;
    `return;
}
Redirect :: (to: string) #expand {
    `res.status = 302;
    res := `res;
    Set_Header("Location", to);
    `return;
}
Redirect_To_Hostname :: () #expand {
    `res.status = 302;
    res := `res;
    Set_Header("Location", HOSTNAME);
    `return;
}
Tpl :: (template_name: string, args: ..Any) -> string #must #expand {
    template, template_exists := get_template(template_name);
    if !template_exists return tprint("-- TEMPLATE NOT FOUND: % --\n", template_name);
    if args.count > 0 && args.count != template.params.count {
        return tprint("-- Tpl ARGUMENT ERROR: % --", template_name);
    }
    req := `req;
    for args {
        Set(template.params[it_index], it);
    }
    return render_to_string(`req, template);
}
Render :: (template_name: string, content_type: HTTP_Content_Type = .HTML, status: HTTP_Status = 200) #expand {
    template, template_exists := get_template(template_name);
    if !template_exists {
        print("-- TEMPLATE NOT FOUND: % --\n", template_name);
        return;
    }
    content_type_string: string;
    if content_type == {
        case .HTML; content_type_string = "text/html; charset=utf-8";
        case .JSON; content_type_string = "text/json; charset=utf-8";
    }
    res := `res;
    Set_Header("Content-Type", content_type_string);
    `res.body = render_to_string(`req, template);
    `res.status = status;
}
get_template :: (name: string) -> template: *Template = null, success: bool = true #must {
    template := table_find_pointer(templates, name);
    if !template return success = false;
    return template;
}
render_to_string :: (req: *Request, template: *Template) -> string #must {
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
Set :: (key: string, value: Any) #expand {
    table_set(*`req.params, key, tprint("%", value));
}
//------------------------------------------------------------------------------
decode_url :: (text: string) -> string {
    builder: String_Builder;
    defer free_buffers(*builder);
    str := text;
    while str != "" {
        next_percent := find_index_from_left(str, #char "%");
        if next_percent == -1 || next_percent + 2 >= str.count {
            append(*builder, str);
            break;
        }
        if next_percent > 0 then append(*builder, slice(str, 0, next_percent));
        a := str[next_percent+1];
        if a >= #char "a" then a -= #char "a" - #char "A";
        if a >= #char "A" then a -= #char "A" - 10;
        else a -= #char "0";
        b := str[next_percent+2];
        if b >= #char "a" then b -= #char "a" - #char "A";
        if b >= #char "A" then b -= #char "A" - 10;
        else b -= #char "0";
        append(*builder, cast(u8) 16 * a + b);
        str = slice(str, next_percent + 3, str.count);
    }
    return builder_to_string(*builder);
}
decode_form :: (text: string) -> string {
    str := text;
    replace_chars(str, "+", #char " ");
    return decode_url(str);
}
is_hex_number :: inline (c: u32) -> bool {
    return (c >= #char "a" && c <= #char "f") || (c >= #char "A" && c <= #char "F") || is_number(c);
}
is_number :: inline (c: u32) -> bool {
    return (c >= #char "0" && c <= #char "9");
}
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
