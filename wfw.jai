#import "Basic";
#import "String";
#import "Hash_Table";
#import "File";
#import "File_Utilities";
#import "Regexp";

#load "src/Template.jai";
#load "src/Request.jai";
#load "src/Response.jai";
#load "src/Route.jai";

main :: () {
    set_working_directory(#filepath);
    init_template_system("/templates");
    init_router();

    add_route("/", (req: *Request) {
        bind("site_title", "Best Website");
        bind("page_title", "Home");
        bind_output("body", "home");
        output("index");
    });

    add_route("/posts/%{id}", (req: *Request) {
        bind("site_title", "Best Website");
        bind("page_title", "This will be dynamic at some point");
        bind("post_title", "First blog post");
        bind("post_body", "This is a blog post!");
        bind_output("body", "blog/post");
        output("index");
    });

    req := Request.{method=.GET, path="/posts/1"};
    route_request(*req);
}
