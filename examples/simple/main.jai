main :: () {
    init_template_system();
    
    //before_route((req: *Request, res: *Response) { sleep_milliseconds(500); });

    /*route(.GET, "/", (req: *Request, res: *Response) {
        set_header(res, "Content-Type", "text/html; charset=utf-8");
        res.body = #string XX
<html>
    <head>
        <title>Website</title>
    </head>
    <body>Hello, world!</body>
</html>
XX      ;
    });*/
    route(.GET, "/user/:id", (req: *Request, res: *Response) {
        defer render("index");
        set("current_year", 2021);
        set("site_title", "website");
        set("page_title", "page");
        set_from_render("body", "home");
    });
    route(.GET, "*", (req: *Request, res: *Response) { /* 404 */ });

    //after_route((req: *Request, res: *Response) { sleep_milliseconds(500); });

    server := create_server(8000);
    start(server);
}

#import "Web_Framework";
#import "Basic";
