#import "Basic";
#import "String";
#import "Hash_Table";
#import "File";
#import "File_Utilities";

#load "src/Middleware.jai";
#load "src/Param_Container.jai";
#load "src/Request.jai";
#load "src/Response.jai";
#load "src/Route.jai";
#load "src/Server.jai";
#load "src/Template.jai";

SITE_TITLE :: "Best Website!";

main :: () {
    set_working_directory(#filepath);
    init_template_system("/templates", ".template");

    add_middleware_before((req: *Request, res: *Response) {
        bind("site_title", SITE_TITLE);
        bind("current_year", 2021);
    });

    add_route(.GET, "/", (req: *Request, res: *Response) {
        defer output(res, "index");
        bind("page_title", "Home");
        bind_output("body", "home");
    });

    add_route(.GET, "/post/:id", (req: *Request, res: *Response) {
        defer output(res, "index");
        post_id := get_int(*req.params, "id");
        bind("page_title", "This will be dynamic at some point");
        bind("post_title", post_id);
        bind("post_body", "This is a blog post!");
        bind_output("body", "blog/post");
    });

    add_route(.GET, "/post/:id/edit", (req: *Request, res: *Response) {
        defer output(res, "index");
        post_id := get_int(*req.params, "id");
        bind("page_title", "Editing post");
        bind("post_title", post_id);
        bind("post_body", "This is a blog post!");
        bind_output("body", "blog/post");
    });

    add_route(.GET, "/user/$username", (req: *Request, res: *Response) {
        defer output(res, "index");
        username := get_string(*req.params, "username");
        bind("page_title", username);
        bind_output("body", "home");
    });

    // for now, route paths are tested to match in sequence, so your wildcard routes must be last
    add_route(.GET, "*", (req: *Request, res: *Response) {
        defer output(res, "index");
        bind("page_title", "Page not found");
        bind_output("body", "404");
        res.status = 404;
    });
    
    //req := make_request(method=.GET, path="/post/111/edit");
    //req := make_request(method=.GET, path="/post//edit"); // should 404
    //req := make_request(method=.GET, path="/user/adam");
    //req := make_request(method=.GET, path="/user/"); // should 404
    //req := make_request(method=.GET, path="/");
    //route_request(req);

    server := create_server(8000);
    start(server);
}
