#import "Basic";
#import "String";
#import "Hash_Table";
#import "File";
#import "File_Utilities";

#load "src/Param_Container.jai";
#load "src/Request.jai";
#load "src/Response.jai";
#load "src/Route.jai";
#load "src/Template.jai";

SITE_TITLE :: "Best Website!";

main :: () {
    set_working_directory(#filepath);
    init_template_system("/templates", ".template");

    add_route(.GET, "/", (req: *Request, res: *Response) {
        defer output(res, "index");
        bind("site_title", SITE_TITLE);
        bind("page_title", "Home");
        bind_output("body", "home");
    });

    add_route(.GET, "/posts/:id", (req: *Request, res: *Response) {
        defer output(res, "index");
        bind("site_title", SITE_TITLE);
        bind("page_title", "This will be dynamic at some point");
        bind("post_title", "First blog post");
        bind("post_body", "This is a blog post!");
        bind_output("body", "blog/post");
    });

    add_route(.GET, "/posts/:id/edit", (req: *Request, res: *Response) {
        defer output(res, "index");
        post_id := get_int(*req.params, "id");
        bind("site_title", SITE_TITLE);
        bind("page_title", "Editing post");
        bind("post_title", post_id);
        bind("post_body", "This is a blog post!");
        bind_output("body", "blog/post");
    });

    add_route(.GET, "/users/$username", (req: *Request, res: *Response) {
        defer output(res, "index");
        username := get_string(*req.params, "username");
        bind("site_title", SITE_TITLE);
        bind("page_title", username);
        bind_output("body", "home");
    });

    // for now, route paths are tested to match in sequence, so your wildcard routes must be last
    add_route(.GET, "*", (req: *Request, res: *Response) {
        defer output(res, "index");
        bind("site_title", SITE_TITLE);
        bind("page_title", "Page not found");
        bind_output("body", "404");
        res.status = 404;
    });
    
    //req := make_request(method=.GET, path="/posts/111/edit");
    req := make_request(method=.GET, path="/posts//edit"); // should 404
    //req := make_request(method=.GET, path="/users/adam");
    //req := make_request(method=.GET, path="/users/"); // should 404
    //req := make_request(method=.GET, path="/");
    route_request(req);
}
