HTTP_Status :: #type u16;

HTTP_Content_Type :: enum { HTML; JSON; } // currently unused

Response :: struct {
    headers:     Headers;
    cookies:     Cookies;
    body:        string;
    status:      HTTP_Status;
    toasts: [..] Toast;
}

deinit :: (using res: *Response) {
    deinit(*headers);
    deinit(*cookies);
    array_free(toasts);
}
