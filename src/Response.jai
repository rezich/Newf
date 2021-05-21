#add_context response: *Response = null;

Response_Proc :: #type (req: *Request);

Response :: struct {
    body: string;
    headers: [..] string;
    status: int;
}

create_response :: () -> *Response {
    res := New(Response);
    return res;
}

respond :: (req: *Request, proc: Response_Proc) {
    res := create_response();
    new_context := context;
    new_context.response = res;
    push_context new_context {
        proc(req);
        
        // Debug:
        write_string("\n\nRESPONSE\n========\n");
        write_string(context.response.body);
        write_string("\n\n");
    }
}
