#add_context response: *Response = null;

Response_Proc :: #type (req: *Request);

Response :: struct {
    body: string;
    headers: Table(string, string);
    status: int = 200;
}

create_response :: () -> *Response {
    res := New(Response);
    init(*res.headers);
    return res;
}

deinit :: (res: *Response) {
    uninit(*res.headers);
}

respond :: (req: *Request, proc: Response_Proc) {
    res := create_response();
    new_context := context;
    new_context.response = res;
    push_context new_context {
        proc(req);
        
        // Debug:
        write_string("\n\n\nREQUEST\n=======\n\n");
        print("PATH\n----\n%\n", req.path);
        write_string("\nHEADERS\n-------\n");
        for value, key: req.headers {
            print("%: %\n", key, value);
        }
        write_string("\n\nRESPONSE\n========\n\n");
        print("STATUS\n------\n%\n", res.status);
        write_string("\nHEADERS\n-------\n");
        for value, key: res.headers {
            print("%: %\n", key, value);
        }
        write_string("\nBODY\n----\n");
        write_string(context.response.body);
        write_string("\n\n");
    }
    deinit(res);
}
