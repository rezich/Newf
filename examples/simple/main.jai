main :: () {
    before_route((req: *Request, res: *Response) {});

    route(.GET, "/", (req: *Request, res: *Response) {
        set_header(res, "Content-Type", "text/html; charset=utf-8");
        res.body = #string XX
<html>
    <head>
        <title>Website</title>
    </head>
    <body>Hello, world!</body>
</html>
XX;
    });
    //route(.GET, "*", (req: *Request, res: *Response) { /* 404 */ });

    after_route((req: *Request, res: *Response) {});

    server := create_server(8000);
    start(server);
}

#import "Web_Framework";
