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

#add_context request: *Request;

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

#add_context response: *Response;

uninit :: (using res: *Response) {
    uninit(*headers);
    uninit(*cookies);
}
//------------------------------------------------------------------------------
// Plugin
before_plugins: [..] ();
after_plugins: [..] ();

before_route :: inline (proc: ()) { array_add(*before_plugins, proc); }
after_route :: inline (proc: ()) { array_add(*after_plugins, proc); }
//------------------------------------------------------------------------------
// API
get :: (key: string) -> value := "", success := true {
    value, success := table_find(context.request.params, key);
    if !success return success = false;
    return value, success = value != "";
}
get_int :: (key: string) -> value := -1, success: bool=true {
    string_value, key_success := table_find(context.request.params, key);
    if !key_success || string_value == "" return success = false;
    int_value, parse_success := parse_int(*string_value);
    if !parse_success return success = false;
    return int_value;
}
get_cookie :: (key: string) -> value := "", success := true {
    value, success := table_find(context.request.cookies, key);
    if !success return success = false;
    return decode_uri_component(value), success = value != "";
}
get_cookie_int :: (key: string) -> value := -1, success: bool=true {
    string_value, key_success := table_find(context.request.cookies, key);
    if !key_success || string_value == "" return success = false;
    string_value = decode_uri_component(string_value);
    int_value, parse_success := parse_int(*string_value);
    if !parse_success return success = false;
    return int_value;
}
get_header :: (key: string) -> value := "", success := true {
    value, success := table_find(context.request.uri.headers, key);
    if !success return success = false;
    return value;
}
get_header_int :: (key: string) -> value := -1, success: bool=true {
    string_value, key_success := table_find(context.request.uri.headers, key);
    if !key_success || string_value == "" return success = false;
    int_value, parse_success := parse_int(*string_value);
    if !parse_success return success = false;
    return int_value;
}
get_session :: (key: string) -> value := "", success := true {
    if !context.response.session return success = false;
    value, success := table_find(context.response.session.params, key);
    if !success return success = false;
    return value, success = value != "";
}
get_session_int :: (key: string) -> value := -1, success := true {
    if !context.response.session return success = false;
    string_value, key_success := table_find(context.response.session.params, key);
    if !key_success || string_value == "" return success = false;
    int_value, parse_success := parse_int(*string_value);
    if !parse_success return success = false;
    return int_value;
}
set :: (key: string, value: Any) { set(key, tprint("%", value)); }
set :: (key: string, value: string) {
    table_set(*context.request.params, key, value);
}
set_cookie :: (key: string, value: Any) { set_cookie(key, tprint("%", value)); }
set_cookie :: (key: string, value: string) {
    table_set(*context.response.cookies, key, encode_uri_component(value));
}
unset_cookie :: (key: string) {
    table_set(*context.response.cookies, key, "INVALID_TOKEN; expires=Thu, 01 Jan 1970 00:00:00 GMT");
}
set_header :: (key: string, value: Any) { set_header(tprint("%", value)); }
set_header :: (key: string, value: string) {
    table_set(*context.response.headers, key, value);
}
set_session :: (key: string, value: Any) { set_session(key, sprint("%", value)); }
set_session :: (key: string, value: string) {
    begin_session();
    table_set(*context.response.session.params, key, value);
}
respond :: (body: string = "", content_type: HTTP_Content_Type=.HTML, status: HTTP_Status=200) #expand {
    content_type_string: string;
    if content_type == {
        case .HTML; content_type_string = "text/html; charset=utf-8";
        case .JSON; content_type_string = "text/json; charset=utf-8";
    }
    set_header("Content-Type", content_type_string);
    context.response.body = body;
    context.response.status = 200;
    `return;
}
redirect :: (to: string, args: ..Any) #expand {
    _to := "";
    if args.count > 0 then _to = tprint(to, ..args); else _to = to;
    context.response.status = 302;
    set_header("Location", _to);
    `return;
}
reroute :: (to: ()) #expand { //TODO: remove
    to();
    `return;
}
render :: (template_name: string, args: ..Any) -> string #must {
    if !templates_initialized init_templates();
    template := table_find_pointer(templates, template_name);
    if !template return tprint("-- TEMPLATE NOT FOUND: % --\n", template_name);
    if args.count > 0 && args.count != template.params.count {
        return tprint("-- RENDER ARGUMENT ERROR: % --\n", template_name);
    }
    for args set(template.params[it_index], it);
    builder: String_Builder; defer free_buffers(*builder);
    for template.pieces {
        if it.type == {
            case .TEXT;
                append(*builder, it.text);
            case .PARAM;
                param_name := template.params[it.param_id];
                value, found := get(param_name);
                if !context.response.rendered_toasts && param_name == "toasts" {
                    _, toast_template_exists := table_find(templates, TOAST_TEMPLATE_NAME);
                    if toast_template_exists {
                        context.response.rendered_toasts = true;
                        value = render_each(context.response.toasts, #code render_it(TOAST_TEMPLATE_NAME, it));
                        found = true;
                    }
                }
                append(*builder, ifx found then value else ""); // blank if nonexistent might not be the Right Thing To Do, we'll see...
        }
    }
    return builder_to_string(*builder);
}
render_each :: (items: $T, code: Code, when_empty: string = "") -> string #expand {
    if !items.count return when_empty;
    builder: String_Builder; defer free_buffers(*builder);
    for items { #insert_internal code; }
    return builder_to_string(*builder);

    render_it :: (template_name: string, args: ..Any) #expand {
        append(*`builder, render(template_name, ..args));
    }
}
toast :: (message: string) {
    array_add(*context.response.toasts, message);
}
//------------------------------------------------------------------------------
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
        builder: String_Builder; defer free_buffers(*builder);
        format_int := *context.print_style.default_format_int;
        format_int.base = 16;
        format_int.minimum_digits = 2;
        for 0..text.count-1 {
            if should_encode(text[it]) then append(*builder, tprint("%%%1", text[it]));
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
    return decode_uri_component(str);
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
#load "Database.jai";
#load "Route.jai";
#load "Server.jai";
#load "Session.jai";
#load "Template.jai";
#load "md5.jai"; // because the official module is broken & will probably be removed anyway

#import "File_Utilities";
#import "Bucket_Array";
#import "Hash_Table";
#import "Atomics";
#import "Thread";
#import "System";
#import "String";
#import "Basic";
#import "File";
