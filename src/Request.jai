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

make_request :: (method: Request_Method, path: string) -> *Request {
    req := New(Request);
    req.method = method;
    req.path = path;
    init(*req.headers);
    init(*req.params);
    return req;
}

deinit :: (using req: *Request) {
    deinit(*params);
}
