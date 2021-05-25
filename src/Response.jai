Response_Proc :: #type (req: *Request, res: *Response);

Response :: struct {
    body: string;
    headers: Table(string, string);
    status: int = 200;
    sent: bool = false;
}

create_response :: () -> *Response {
    res := New(Response);
    init(*res.headers);
    return res;
}

deinit :: (using res: *Response) {
    uninit(*headers);
}

send :: (using res: *Response) {
    sent = true;

    // Debug:
    /*write_string("\n\nRESPONSE\n========\n\n");
    print("STATUS\n------\n%\n", res.status);
    write_string("\nHEADERS\n-------\n");
    for value, key: res.headers {
        print("%: %\n", key, value);
    }
    write_string("\nBODY\n----\n");
    write_string(res.body);
    write_string("\n\n");*/
}

respond :: (req: *Request, proc: Response_Proc) -> *Response {
    res := create_response();

    new_context := context;
    push_context new_context {
        run_middleware_before(req, res);

        // Debug:
        write_string("\n\n\nREQUEST\n=======\n\n");
        print("PATH\n----\n%\n", req.path);
        write_string("\nHEADERS\n-------\n");
        for value, key: req.headers {
            print("%: %\n", key, value);
        }

        proc(req, res);

        //if !res.sent then send(res);

        run_middleware_after(req, res);
    }
    return res;
}
