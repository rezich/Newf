Response_Proc :: #type (req: *Request, res: *Response);

Response :: struct {
    body: string;
    headers: Table(string, string);
    status: int = 200;
    template_variables: Template_Variables;
}

create_response :: () -> *Response {
    res := New(Response);
    init(*res.headers);
    init(*res.template_variables);
    return res;
}

deinit :: (using res: *Response) {
    uninit(*headers);
}

respond :: (req: *Request, proc: Response_Proc) {
    res := create_response();

    new_context := context;
    init(*new_context.template_variables);
    push_context new_context {

        run_middleware(req, res);

        proc(req, res);
        
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
        write_string(res.body);
        write_string("\n\n");

        uninit(*context.template_variables);
    }
    deinit(res);
}
