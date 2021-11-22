Guestbook :: struct {
    posts: [..] Post;
    
    Post :: struct {
        id: int;
        body: string;
    }
}

add_post :: (using guestbook: *Guestbook, body: string) {
    post: Post;
    post.id = guestbook.posts.count;
    post.body = body;
    array_add(*guestbook.posts, post);
}

guestbook: Guestbook;


main :: () {
    init_template_system();

    add_post(*guestbook, "first! lol");

    before_route((req: *Request, res: *Response) {
        Set("current_year", 2021);
        Set("site_title", "Website");
    });

    route(.GET, "/", (req: *Request, res: *Response) {
        Set("page_title", "homepage");
        {
            builder: String_Builder;
            defer free_buffers(*builder);
            //for guestbook.posts append(*builder, tprint("<a href=\"/guestbook/%1\"><h2>Post #%1</h2></a><p>%2</p>\n<hr />\n", it.id, it.body));
            for guestbook.posts append(*builder, Tpl("guestbook_post", it.id, it.body));
            Set("guestbook_posts", builder_to_string(*builder));
        }
        Set("body", Tpl("home"));
        Render("index");
    });
    route(.GET, "/guestbook/:id", (req: *Request, res: *Response) {
        id, id_given := Param_int("id");
        if !id_given then Respond(400, "Malformed guestbook post ID");
        if id >= guestbook.posts.count then Respond(404, "Guestbook post does not exist");
        post := guestbook.posts[id];
        Set("page_title", tprint("Guestbook post #%", id));
        Set("post_body", post.body);
        Set("body", Tpl("guestbook_post"));
        Render("index");
    });
    route(.POST, "/guestbook/post", (req: *Request, res: *Response) {
        body, body_given := Param("post_body");
        if !body_given then Respond(400, "Did not provide body.");
        add_post(*guestbook, body);
        Redirect("/");
    });
    route(.GET, "api", "/v1/guestbook/:id", (req: *Request, res: *Response) {
        id, id_given := Param_int("id");
        if !id_given then Respond(400, "Malformed guestbook post ID");
        if id >= guestbook.posts.count then Respond(404, "Guestbook post does not exist.");
        post := guestbook.posts[id];
        Set("post_body", post.body);
        Render("api/guestbook", content_type=.JSON);
    });
    route(.GET, "api", "*", (req: *Request, res: *Response) {
        Respond(400);
    });
    route(.GET, "*", "*", (req: *Request, res: *Response) {
        Set("page_title", "page not found");
        Set("body", Tpl("404"));
        Render("index", status=404);
    });


    //after_route((req: *Request, res: *Response) { sleep_milliseconds(500); });

    server := create_server(8000);
    start(server);
}

#import "Web_Framework";
#import "Hash_Table";
#import "Basic";
