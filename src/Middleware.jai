Middleware_Proc :: #type (req: *Request, res: *Response);

Middleware :: struct {
    proc: Middleware_Proc;
}

middleware: [..] Middleware;

add_middleware :: inline (proc: Middleware_Proc) {
    mw: Middleware;
    mw.proc = proc;
    array_add(*middleware, mw);
}

run_middleware :: (req: *Request, res: *Response) {
    for mw: middleware {
        print("% %\n", req, res);
        mw.proc(req, res);
    }
}
