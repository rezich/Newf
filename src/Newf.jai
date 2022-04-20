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
    cookies: Cookies;
    raw: string;
    params: Table(string, string);
    finished_routing: bool;
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
    rendered_toasts: bool;

    Toast :: #type string;
}
uninit :: (using res: *Response) {
    uninit(*headers);
    uninit(*cookies);
}
//------------------------------------------------------------------------------
// API - Cookie
get_cookie :: (req: *Request, key: string) -> value := "", success := true {
    value, success := table_find(req.cookies, key);
    if !success return success = false;
    return decode_uri_component(value), success = value != "";
}
get_cookie_int :: (req: *Request, key: string) -> value := -1, success: bool=true {
    string_value, key_success := table_find(req.cookies, key);
    if !key_success || string_value == "" return success = false;
    string_value = decode_uri_component(string_value);
    int_value, parse_success := parse_int(*string_value);
    if !parse_success return success = false;
    return int_value;
}
set_cookie :: (res: *Response, key: string, value: Any) { set_cookie(res, key, tprint("%", value)); }
set_cookie :: (res: *Response, key: string, value: string) {
    table_set(*res.cookies, key, encode_uri_component(value));
}
unset_cookie :: (res: *Response, key: string) {
    table_set(*res.cookies, key, "INVALID_TOKEN; expires=Thu, 01 Jan 1970 00:00:00 GMT");
}
//------------------------------------------------------------------------------
// API - Header
get_header :: (req: *Request, key: string) -> value := "", success := true {
    value, success := table_find(req.uri.headers, key);
    if !success return success = false;
    return value;
}
get_header_int :: (req: *Request, key: string) -> value := -1, success: bool=true {
    string_value, key_success := table_find(req.uri.headers, key);
    if !key_success || string_value == "" return success = false;
    int_value, parse_success := parse_int(*string_value);
    if !parse_success return success = false;
    return int_value;
}
set_header :: (res: *Response, key: string, value: Any) { set_header(res, tprint("%", value)); }
set_header :: (res: *Response, key: string, value: string) {
    table_set(*res.headers, key, value);
}
//------------------------------------------------------------------------------
// API - Session
Get_Session :: (key: string) -> value: string, success: bool #expand {
    value, success := get_session(`res, key);
    return value, success;
}
Get_Session_Int :: (key: string) -> value: int, success: bool #expand {
    value, success := get_session_int(`res, key);
    return value, success;
}
Set_Session :: (key: string, value: Any) #expand { set_session(`res, key, value); }
Set_Session :: (key: string, value: string) #expand { set_session(`res, key, value); }
#scope_module
get_session :: (res: *Response, key: string) -> value := "", success := true {
    if !res.session return success = false;
    value, success := table_find(res.session.params, key);
    if !success return success = false;
    return value, success = value != "";
}
get_session_int :: (res: *Response, key: string) -> value := -1, success := true {
    if !res.session return success = false;
    string_value, key_success := table_find(res.session.params, key);
    if !key_success || string_value == "" return success = false;
    int_value, parse_success := parse_int(*string_value);
    if !parse_success return success = false;
    return int_value;
}
set_session :: (res: *Response, key: string, value: Any) { set_session(res, key, sprint("%", value)); }
set_session :: (res: *Response, key: string, value: string) {
    begin_session(res);
    table_set(*res.session.params, key, value);
}
#scope_export
//------------------------------------------------------------------------------
// API - Routing
get :: (req: *Request, key: string) -> value := "", success := true {
    value, success := table_find(req.params, key);
    if !success return success = false;
    return value, success = value != "";
}
get_int :: (req: *Request, key: string) -> value := -1, success: bool=true {
    string_value, key_success := table_find(req.params, key);
    if !key_success || string_value == "" return success = false;
    int_value, parse_success := parse_int(*string_value);
    if !parse_success return success = false;
    return int_value;
}
set :: (req: *Request, key: string, value: Any) { set(req, key, tprint("%", value)); }
set :: (req: *Request, key: string, value: string) {
    table_set(*req.params, key, value);
}
Respond :: (body: string = "", content_type: HTTP_Content_Type=.HTML, status: HTTP_Status=200) #expand {
    payload := `payload; using payload;
    content_type_string: string;
    if content_type == {
        case .HTML; content_type_string = "text/html; charset=utf-8";
        case .JSON; content_type_string = "text/json; charset=utf-8";
    }
    set_header(res, "Content-Type", content_type_string);
    res.body = body;
    res.status = 200;
    `return;
}
Redirect :: (to: string, args: ..Any) #expand {
    res := `res;
    _to := "";
    if args.count > 0 then _to = tprint(to, ..args); else _to = to;
    res.status = 302;
    set_header(res, "Location", _to);
    `return;
}
Reroute :: (to: Route.Proc) #expand { //TODO: remove
    to(`payload);
    `return;
}
Render :: (template_name: string, args: ..Any) -> string #must #expand {
    return render(`payload, template_name, ..args);
}
Render_Each :: (items: $T, code: Code, when_empty: string = "") -> string #expand {
    payload := `payload; using payload;
    if !items.count return when_empty;
    builder: String_Builder; defer free_buffers(*builder);
    for items { #insert_internal code; }
    return builder_to_string(*builder);

    Render_It :: (template_name: string, args: ..Any) #expand {
        append(*`builder, Render(template_name, ..args));
    }
}
Toast :: (message: string) #expand {
    toast(`res, message);
}
#scope_module
toast :: (res: *Response, message: string) {
    array_add(*res.toasts, message);
}
render :: (using payload: Route.Payload, template_name: string, args: ..Any) -> string #must {
    if !templates_initialized init_templates();
    template := table_find_pointer(templates, template_name);
    if !template return tprint("-- TEMPLATE NOT FOUND: % --\n", template_name);
    if args.count > 0 && args.count != template.params.count {
        return tprint("-- RENDER ARGUMENT ERROR: % --\n", template_name);
    }
    for args set(req, template.params[it_index], it);
    builder: String_Builder; defer free_buffers(*builder);
    for template.pieces if it.type == {
        case .TEXT;
            append(*builder, it.text);
        case .PARAM;
            param_name := template.params[it.param_id];
            value, found := get(req, param_name);
            if !res.rendered_toasts && param_name == "toasts" {
                _, toast_template_exists := table_find(templates, TOAST_TEMPLATE_NAME);
                if toast_template_exists {
                    res.rendered_toasts = true;
                    value = render_each(payload, res.toasts, #code render_it(TOAST_TEMPLATE_NAME, it));
                    found = true;
                }
            }
            append(*builder, ifx found then value else ""); // blank if nonexistent might not be the Right Thing To Do, we'll see...
    }
    return builder_to_string(*builder);
}
render_each :: (using payload: Route.Payload, items: $T, code: Code, when_empty: string = "") -> string #expand {
    if !items.count return when_empty;
    builder: String_Builder; defer free_buffers(*builder);
    for items { #insert_internal code; }
    return builder_to_string(*builder);

    render_it :: (template_name: string, args: ..Any) #expand {
        append(*`builder, render(`payload, template_name, ..args));
    }
}
#scope_export
//------------------------------------------------------------------------------
#load "Database.jai";
#load "Route.jai";
#load "Session.jai";
#load "Server.jai";
#load "Template.jai";
#load "Utils.jai";
//------------------------------------------------------------------------------
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
