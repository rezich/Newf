//------------------------------------------------------------------------------
// Models
Comment :: struct { using base: Model;
    story: *Story;
    parent: *Comment;
    commenter: *User;
    body: string;
}
Story :: struct @plural=stories { using base: Model;
    submitter: *User;
    headline: string;
    body: string;
    //score: Score; Score :: #type int;
}
User :: struct { using base: Model;
    name: string;
    password_hash: string;
}
Vote :: struct { using base: Model;
    voter: *User;
    story: *Story;
    //score: Story.Score;
}


// helper function, might not be needed if we change how routing works
respond_index :: (page_title: string, body: string, status: HTTP_Status=200) {
    set("page_title", page_title);
    set("body", body);
    respond(render("index"), status=status);
}


main :: () {
    {
        file_delete("database.db"); // obviously this won't be here later
        db_open(); defer db_close();
        query_exec(#string XX
CREATE TABLE Comment(
    id              INTEGER PRIMARY KEY,
    parent_id       INTEGER,
    commenter_id    INTEGER,
    body            TEXT,
    FOREIGN KEY(parent_id) REFERENCES Comment(id),
    FOREIGN KEY(commenter_id) REFERENCES User(id)
);
CREATE TABLE Story(
    id              INTEGER PRIMARY KEY,
    submitter_id    INTEGER,
    headline        TEXT,
    body            TEXT,
    FOREIGN KEY(submitter_id) REFERENCES User(id)
);
CREATE TABLE User(
    id              INTEGER PRIMARY KEY,
    name            TEXT,
    password_hash   TEXT
);
CREATE TABLE Vote(
    id              INTEGER PRIMARY KEY,
    voter_id        INTEGER,
    story_id        INTEGER,
    FOREIGN KEY(voter_id) REFERENCES User(id),
    FOREIGN KEY(story_id) REFERENCES Story(id)
);
XX      );
    }
    {
        admin: User;
        admin.name = "admin";
        admin.password_hash = md5("hunter2");
        insert(admin);
    }
    {
        story: Story;
        story.headline = "First Story?";
        story.body = "This is the first NEW story.";
        insert(story);
    }
    {
        story: Story;
        story.headline = "Second Story";
        story.body = "This is the second story.";
        insert(story);
    }
    {
        story: Story;
        story.headline = "Third Story";
        story.body = "This is the third story.";
        insert(story);
    }
    {
        story: Story;
        story.headline = "Fourth Story";
        story.body = "This is the fourth story.";
        insert(story);
    }

    before_route(() {
        year := filetime_to_localtime(get_current_file_time());
        set("current_year", year);
        set("site_title", "Something News");
        current_user_id, logged_in := get_session_int("user_id");
        if logged_in {
            user_result := select_from(User, where=tprint("id=%", current_user_id));
            if user_result.count != 0 {
                current_user := user_result[0];
                set("current_user_id", current_user_id);
                set("current_user_name", current_user.name);
                set("nav_user", render("nav_user/logged_in"));
            }
            //TODO: handle failure?
        }
        else set("nav_user", render("nav_user/default"));
    });


    // homepage
    route(.GET, "/", () {
        set("stories", render_each(select_from(Story, limit=2, offset=2),
            #code { render_it("story/header", it.id, it.headline); }, 
            "<em>There are no stories to display at the moment.</em>"
        ));
        respond_index("Homepage", render("home"));
    });
    // story detail
    route(.GET, "/story/:id", () {
        id, id_valid := get_int("id");
        if !id_valid then reroute(not_found);
        results := select_from(Story, where=tprint("id=%", id));
        if results.count == 0 then reroute(not_found);
        story := results[0];

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
        story: Story;
        headline_given, body_given: bool;
        story.headline, headline_given = get("headline");
        if !headline_given then toast("Did not provide headline.");
        story.body, body_given = get("body");
        if !body_given then toast("Did not provide body.");
        if !headline_given || !body_given {
            set("submission_headline", story.headline);
            set("submission_body", story.body);
            reroute(story_submission_form);
        }
        id := insert(story);
        toast("Story was submitted successfully.");
        redirect("/story/%", id);
    });
    // user detail
    route(.GET, "/user/:name", () {
        name, _ := get("name");
        user_result := select_from(User, where=tprint("name=\"%\"", name));
        if user_result.count == 0 then reroute(not_found);
        user := user_result[0];
        set("user_name", user.name);
        set("user_id", user.id);
        set("user_submissions", render_each(
            select_from(Story, where=tprint("submitter_id = %", get_int("user_id"))),
            #code { render_it("story/header", it.id, it.headline); },
            "<em>This user has not submitted any stories.</em>"
        ));
        set("user_comments", render_each(
            select_from(Comment, where=tprint("commenter_id = %", get_int("user_id"))),
            #code { /* TODO */ },
            "<em>This user has not posted any comments.</em>"
        ));
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
        user_result := select_from(User, where=tprint("name=\"%\"", name));
        if user_result.count == 0 {
            toast("User does not exist.");
            reroute(login_form);
        }
        user := user_result[0];
        print("$$\n%\n$$\n", user);
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
    register_form :: () { respond_index("Register account", render("register")); }
    // user register
    route(.POST, "/register", () {
        name, name_given := get("name");
        if !name_given {
            toast("No user name provided.");
            reroute(register_form);
        }
        user_result := select_from(User, where=tprint("name=\"%\"", name));
        if user_result.count != 0 {
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
        user: User;
        user.name = name;
        user.password_hash = md5(password);
        user_id := insert(user);
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
#import "Time";
#import "File";
