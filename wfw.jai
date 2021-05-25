#import "Basic";
#import "String";
#import "Hash_Table";
#import "File";
#import "File_Utilities";

#load "modules/winsock.jai";

#load "src/Middleware.jai";
#load "src/Param_Container.jai";
#load "src/Request.jai";
#load "src/Response.jai";
#load "src/Route.jai";
#load "src/Template.jai";

SITE_TITLE :: "Best Website!";

main :: () {
    set_working_directory(#filepath);
    init_template_system("/templates", ".template");

    add_middleware((req: *Request, res: *Response) {
        bind(res, "site_title", SITE_TITLE);
    });

    add_route(.GET, "/", (req: *Request, res: *Response) {
        bind(res, "page_title", "Home");
        bind_output(res, "body", "home");
        output(res, "index");
    });

    add_route(.GET, "/posts/:id", (req: *Request, res: *Response) {
        defer output(res, "index");
        bind(res, "page_title", "This will be dynamic at some point");
        bind(res, "post_title", "First blog post");
        bind(res, "post_body", "This is a blog post!");
        bind_output(res, "body", "blog/post");
    });

    /*add_route(.GET, "/posts/:id/edit", (req: *Request, res: *Response) {
        defer output(res, "index");
        post_id := get_int(*req.params, "id");
        
        bind(res, "page_title", "Editing post");
        bind(res, "post_title", post_id);
        bind(res, "post_body", "This is a blog post!");
        bind_output(res, "body", "blog/post");
    });*/

    add_route(.GET, "/users/$username", (req: *Request, res: *Response) {
        defer output(res, "index");
        username := get_string(*req.params, "username");
        bind(res, "page_title", username);
        bind_output(res, "body", "home");
    });

    // for now, route paths are tested to match in sequence, so your wildcard routes must be last
    add_route(.GET, "*", (req: *Request, res: *Response) {
        defer output(res, "index");
        bind(res, "page_title", "Page not found");
        bind_output(res, "body", "404");
        res.status = 404;
    });
    
    //req := make_request(method=.GET, path="/posts/111/edit");
    //req := make_request(method=.GET, path="/posts//edit"); // should 404
    //req := make_request(method=.GET, path="/users/adam");
    //req := make_request(method=.GET, path="/users/"); // should 404
    req := make_request(method=.GET, path="/");
    route_request(req);
}
