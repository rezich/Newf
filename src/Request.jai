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
    method: Request_Method;
    path: string;
    headers: Table(string, string);
    params: Param_Container;
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

make_request :: inline (method: Request_Method, path: string) -> *Request {
    req := New(Request);
    req.method = method;
    req.path = path;
    init(*req.headers);
    init(*req.params);
    return req;
}

make_request :: (request: string) -> *Request {
    request_string := request;

    verb_end := index_of_char(request_string, #char " ");
    verb := slice(request_string, 0, verb_end);

    request_string = slice(request_string, verb_end + 1, request_string.count);

    path_end := index_of_char(request_string, #char " ");
    path := slice(request_string, 0, path_end);

    request_string = slice(request_string, path_end + 1, request_string.count);

    http_end := index_of_string(request_string, "\r\n") + 2;

    request_string = slice(request_string, http_end, request_string.count);
    
    req := make_request(request_method_from_string(verb), path);

    for split(request_string, "\r\n") {
        kv := split(it, ": ");
        if kv.count > 0 {
            table_add(*req.headers, kv[0], kv[1]);
        }
    }
    return req;
}

deinit :: (using req: *Request) {
    deinit(*params);
}
