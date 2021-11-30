Headers :: #type Table(string, string);
Cookies :: #type Table(string, string);
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
        query_params: Table(string, string);
        subdomain: string;
    }
    form_data: Table(string, string);
    session: *Session;
    cookies: Cookies;
    raw: string;
    params: Table(string, string);
}

uninit :: (using req: *Request) {
    uninit(*uri.headers);
    uninit(*uri.query_params);
    uninit(*form_data);
    uninit(*cookies);
    uninit(*params);
}
//------------------------------------------------------------------------------
// Response
HTTP_Status :: #type u16;
HTTP_Content_Type :: enum {
    HTML;
    JSON;
}
Response :: struct {
    headers: Headers;
    cookies: Cookies;
    body: string;
    status: HTTP_Status;
    session: *Session;
    toasts: [..] Toast;

    Toast :: #type string;
}

uninit :: (using res: *Response) {
    uninit(*headers);
    uninit(*cookies);
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
ROUTE_PATH_SEPARATORS :: "/";
Route_Proc :: #type (*Request, *Response);
//#scope_file
Route :: struct {
    method: Request_Method;
    subdomain: string;
    response: Route_Proc;
    stretches: [..] Stretch;
    params: [..] string;

    Stretch :: struct { // Merriam-Webster, Entry 2, Definition 4a
        type: Type;
        text: string;

        Type :: enum {
            WILDCARD;
            PATH;
            PARAM;
        }
    }
}
//#scope_export
routes: [..] Route;
routes_match_subdomains := false;

route :: (method: Request_Method, path: string, response: Route_Proc) { route(method, "", path, response); }
route :: (method: Request_Method, subdomain: string, path: string, response: Route_Proc) {
    if subdomain != "" then routes_match_subdomains = true;
    r: Route;
    r.method = method;
    r.subdomain = subdomain;
    r.response = response;
    parse_route_path(*r, path);

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
            table_add(*templates, short_name, template);
        }
        else print("failed to load template: %\n", it);
    }
}
//------------------------------------------------------------------------------
// Session
Session :: struct {
    token: TOKEN;
    locator: Bucket_Locator;
    ended: bool;
    params: Table(string, string);

    TOKEN :: string;
}

sessions: Table(Session.TOKEN, *Session);
session_storage: Bucket_Array(Session, SESSIONS_PER_BUCKET, true);

