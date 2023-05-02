Headers :: #type Table(string, string);
Cookies :: #type Table(string, string);


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
deinit :: (using req: *Request) {
    deinit(*uri.headers);
    deinit(*uri.query_params);
    deinit(*form_data);
    deinit(*cookies);
    deinit(*params);
}


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
deinit :: (using res: *Response) {
    deinit(*headers);
    deinit(*cookies);
}


// Cookie
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


// Header
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


// Session
session_get :: (key: string) -> value := "", success := true {
    using context.reqres;
    if !res.session return success = false;
    value, success := table_find(*res.session.params, key);
    if !success return success = false;
    return value, success = value != "";
}
session_get_int :: (key: string) -> value := -1, success := true {
    using context.reqres;
    if !res.session return success = false;
    string_value, key_success := table_find(*res.session.params, key);
    if !key_success || string_value == "" return success = false;
    int_value, parse_success := parse_int(*string_value);
    if !parse_success return success = false;
    return int_value;
}
session_set :: inline (key: string, value: Any) { session_set(key, sprint("%", value)); }
session_set :: inline (key: string, value: string) { begin_session(); table_set(*context.reqres.res.session.params, key, value); }

Session :: struct {
    token: TOKEN;
    locator: Bucket_Locator;
    ended: bool;
    params: Table(string, string);

    TOKEN :: string;
}

sessions: Table(Session.TOKEN, *Session);
session_storage: Bucket_Array(Session, SESSIONS_PER_BUCKET, true);

begin_session :: () {
    using context.reqres;
    if !res.session {
        session: Session;
        session.token = md5(tprint("%", get_time())); //TODO: lol
        session.locator = bucket_array_add(*session_storage, session);
        res.session = bucket_array_find_pointer(*session_storage, session.locator);
        table_add(*sessions, session.token, res.session);
        cookie_set(SESSION_TOKEN, session.token);
    }
}
load_or_begin_session :: (token: Session.TOKEN) {
    using context.reqres;
    existing, found := table_find(*sessions, token);
    if found && existing {
        res.session = existing;
        cookie_set(SESSION_TOKEN, existing.token);
    }
    else begin_session();
}
end_session :: () {
    using context.reqres;
    if res.session == null return;
    table_remove(*sessions, res.session.token);
    bucket_array_remove(*session_storage, res.session.locator);
    res.session = null;
    cookie_unset(SESSION_TOKEN);
}


// Route
ROUTE_PATH_SEPARATORS :: "/";
Route :: struct {
    method: Request_Method;
    subdomain: string;
    proc: Proc;
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
    Proc :: #type ();
}

routes: [..] Route;
routes_match_subdomains := false;

route :: (method: Request_Method, path: string, proc: Route.Proc) { route(method, "", path, proc); }
route :: (method: Request_Method, subdomain: string, path: string, proc: Route.Proc) {
    if subdomain != "" then routes_match_subdomains = true;
    r: Route;
    r.method = method;
    r.subdomain = subdomain;
    r.proc = proc;
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

before_routes: [..] Route.Proc;
after_routes:  [..] Route.Proc;

before_route :: inline (proc: Route.Proc) { array_add(*before_routes, proc); }
after_route  :: inline (proc: Route.Proc) { array_add(*after_routes,  proc); }

param_get :: (key: string) -> value := "", success := true {
    value, success := table_find(*context.reqres.req.params, key);
    if !success return success = false;
    return value, success = value != "";
}
param_get_int :: (key: string) -> value := -1, success: bool=true {
    string_value, key_success := table_find(*context.reqres.req.params, key);
    if !key_success || string_value == "" return success = false;
    int_value, parse_success := parse_int(*string_value);
    if !parse_success return success = false;
    return int_value;
}
param_set :: inline (key: string, value: Any)    { param_set(key, tprint("%", value)); }
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


// Template
#load "Template.jai";


// Utils
bucket_array_find_pointer :: (using array: *Bucket_Array, locator: Bucket_Locator) -> *array.type {
    bucket := all_buckets[locator.bucket_index];
    assert(bucket.occupied[locator.slot_index] == true);
    result := *bucket.data[locator.slot_index];
    return result;
}
encode_uri_component :: (text: string) -> string {
    new_context := context;
    push_context new_context {
        builder: String_Builder;
        format_int := *context.print_style.default_format_int;
        format_int.base = 16;
        format_int.minimum_digits = 2;
        for 0..text.count-1 {
            if should_encode(text[it]) then print_to_builder(*builder, "%%%1", text[it]);
            else append(*builder, text[it]);
        }
        return builder_to_string(*builder);
        
        should_encode :: (char: u8) -> bool {
            if  (char >= #char "A" && char <= #char "Z") ||
                (char >= #char "a" && char <= #char "z") ||
                (char >= #char "0" && char <= #char "9") ||
                char == #char "-" || char == #char "_" || char == #char "." ||
                char == #char "!" || char == #char "~" || char == #char "*" ||
                char == #char "'" || char == #char "(" || char == #char ")"
            then return false;
            return true;
        }
    }
}
decode_uri_component :: (text: string) -> string {
    builder: String_Builder;
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
    return decode_uri_component(str);
}
is_hex_number :: inline (c: u32) -> bool {
    return (c >= #char "a" && c <= #char "f") || (c >= #char "A" && c <= #char "F") || is_number(c);
}
is_number :: inline (c: u32) -> bool {
    return (c >= #char "0" && c <= #char "9");
}
xprint :: (args: ..Any) -> string {
    builder: String_Builder;
    for args print_to_builder(*builder, "%", it);
    return builder_to_string(*builder);
}

#load "Server.jai";

#import "Basic";
#import "Hash_Table";
#import "Bucket_Array";
#import "String";
#import "File";
#import "File_Utilities";
#import "md5";

