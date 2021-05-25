Middleware_Proc :: #type (req: *Request, res: *Response);

middleware_before: [..] Middleware_Proc;
middleware_after: [..] Middleware_Proc;

add_middleware_before :: inline (proc: Middleware_Proc) {
    array_add(*middleware_before, proc);
}

add_middleware_after :: inline (proc: Middleware_Proc) {
    array_add(*middleware_after, proc);
}

run_middleware_before :: (req: *Request, res: *Response) {
    for middleware_before {
        it(req, res);
    }
}

run_middleware_after :: (req: *Request, res: *Response) {
    for < middleware_after {
        it(req, res);
    }
}
