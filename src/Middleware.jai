Middleware_Proc :: #type (req: *Request, res: *Response);

middleware: [..] Middleware_Proc;

add_middleware :: inline (proc: Middleware_Proc) {
    array_add(*middleware, proc);
}

run_middleware :: (req: *Request, res: *Response) {
    for proc: middleware {
        proc(req, res);
    }
}