begin_session :: (req: *Request, res: *Response) { //TODO: probably remove session from req
    if !req.session {
        session: Session;
        session.token = md5(tprint("%", get_time())); //TODO: lol
        session.locator = bucket_array_add(*session_storage, session);
        req.session = bucket_array_find_pointer(*session_storage, session.locator);
        res.session = req.session;
        table_add(*sessions, session.token, req.session);
        Set_Cookie(SESSION_TOKEN, session.token);
    }
}
load_or_begin_session :: (req: *Request, res: *Response, token: Session.TOKEN) {
    existing, found := table_find(sessions, token);
    if found && existing {
        req.session = existing;
        res.session = existing;
        Set_Cookie(SESSION_TOKEN, existing.token);
    }
    else begin_session(req, res);
}
end_session :: (req: *Request, res: *Response) {
    if req.session == null return;
    table_remove(*sessions, req.session.token);
    bucket_array_remove(*session_storage, req.session.locator);
    req.session = null;
    res.session = null;
    Unset_Cookie(SESSION_TOKEN);
}
//------------------------------------------------------------------------------
// Macros
Get :: (key: string) -> value: string = "", success: bool = true #must #expand {
    value, success := table_find(`req.params, key);
    if !success return success = false;
    return value;
}
Get_Int :: (key: string) -> value: int = -1, success: bool = true #must #expand {
    string_value, key_success := table_find(`req.params, key);
    if !key_success return success = false;
    int_value, parse_success := parse_int(*string_value);
    if !parse_success return success = false;
    return int_value;
}
Get_Cookie :: (key: string) -> value: string = "", success: bool = true #must #expand {
    value, success := table_find(`req.cookies, key);
    if !success return success = false;
    return value;
}
Get_Cookie_Int :: (key: string) -> value: int = -1, success: bool = true #must #expand {
    string_value, key_success := table_find(`req.cookies, key);
    if !key_success return success = false;
    int_value, parse_success := parse_int(*string_value);
    if !parse_success return success = false;
    return int_value;
}
Get_Header :: (key: string) -> value: string = "", success: bool = true #must #expand {
    value, success := table_find(`req.uri.headers, key);
    if !success return success = false;
    return value;
}
Get_Header_Int :: (key: string) -> value: int = -1, success: bool = true #must #expand {
    string_value, key_success := table_find(`req.uri.headers, key);
    if !key_success return success = false;
    int_value, parse_success := parse_int(*string_value);
    if !parse_success return success = false;
    return int_value;
}
Get_Session :: (key: string) -> value: string = "", success: bool = true #must #expand {
    req := `req;
    if !req.session return success = false;
    value, success := table_find(req.session.params, key);
    if !success return success = false;
    return value;
}
Get_Session_Int :: (key: string) -> value: int = -1, success: bool = true #must #expand {
    req := `req;
    if !req.session return success = false;
    string_value, key_success := table_find(req.session.params, key);
    if !key_success return success = false;
    int_value, parse_success := parse_int(*string_value);
    if !parse_success return success = false;
    return int_value;
}
Set :: (key: string, value: Any) #expand { req := `req; Set(key, tprint("%", value)); }
Set :: (key: string, value: string) #expand {
    table_set(*`req.params, key, value);
}
Set_Cookie :: (key: string, value: Any) #expand { req, res := `req, `res; Set_Cookie(key, tprint("%", value)); }
Set_Cookie :: (key: string, value: string) #expand {
    table_set(*`res.cookies, key, value);
}
Unset_Cookie :: (key: string) #expand { req, res := `req; `res; Set_Cookie(key, "INVALID_TOKEN; expires=Thu, 01 Jan 1970 00:00:00 GMT"); }
Set_Header :: (key: string, value: Any) #expand { req := `req; Set_Header(tprint("%", value)); }
Set_Header :: (key: string, value: string) #expand {
    table_set(*`res.headers, key, value);
}
Set_Session :: (key: string, value: Any) #expand { req, res, sessions, session_storage := `req, `res, `sessions, `session_storage; Set_Session(key, tprint("%", value)); }
Set_Session :: (key: string, value: string) #expand {
    req, res, sessions, session_storage := `req, `res, `sessions, `session_storage;
    begin_session(req, res);
    table_set(*req.session.params, key, value);
}
Respond :: (body: string = "", content_type: HTTP_Content_Type = .HTML, status: HTTP_Status = 200) #expand {
    content_type_string: string;
    if content_type == {
        case .HTML; content_type_string = "text/html; charset=utf-8";
        case .JSON; content_type_string = "text/json; charset=utf-8";
    }
    res := `res;
    Set_Header("Content-Type", content_type_string);
    res.body = body;
    res.status = 200;
    `return;
}
Redirect :: (to: string, args: ..Any) #expand {
    _to := "";
    if args.count > 0 then _to = tprint(to, ..args); else _to = to;
    res := `res;
    res.status = 302;
    Set_Header("Location", _to);
    `return;
}
Reroute :: (to: (req: *Request, res: *Response)) #expand {
    req, res := `req, `res;
    to(req, res);
    `return;
}
Render :: (template_name: string, args: ..Any) -> string #must #expand {
    req, res := `req, `res;
    template := table_find_pointer(templates, template_name);
    if !template return tprint("-- TEMPLATE NOT FOUND: % --\n", template_name);
    if args.count > 0 && args.count != template.params.count {
        return tprint("-- RENDER ARGUMENT ERROR: % --\n", template_name);
    }
    for args Set(template.params[it_index], it);
    builder: String_Builder; defer free_buffers(*builder);
    for template.pieces {
        if it.type == {
            case .TEXT;
                append(*builder, it.text);
            case .PARAM;
                param_name := template.params[it.param_id];
                value, found := Get(param_name);
                /*if !res.rendered_toasts && param_name == "toasts" {
                    _, toast_template_exists := table_find(templates, TOAST_TEMPLATE_NAME);
                    res.rendered_toasts = true;
                    if toast_template_exists then value = Render_Each(res.toasts, #code Render_It(TOAST_TEMPLATE_NAME, it));
                }*/
                append(*builder, ifx found then value else tprint("[!! MISSING PARAM: % !!]", param_name));
        }
    }
    return builder_to_string(*builder);
}
Render_Each :: (items: $T, code: Code) -> string #expand {
    req, res := `req, `res;
    builder: String_Builder; defer free_buffers(*builder);
    for items {
        #insert_internal code;
    }
    return builder_to_string(*builder);

    Render_It :: (template_name: string, args: ..Any) #expand {
        req, res := `req, `res;
        append(*`builder, Render(template_name, ..args));
    }
}
Render_Toasts :: (template_name: string) #expand {
    req, res := `req, `res;
    ;
}
Toast :: (message: string) #expand {
    array_add(*`res.toasts, message);
}
/*Route :: (method: Request_Method, path: string, code: Code) #expand {
    route(method, path, (req: *Request, res: *Response) {
        #insert_internal code;
    });
}
Route :: (method: Request_Method, subdomain: string, path: string, code: Code) #expand {
    route(method, subdomain, path, (req: *Request, res: *Response) {
        #insert_internal code;
    });
}*/
//------------------------------------------------------------------------------
// Utils
bucket_array_find_pointer :: (using array: *Bucket_Array, locator: Bucket_Locator) -> *array.type {
    bucket := all_buckets[locator.bucket_index];
    assert(bucket.occupied[locator.slot_index] == true);
    result := *bucket.data[locator.slot_index];
    return result;
}
decode_url :: (text: string) -> string {
    builder: String_Builder; defer free_buffers(*builder);
    str := text;
    while str != "" {
        next_percent := find_index_from_left(str, #char "%");
        if next_percent == -1 || next_percent + 2 >= str.count {
            append(*builder, str);
            break;
        }
        if next_percent > 0 then append(*builder, slice(str, 0, next_percent));
        a := str[next_percent+1];
        b := str[next_percent+2];
        if is_hex_number(a) && is_hex_number(b) {
            if a >= #char "a" then a -= #char "a" - #char "A";
            if a >= #char "A" then a -= #char "A" - 10;
            else a -= #char "0";
            if b >= #char "a" then b -= #char "a" - #char "A";
            if b >= #char "A" then b -= #char "A" - 10;
            else b -= #char "0";
            append(*builder, cast(u8) 16 * a + b);
        }
        else append(*builder, slice(str, next_percent, next_percent + 2));
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
    builder: String_Builder; defer free_buffers(*builder);
    for args print_to_builder(*builder, tprint("%", it));
    return builder_to_string(*builder);
}
//------------------------------------------------------------------------------
#load "Server.jai";

#import "File_Utilities";
#import "Bucket_Array";
#import "Hash_Table";
#import "Atomics";
#import "Thread";
#import "System";
#import "String";
#import "Basic";
#import "File";
#import "md5";
