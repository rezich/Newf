SITE_TITLE :: "Dorknews";

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
    stories: [..] *Story; @fk=submitter;
    //comments: [..] *Comment; @fk=commenter;
}
Vote :: struct { using base: Model;
    voter: *User;
    story: *Story;
    //score: Story.Score;
}


// helper function, might not be needed if we change how routing works
Respond_Index :: (page_title: string, body: string, status: HTTP_Status=200) #expand {
    param_set("page_title", page_title);
    param_set("body", body);
    Respond(render("index"), status=status);
}
setup_test_database :: () {
    file_delete("database.db"); // obviously this won't be here later
    {
        db_open(); defer db_close();
        query_exec(database_schema);
    }
    {
        admin: User;
        admin.name = "admin";
        admin.password_hash = md5("hunter2");
        insert(admin);
    }
    admin: *User;
    {
        results := select_from(User, where="id=1");
        admin = results[0];
    }
    {
        story: Story;
        story.headline = "First Story?";
        story.body = "This is the first NEW story.";
        story.submitter = admin;
        insert(story);
    }
    {
        story: Story;
        story.headline = "Second Story";
        story.body = "This is the second story.";
        story.submitter = admin;
        insert(story);
    }
    {
        story: Story;
        story.headline = "Third Story";
        story.body = "This is the third story.";
        story.submitter = admin;
        insert(story);
    }
    {
        story: Story;
        story.headline = "Fourth Story";
        story.body = "This is the fourth story.";
        story.submitter = admin;
        insert(story);
    }
}

main :: () {
    set_model_infos();
    setup_test_database();

    // global before-route -----------------------------------------------------
    before_route(() {
        now := filetime_to_local_time(get_current_file_time());
        param_set("current_year", now.year);
        param_set("site_title", SITE_TITLE);
        current_user_id, logged_in := session_get_int("user_id");
        if logged_in {
            user_result := select_from(User, where=tprint("id=%", current_user_id));
            if user_result.count != 0 {
                current_user := user_result[0];
                param_set("current_user_id", current_user_id);
                param_set("current_user_name", current_user.name);
                param_set("nav_user", render("nav_user/logged_in"));
            }
            //TODO: handle failure?
        }
        else param_set("nav_user", render("nav_user/default"));
    });

    // homepage ----------------------------------------------------------------
    route(.GET, "/", () {
        param_set("stories", render_each(select_from(Story, limit=2, offset=2),
            #code { render_it("story/header", it.id, it.headline); },
            "<em>There are no stories to display at the moment.</em>"
        ));
        Respond_Index("Homepage", render("home"));
    });

    // story detail ------------------------------------------------------------
    route(.GET, "/story/:id", () {
        id, id_valid := param_get_int("id");
        if !id_valid then Reroute(not_found);
        results := select_from(Story, where=tprint("id=%", id));
        if results.count == 0 then Reroute(not_found);
        story := results[0];
        Respond_Index(
            story.headline,
            render("story",
                render("story/header", story.id, story.headline),
                render("story/body", story.body)
        ));
    });

    // story submission form ---------------------------------------------------
    route(.GET, "/submit", story_submission_form);
    story_submission_form :: () {
        _, logged_in := session_get_int("user_id");
        if !logged_in {
            toast("You must be logged in to submit a story.");
            Redirect("/login");
        }
        Respond_Index("Submit story", render("submit"));
    }

    // story submission --------------------------------------------------------
    route(.POST, "/submit", () {
        story: Story;
        headline_given, body_given: bool;
        story.headline, headline_given = param_get("headline");
        if !headline_given then toast("Did not provide headline.");
        story.body, body_given = param_get("body");
        if !body_given then toast("Did not provide body.");
        if !headline_given || !body_given {
            param_set("submission_headline", story.headline);
            param_set("submission_body", story.body);
            Reroute(story_submission_form);
        }
        id := insert(story);
        toast("Story was submitted successfully.");
        Redirect("/story/%", id);
    });

    // user detail -------------------------------------------------------------
    route(.GET, "/user/:name", () {
        name, _ := param_get("name");
        user_result := select_from(User, where=tprint("name=\"%\"", name), fetch=.["stories"/*, "comments"*/]); // fetch doesn't work yet
        if user_result.count == 0 then Reroute(not_found);
        user := user_result[0];
        param_set("user_name", user.name);
        param_set("user_id", user.id);
        param_set("user_submissions", render_each(
            user.stories,
            //select_from(Story, where=tprint("submitter_id = %", param_get_int("user_id"))),
            #code { render_it("story/header", it.id, it.headline); },
            "<em>This user has not submitted any stories.</em>"
        ));
        param_set("user_comments", render_each(
            select_from(Comment, where=tprint("commenter_id = %", param_get_int("user_id"))),
            #code { /* TODO */ },
            "<em>This user has not posted any comments.</em>"
        ));
        Respond_Index(tprint("user %", user.name), render("user"));
    });

    // user login form ---------------------------------------------------------
    route(.GET, "/login", login_form);
    login_form :: () { Respond_Index("Log in", render("login")); }

    // user login --------------------------------------------------------------
    route(.POST, "/login", () {
        name, name_given := param_get("name");
        if !name_given {
            toast("No user name provided.");
            Reroute(login_form);
        }
        user_result := select_from(User, where=tprint("name=\"%\"", name));
        if user_result.count == 0 {
            toast("User does not exist.");
            Reroute(login_form);
        }
        user := user_result[0];
        print("$$\n%\n$$\n", user);
        password, password_given := param_get("password");
        if !password_given {
            toast("No password provided.");
            param_set("login_name", name);
            Reroute(login_form);
        }
        if md5(password) != user.password_hash {
            toast("Invalid password.");
            param_set("login_name", name);
            Reroute(login_form);
        }
        session_set("user_id", user.id);
        toast("Logged in successfully. 😀"); // we can encode emoji in cookies!
        Redirect("/");
    });

    // user register form ------------------------------------------------------
    route(.GET, "/register", register_form);
    register_form :: () { Respond_Index("Register account", render("register")); }

    // user register -----------------------------------------------------------
    route(.POST, "/register", () {
        name, name_given := param_get("name");
        if !name_given {
            toast("No user name provided.");
            Reroute(register_form);
        }
        user_result := select_from(User, where=tprint("name=\"%\"", name));
        if user_result.count != 0 {
            toast("User name is already taken.");
            Reroute(register_form);
        }
        password, password_given := param_get("password");
        if !password_given {
            toast("No password provided.");
            param_set("register_name", name);
            Reroute(register_form);
        }
        password_confirm, password_confirm_given := param_get("password_confirm");
        if !password_confirm_given {
            toast("No password confirmation provided.");
            param_set("register_name", name);
            Reroute(register_form);
        }
        if password != password_confirm {
            toast("Password and password confirmation do not match.");
            param_set("register_name", name);
            Reroute(register_form);
        }
        user: User;
        user.name = name;
        user.password_hash = md5(password);
        user_id := insert(user);
        session_set("user_id", user_id);
        toast("Registered and logged in successfully. 😀");
        Redirect("/");
    });

    // user logout -------------------------------------------------------------
    route(.GET, "/logout", () {
        end_session();
        cookie_unset("saved_name");
        cookie_unset("saved_password");
        toast("Logged out successfully.");
        Redirect("/");
    });

    // catch-all 404 -----------------------------------------------------------
    route(.GET, "*", "*", not_found);
    not_found :: () { Respond_Index("Not found", render("404"), status=404); }


    listen(8000);
}

#import "Newf";
#import "Hash_Table";
#import "Basic";
#import "File";
#import "md5";
#import "Time";
