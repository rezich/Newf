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
cookie_get :: (key: string) -> value := "", success := true {
    value, success := table_find(context.reqres.req.cookies, key);
    if !success return success = false;
    return decode_uri_component(value), success = value != "";
}
cookie_get_int :: (key: string) -> value := -1, success: bool=true {
    string_value, key_success := table_find(context.reqres.req.cookies, key);
    if !key_success || string_value == "" return success = false;
    string_value = decode_uri_component(string_value);
    int_value, parse_success := parse_int(*string_value);
    if !parse_success return success = false;
    return int_value;
}
cookie_set :: (key: string, value: Any) { cookie_set(key, tprint("%", value)); }
cookie_set :: (key: string, value: string) {
    table_set(*context.reqres.res.cookies, key, encode_uri_component(value));
}
cookie_unset :: (key: string) {
    table_set(*context.reqres.res.cookies, key, "INVALID_TOKEN; expires=Thu, 01 Jan 1970 00:00:00 GMT");
}
//------------------------------------------------------------------------------
// API - Header
header_get :: (key: string) -> value := "", success := true {
    value, success := table_find(context.reqres.req.uri.headers, key);
    if !success return success = false;
    return value;
}
header_get_int :: (key: string) -> value := -1, success: bool=true {
    string_value, key_success := table_find(context.reqres.req.uri.headers, key);
    if !key_success || string_value == "" return success = false;
    int_value, parse_success := parse_int(*string_value);
    if !parse_success return success = false;
    return int_value;
}
header_set :: inline (key: string, value: Any) { header_set(key, tprint("%", value)); }
header_set :: inline (key: string, value: string) { table_set(*context.reqres.res.headers, key, value); }
//------------------------------------------------------------------------------
// API - Session
session_get :: (key: string) -> value := "", success := true {
    using context.reqres;
    if !res.session return success = false;
    value, success := table_find(res.session.params, key);
    if !success return success = false;
    return value, success = value != "";
}
session_get_int :: (key: string) -> value := -1, success := true {
    using context.reqres;
    if !res.session return success = false;
    string_value, key_success := table_find(res.session.params, key);
    if !key_success || string_value == "" return success = false;
    int_value, parse_success := parse_int(*string_value);
    if !parse_success return success = false;
    return int_value;
}
session_set :: inline (key: string, value: Any) { session_set(key, sprint("%", value)); }
session_set :: inline (key: string, value: string) { begin_session(); table_set(*context.reqres.res.session.params, key, value); }
//------------------------------------------------------------------------------
// API - Routing
param_get :: (key: string) -> value := "", success := true {
    value, success := table_find(context.reqres.req.params, key);
    if !success return success = false;
    return value, success = value != "";
}
param_get_int :: (key: string) -> value := -1, success: bool=true {
    string_value, key_success := table_find(context.reqres.req.params, key);
    if !key_success || string_value == "" return success = false;
    int_value, parse_success := parse_int(*string_value);
    if !parse_success return success = false;
    return int_value;
}
param_set :: inline (key: string, value: Any) { param_set(key, tprint("%", value)); }
param_set :: inline (key: string, value: string) { table_set(*context.reqres.req.params, key, value); }

Respond :: (body: string = "", content_type: HTTP_Content_Type=.HTML, status: HTTP_Status=200) #expand {
    using context.reqres;
    content_type_string: string;
    if content_type == {
        case .HTML; content_type_string = "text/html; charset=utf-8";
        case .JSON; content_type_string = "text/json; charset=utf-8";
    }
    header_set("Content-Type", content_type_string);
    res.body = body;
    res.status = 200;
    `return;
}
Redirect :: (to: string, args: ..Any) #expand {
    using context.reqres;
    _to := "";
    if args.count > 0 then _to = tprint(to, ..args); else _to = to;
    res.status = 302;
    header_set("Location", _to);
    `return;
}
Reroute :: (to: Route.Proc) #expand { to(); `return; }

render :: (template_name: string, args: ..Any) -> string #must {
    using context.reqres;
    if !templates_initialized init_templates();
    template := table_find_pointer(templates, template_name);
    if !template return tprint("-- TEMPLATE NOT FOUND: % --\n", template_name);
    if args.count > 0 && args.count != template.params.count {
        return tprint("-- RENDER ARGUMENT ERROR: % --\n", template_name);
    }
    for args param_set(template.params[it_index], it);
    builder: String_Builder; defer free_buffers(*builder);
    for template.pieces if it.type == {
        case .TEXT;
            append(*builder, it.text);
        case .PARAM;
            param_name := template.params[it.param_id];
            value, found := param_get(param_name);
            if !res.rendered_toasts && param_name == "toasts" {
                _, toast_template_exists := table_find(templates, TOAST_TEMPLATE_NAME);
                if toast_template_exists {
                    res.rendered_toasts = true;
                    value = render_each(res.toasts, #code render_it(TOAST_TEMPLATE_NAME, it));
                    found = true;
                }
            }
            append(*builder, ifx found then value else ""); // blank if nonexistent might not be the Right Thing To Do, we'll see...
    }
    return builder_to_string(*builder);
}
render_each :: (items: $T, code: Code, when_empty: string = "") -> string #expand {
    using context.reqres;
    if !items.count return when_empty;
    builder: String_Builder; defer free_buffers(*builder);
    for items { #insert_internal code; }
    return builder_to_string(*builder);

    render_it :: (template_name: string, args: ..Any) #expand {
        append(*`builder, render(template_name, ..args));
    }
}

toast :: (message: string) { array_add(*context.reqres.res.toasts, message); }
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
