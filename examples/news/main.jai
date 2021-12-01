//------------------------------------------------------------------------------
// Models
Comment :: struct {
    id: ID; ID :: #type int;
    story_id: Story.ID;
    parent_id: Comment.ID;
    user_id: User.ID;
    body: string;
}
Story :: struct {
    id: ID; ID :: #type int;
    submitter_id: User.ID;
    headline: string;
    body: string;
    score: Score; Score :: #type int;
}
User :: struct {
    id: ID; ID :: #type int;
    name: string;
    password_hash: string;
}
Vote :: struct {
    id: ID; ID :: #type int;
    user_id: User.ID;
    story_id: Story.ID;
    score: Story.Score;
}

//------------------------------------------------------------------------------
// Database (non-persistent)
comments: [..] Comment;
stories: [..] Story;
Story_insert :: (headline: string, body: string) -> Story.ID {
    story: Story;
    story.id = stories.count + 1;
    story.headline = headline;
    story.body = body;
    array_add(*stories, story);
    return story.id;
}
Story_get :: (id: Story.ID) -> story: *Story = null, exists: bool = true {
    if id-1 >= stories.count return exists = false;
    return *stories[id-1];
}

users: [..] User;
User_insert :: (name: string, password: string) -> User.ID {
    user: User;
    user.id = users.count + 1;
    user.name = name;
    user.password_hash = md5(password);
    array_add(*users, user);
    return user.id;
}
User_get :: (id: User.ID) -> user: *User = null, exists: bool = true {
    if id-1 >= users.count return exists = false;
    return *users[id-1];
}
User_get :: (name: string) -> user: *User = null, exists: bool = true {
    user: *User = null;
    for * users if it.name == name { user = it; break; } // I know I know
    if !user return exists = false;
    return user;
}

votes: [..] Vote;
Vote_insert :: (user: User, story: Story, score: Story.Score) {
    vote: Vote;
    vote.id = votes.count + 1;
    vote.user_id = user.id;
    vote.story_id = story.id;
    vote.score = score;
    array_add(*votes, vote);
}

Select_From :: (items: [] $T, where: (*T) -> bool=null) -> [..] T {
    results: [..] T;
    for items if !where || where(*it) then array_add(*results, it);
    return results;
}


// helper function, might not be needed if we change how routing works
respond_index :: (page_title: string, body: string, status: HTTP_Status=200) {
    set("page_title", page_title);
    set("body", body);
    respond(render("index"), status=status);
}


main :: () {
    User_insert("admin", "hunter2");


    before_route(() {
        set("current_year", 2021);
        set("site_title", "News");
        current_user_id, logged_in := get_session_int("user_id");
        if logged_in {
            current_user, current_user_exists := User_get(current_user_id);
            set("current_user_id", current_user_id);
            set("current_user_name", current_user.name);
            set("nav_user", render("nav_user/logged_in"));
        }
        else set("nav_user", render("nav_user/default"));
    });


    // homepage
    route(.GET, "/", () {
        set("stories", render_each(Select_From(stories), #code
            { render_it("story/header", it.id, it.headline); }, 
            "<em>There are no stories to display at the moment.</em>"
        ));
        respond_index("Homepage", render("home"));
    });
    // story detail
    route(.GET, "/story/:id", () {
        id, id_valid := get_int("id");
        if !id_valid then reroute(not_found);
        story, story_exists := Story_get(id);
        if !story_exists then reroute(not_found);

        respond_index(story.headline, render("story",
            render("story/header", story.id, story.headline),
            render("story/body", story.body)
        ));
    });
    // story submission form
    route(.GET, "/submit", story_submission_form);
    story_submission_form :: () {
        _, logged_in := get_session_int("user_id");
        if !logged_in {
            toast("You must be logged in to submit a story.");
            redirect("/login");
        }
        respond_index("Submit story", render("submit"));
    }
    // story submission
    route(.POST, "/submit", () {
        headline, headline_given := get("headline");
        if !headline_given then toast("Did not provide headline.");
        body, body_given := get("body");
        if !body_given then toast("Did not provide body.");
        if !headline_given || !body_given {
            set("submission_headline", headline);
            set("submission_body", body);
            reroute(story_submission_form);
        }
        id := Story_insert(headline, body);
        toast("Story was submitted successfully.");
        redirect("/story/%", id);
    });
    // user page
    route(.GET, "/user/:name", () {
        name, _ := get("name");
        user, user_exists := User_get(name);
        if !user_exists then reroute(not_found);
        set("user_name", user.name);
        set("user_id", user.id);
        set("user_submissions", render_each(
            Select_From(stories, where=(x)=>x.submitter_id==get_int("user_id")),
            #code { render_it("story/header", it.id, it.headline); },
            "<em>This user has not submitted any stories.</em>"
        ));
        set("user_comments", "TODO");
        respond_index(tprint("user %", user.name), render("user"));
    });
    // user login form
    route(.GET, "/login", login_form);
    login_form :: () { respond_index("Log in", render("login")); }
    // user login
    route(.POST, "/login", () {
        name, name_given := get("name");
        if !name_given {
            toast("No user name provided.");
            reroute(login_form);
        }
        user, user_exists := User_get(name);
        if !user_exists {
            toast("User does not exist.");
            reroute(login_form);
        }
        password, password_given := get("password");
        if !password_given {
            toast("No password provided.");
            set("login_name", name);
            reroute(login_form);
        }
        if md5(password) != user.password_hash {
            toast("Invalid password.");
            set("login_name", name);
            reroute(login_form);
        }
        set_session("user_id", user.id);
        toast("Logged in successfully. 😀"); // we can encode emoji in cookies!
        redirect("/");
    });
    // user register form
    route(.GET, "/register", register_form);
    register_form :: () { respond_index("Register", render("register")); }
    // user register
    route(.POST, "/register", () {
        name, name_given := get("name");
        if !name_given {
            toast("No user name provided.");
            reroute(register_form);
        }
        _, user_exists := User_get(name);
        if user_exists {
            toast("User name is already taken.");
            reroute(register_form);
        }
        password, password_given := get("password");
        if !password_given {
            toast("No password provided.");
            set("register_name", name);
            reroute(register_form);
        }
        password_confirm, password_confirm_given := get("password_confirm");
        if !password_confirm_given {
            toast("No password confirmation provided.");
            set("register_name", name);
            reroute(register_form);
        }
        if password != password_confirm {
            toast("Password and password confirmation do not match.");
            set("register_name", name);
            reroute(register_form);
        }
        user_id := User_insert(name, md5(password));
        set_session("user_id", user_id);
        toast("Registered and logged in successfully. 😀");
        redirect("/");
    });
    // user logout
    route(.GET, "/logout", () {
        end_session();
        unset_cookie("saved_name");
        unset_cookie("saved_password");
        toast("Logged out successfully.");
        redirect("/");
    });
    // catch-all 404
    route(.GET, "*", "*", not_found);
    not_found :: () { respond_index("Page not found", render("404"), status=404); }


    listen(8000);
}

#import "Web_Framework";
#import "Hash_Table";
#import "Basic";
