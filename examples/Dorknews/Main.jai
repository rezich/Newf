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
    payload := `payload; using payload;
    set(req, "page_title", page_title);
    set(req, "body", body);
    Respond(Render("index"), status=status);
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
    before_route((using payload: Route.Payload) {
        now := filetime_to_local_time(get_current_file_time());
        set(req, "current_year", now.year);
        set(req, "site_title", SITE_TITLE);
        current_user_id, logged_in := Get_Session_Int("user_id");
        if logged_in {
            user_result := select_from(User, where=tprint("id=%", current_user_id));
            if user_result.count != 0 {
                current_user := user_result[0];
                set(req, "current_user_id", current_user_id);
                set(req, "current_user_name", current_user.name);
                set(req, "nav_user", Render("nav_user/logged_in"));
            }
            //TODO: handle failure?
        }
        else set(req, "nav_user", Render("nav_user/default"));
    });
    // homepage ----------------------------------------------------------------
    route(.GET, "/", (using payload: Route.Payload) {
        set(req, "stories", Render_Each(select_from(Story, limit=2, offset=2),
            #code { Render_It("story/header", it.id, it.headline); },
            "<em>There are no stories to display at the moment.</em>"
        ));
        Respond_Index("Homepage", Render("home"));
    });
    // story detail ------------------------------------------------------------
    route(.GET, "/story/:id", (using payload: Route.Payload) {
        id, id_valid := get_int(req, "id");
        if !id_valid then Reroute(not_found);
        results := select_from(Story, where=tprint("id=%", id));
        if results.count == 0 then Reroute(not_found);
        story := results[0];

        Respond_Index(
            story.headline,
            Render("story",
                Render("story/header", story.id, story.headline),
                Render("story/body", story.body)
        ));
    });
    // story submission form ---------------------------------------------------
    route(.GET, "/submit", story_submission_form);
    story_submission_form :: (using payload: Route.Payload) {
        _, logged_in := Get_Session_Int("user_id");
        if !logged_in {
            Toast("You must be logged in to submit a story.");
            Redirect("/login");
        }
        Respond_Index("Submit story", Render("submit"));
    }
    // story submission --------------------------------------------------------
    route(.POST, "/submit", (using payload: Route.Payload) {
        story: Story;
        headline_given, body_given: bool;
        story.headline, headline_given = get(req, "headline");
        if !headline_given then Toast("Did not provide headline.");
        story.body, body_given = get(req, "body");
        if !body_given then Toast("Did not provide body.");
        if !headline_given || !body_given {
            set(req, "submission_headline", story.headline);
            set(req, "submission_body", story.body);
            Reroute(story_submission_form);
        }
        id := insert(story);
        Toast("Story was submitted successfully.");
        Redirect("/story/%", id);
    });
    // user detail -------------------------------------------------------------
    route(.GET, "/user/:name", (using payload: Route.Payload) {
        name, _ := get(req, "name");
        user_result := select_from(User, where=tprint("name=\"%\"", name), fetch=.["stories"/*, "comments"*/]); // fetch doesn't work yet
        if user_result.count == 0 then Reroute(not_found);
        user := user_result[0];
        set(req, "user_name", user.name);
        set(req, "user_id", user.id);
        set(req, "user_submissions", Render_Each(
            user.stories,
            //select_from(Story, where=tprint("submitter_id = %", get_int("user_id"))),
            #code { Render_It("story/header", it.id, it.headline); },
            "<em>This user has not submitted any stories.</em>"
        ));
        set(req, "user_comments", Render_Each(
            select_from(Comment, where=tprint("commenter_id = %", get_int(req, "user_id"))),
            #code { /* TODO */ },
            "<em>This user has not posted any comments.</em>"
        ));
        Respond_Index(tprint("user %", user.name), Render("user"));
    });
    // user login form ---------------------------------------------------------
    route(.GET, "/login", login_form);
    login_form :: (using payload: Route.Payload) { Respond_Index("Log in", Render("login")); }
    // user login --------------------------------------------------------------
    route(.POST, "/login", (using payload: Route.Payload) {
        name, name_given := get(req, "name");
        if !name_given {
            Toast("No user name provided.");
            Reroute(login_form);
        }
        user_result := select_from(User, where=tprint("name=\"%\"", name));
        if user_result.count == 0 {
            Toast("User does not exist.");
            Reroute(login_form);
        }
        user := user_result[0];
        print("$$\n%\n$$\n", user);
        password, password_given := get(req, "password");
        if !password_given {
            Toast("No password provided.");
            set(req, "login_name", name);
            Reroute(login_form);
        }
        if md5(password) != user.password_hash {
            Toast("Invalid password.");
            set(req, "login_name", name);
            Reroute(login_form);
        }
        Set_Session("user_id", user.id);
        Toast("Logged in successfully. 😀"); // we can encode emoji in cookies!
        Redirect("/");
    });
    // user register form ------------------------------------------------------
    route(.GET, "/register", register_form);
    register_form :: (using payload: Route.Payload) { Respond_Index("Register account", Render("register")); }
    // user register -----------------------------------------------------------
    route(.POST, "/register", (using payload: Route.Payload) {
        name, name_given := get(req, "name");
        if !name_given {
            Toast("No user name provided.");
            Reroute(register_form);
        }
        user_result := select_from(User, where=tprint("name=\"%\"", name));
        if user_result.count != 0 {
            Toast("User name is already taken.");
            Reroute(register_form);
        }
        password, password_given := get(req, "password");
        if !password_given {
            Toast("No password provided.");
            set(req, "register_name", name);
            Reroute(register_form);
        }
        password_confirm, password_confirm_given := get(req, "password_confirm");
        if !password_confirm_given {
            Toast("No password confirmation provided.");
            set(req, "register_name", name);
            Reroute(register_form);
        }
        if password != password_confirm {
            Toast("Password and password confirmation do not match.");
            set(req, "register_name", name);
            Reroute(register_form);
        }
        user: User;
        user.name = name;
        user.password_hash = md5(password);
        user_id := insert(user);
        Set_Session("user_id", user_id);
        Toast("Registered and logged in successfully. 😀");
        Redirect("/");
    });
    // user logout -------------------------------------------------------------
    route(.GET, "/logout", (using payload: Route.Payload) {
        end_session(res);
        unset_cookie(res, "saved_name");
        unset_cookie(res, "saved_password");
        Toast("Logged out successfully.");
        Redirect("/");
    });
    // catch-all 404 -----------------------------------------------------------
    route(.GET, "*", "*", not_found);
    not_found :: (using payload: Route.Payload) { }


    listen(8000);
}

#import "Newf";
#import "Hash_Table";
#import "Basic";
#import "File";
#import "md5";
#import "Time";
