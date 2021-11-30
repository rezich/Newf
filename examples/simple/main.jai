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
get_post :: (using guestbook: *Guestbook, id: int) -> post: *Guestbook.Post = null, exists: bool = true {
    if id >= posts.count return exists = false;
    return *posts[id];
}

guestbook: Guestbook;


main :: () {
    init_template_system();


    before_route(() {
        Set("current_year", 2021);
        Set("site_title", "Website");
    });


    // homepage
    route(.GET, "/", () {
        Set("page_title", "homepage");
        Set("guestbook_posts", Render_Each(guestbook.posts, #code Render_It("guestbook_post", it.id, it.body)));
        Set("body", Render("home"));
        Respond(Render("index"));
    });
    // guestbook post detail page
    route(.GET, "/guestbook/:id", () {
        id, id_valid := Get_Int("id");
        if !id_valid then Reroute(not_found);
        post, post_exists := get_post(*guestbook, id);
        if !post_exists then Reroute(not_found);
        Set("page_title", tprint("Guestbook post #%", id));
        Set("post_body", post.body);
        Set("body", Render("guestbook_post"));
        Respond(Render("index"));
    });
    // guestbook post submission
    route(.POST, "/guestbook/post", () {
        body, body_given := Get("post_body");
        if !body_given then Respond(status=400, body="Did not provide body.");
        add_post(*guestbook, body);
        Redirect("/");
    });
    // guestbook API
    route(.GET, "api", "/v1/guestbook", () {
        Respond(Render("api/guestbook", guestbook.posts.count), content_type=.JSON);
    });
    // guestbook post detail API
    route(.GET, "api", "/v1/guestbook/:id", () {
        id, id_given := Get_Int("id");
        if !id_given then Respond(status=400, body=json_error("Malformed guestbook post ID"), content_type=.JSON);
        post, post_exists := get_post(*guestbook, id);
        if !post_exists then Respond(status=404, body=json_error("Guestbook post does not exist."), content_type=.JSON);
        Set("post_body", post.body);
        Respond(Render("api/guestbook_post"), content_type=.JSON);
    });
    // invalid API handler
    route(.GET, "api", "*", () {
        Respond(status=400);
    });
    // catch-all 404
    route(.GET, "*", "*", not_found);


    not_found :: () {
        Set("page_title", "page not found");
        Set("body", Render("404"));
        Respond(Render("index"), status=404);
    }
    json_error :: x => tprint("{ \"error:\" \"%\" }", x);


    /*after_route(() {
        // currently doesn't work because routes are case-sensitive!
        for 0..res.body.count-1
            if (res.body[it] >= #char "a" && res.body[it] <= #char "z") res.body[it] ^= 0x20;
    });*/
    //after_route(() { sleep_milliseconds(500); });


    /*server := create_server(8000);
    start(server);*/
    listen(8000);
}

#import "Web_Framework";
#import "Basic";
