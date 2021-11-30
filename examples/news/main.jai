Comment :: struct {
    id: ID; ID :: #type int;
    story_id: Story.ID;
    parent_id: Comment.ID;
    user_id: User.ID;
    body: string;
} comments: [..] Comment;
Story :: struct {
    id: ID; ID :: #type int;
    headline: string;
    body: string;
    score: Score; Score :: #type int;
} stories: [..] Story;
User :: struct {
    id: ID; ID :: #type int;
    name: string;
    password_hash: string;
} users: [..] User;
Vote :: struct {
    id: ID; ID :: #type int;
    user_id: User.ID;
    story_id: Story.ID;
    score: Story.Score;
} votes: [..] Vote;

add_story :: (headline: string, body: string) -> Story.ID {
    story: Story;
    story.id = stories.count + 1;
    story.headline = headline;
    story.body = body;
    array_add(*stories, story);
    return story.id;
}
get_story :: (id: Story.ID) -> story: *Story = null, exists: bool = true {
    if id-1 >= stories.count return exists = false;
    return *stories[id-1];
}
list_stories :: () -> [] *Story {
    return .[];
}

add_vote :: (user: User, story: Story, score: Story.Score) {
    vote: Vote;
    vote.id = votes.count + 1;
    vote.user_id = user.id;
    vote.story_id = story.id;
    vote.score = score;
    array_add(*votes, vote);
}

add_user :: (name: string, password: string) -> User.ID {
    user: User;
    user.id = users.count + 1;
    user.name = name;
    user.password_hash = md5(password);
    array_add(*users, user);
    return user.id;
}
get_user :: (id: User.ID) -> user: *User = null, exists: bool = true {
    if id-1 >= users.count return exists = false;
    return *users[id-1];
}
get_user :: (name: string) -> user: *User = null, exists: bool = true {
    user: *User = null;
    for * users if it.name == name { user = it; break; } // I know I know
    if !user return exists = false;
    return user;
}

// not every website makes the following equivalence, but this one does, because
// we only use sessions for logged-in users
logged_in :: () => in_session();


main :: () {
    init_template_system();


    add_user("admin", "hunter2");


    before_route(() {
        Set("current_year", 2021);
        Set("site_title", "News");
        current_user_id, logged_in := Get_Session_Int("user_id");
        if logged_in {
            current_user, current_user_exists := get_user(current_user_id);
            Set("current_user_id", current_user_id);
            Set("current_user_name", current_user.name);
            Set("nav_user", Render("nav_user/logged_in"));
        }
        else Set("nav_user", Render("nav_user/default"));
    });


    // homepage
    route(.GET, "/", () {
        Set("page_title", "Homepage");
        Set("stories", Render_Each(stories, #code Render_It("story/header", it.id, it.headline)));
        Set("body", Render("home"));
        Respond(Render("index"));
    });
    // story detail
    route(.GET, "/story/:id", () {
        id, id_valid := Get_Int("id");
        if !id_valid then Reroute(not_found);
        story, story_exists := get_story(id);
        if !story_exists then Reroute(not_found);
        Set("page_title", story.headline);
        Set("body", Render("story",
            Render("story/header", story.id, story.headline),
            Render("story/body", story.body)
        ));
        Respond(Render("index"));
    });
    // story submission form
    route(.GET, "/submit", story_submission_form);
    story_submission_form :: () {
        if !logged_in() {
            Toast("You must be logged in to submit a story.");
            Redirect("/login");
        }
        Set("page_title", "Submit story");
        Set("body", Render("submit"));
        Respond(Render("index"));
    }
    // story submission
    route(.POST, "/submit", () {
        headline, headline_given := Get("headline");
        if !headline_given then Toast("Did not provide headline.");
        body, body_given := Get("body");
        if !body_given then Toast("Did not provide body.");
        if !headline_given || !body_given {
            Set("submission_headline", headline);
            Set("submission_body", body);
            Reroute(story_submission_form);
        }
        id := add_story(headline, body);
        Redirect("/story/%", id);
    });
    // user page
    route(.GET, "/user/:name", () {
        name, _ := Get("name");
        user, user_exists := get_user(name);
        if !user_exists then Reroute(not_found);
        Set("user_name", user.name);
        Set("user_submission", "TODO");
        Set("user_comments", "TODO");
        Respond(Render("user"));
    });
    // user login form
    route(.GET, "/login", login_form);
    login_form :: () {
        Set("page_title", "Log in");
        Set("body", Render("login"));
        Respond(Render("index"));
    }
    // user login
    route(.POST, "/login", () {
        name, name_given := Get("name");
        if !name_given {
            Toast("No user name provided.");
            Reroute(login_form);
        }
        user, user_exists := get_user(name);
        if !user_exists {
            Toast("User does not exist.");
            Reroute(login_form);
        }
        password, password_given := Get("password");
        if !password_given {
            Toast("No password provided.");
            Set("login_name", name);
            Reroute(login_form);
        }
        if md5(password) != user.password_hash {
            Toast("Invalid password.");
            Set("login_name", name);
            Reroute(login_form);
        }
        Set_Session("user_id", user.id);
        Toast("Logged in successfully. 😀");
        Redirect("/");
    });
    // user logout
    route(.GET, "/logout", () {
        end_session();
        Toast("Logged out successfully.");
        Toast("Please come again.");
        Redirect("/");
    });
    // catch-all 404
    route(.GET, "*", "*", not_found);
    not_found :: () {
        Set("page_title", "page not found");
        Set("body", Render("404"));
        Respond(Render("index"), status=404);
    }


    listen(8000);
}

#import "Web_Framework";
#import "Hash_Table";
#import "Basic";
