#add_context response: *Response = null;

Response :: struct {
    body: string;
}

create_response :: () -> *Response {
    res := New(Response);
    return res;
}
