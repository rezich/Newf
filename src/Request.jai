Headers :: #type Table(string, string);
Cookies :: #type Table(string, string);

Request :: struct {
    uri: struct {
        headers:      Headers;
        method:       Method;
        scheme:       string;
        path:         string;
        query:        string;
        query_params: Table(string, string);
        subdomain:    string;
    }
    form_data: Table(string, string);
    cookies:   Cookies;
    raw:       string;
    params:    Table(string, string);

    Method :: enum { GET; HEAD; POST; PUT; DELETE; CONNECT; OPTIONS; TRACE; PATCH; }
}
deinit :: (using req: *Request) {
    deinit(*uri.headers);
    deinit(*uri.query_params);
    deinit(*form_data);
    deinit(*cookies);
    deinit(*params);
}

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

#scope_module
param_set :: inline (key: string, value: Any)    { param_set(key, tprint("%", value)); }
param_set :: inline (key: string, value: string) { table_set(*context.reqres.req.params, key, value); }
