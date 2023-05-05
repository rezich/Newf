set_routes :: () {

Respond_Index :: (page_title: string, body: string, status: HTTP_Status=200) #expand {
    param_set("page_title", page_title);
    param_set("body", body);
    Respond(render("index"), status=status);
}


before_route(() {
    param_set("current_year", to_calendar(current_time_consensus()).year);
    param_set("site_title", "Dorknews");
    current_user_id, logged_in := session_get_int("user_id");
    if logged_in {
        user := select_by_id(User, current_user_id) ? #code {
            param_set("nav_user", render("nav_user/default"));
            Reroute(login_form, "Something happened—please log in again.");
            //TODO: make sure this works
        };
        param_set("current_user_id", user.id);
        param_set("current_user_name", user.name);
        param_set("nav_user", render("nav_user/logged_in"));
    }
    else param_set("nav_user", render("nav_user/default"));
});


// landing page
route(.GET, "/", () {
    param_set("submissions", render_each(The_Algo(),
        #code { render_it("submission/header", it.id, it.headline, it.submitter.name); },
        "<i>There are no submissions to display at the moment.</i>"
    ));
    Respond_Index("Homepage", render("home"));
});


// submission detail
route(.GET, "/submission/:id", () {
    id, id_valid := param_get_int("id");
    if !id_valid then Reroute(not_found);

    submission := select_by_id(Submission, id) ? Reroute(not_found);

    Respond_Index(
        submission.headline,
        render("submission",
            render("submission/header", submission.id, submission.headline, submission.submitter.name),
            submission.body,
            render_comments_for(submission)
        )
    );
});


// submission form
route(.GET, "/submit", new_submission_form);
new_submission_form :: () {
    if !is_logged_in() then Redirect("/login", "You must be logged in to submit a story.");
    Respond_Index("Submit story", render("submit"));
}


// submission process
route(.POST, "/submit", () {
    new_submission: Submission;
    headline_given, body_given: bool;

    new_submission.headline, headline_given = param_get("headline");
    if !headline_given then toast("Did not provide headline.");

    new_submission.body, body_given = param_get("body");
    if !body_given then toast("Did not provide body.");

    if !headline_given || !body_given {
        param_set("submission_headline", new_submission.headline);
        param_set("submission_body", new_submission.body);
        Reroute(new_submission_form);
    }

    new_submission.submitter = Get_Logged_In_User(); //TODO: replace with something not bad!!

    submission := insert(new_submission);

    Redirect(tprint("/submission/%", submission.id), "Submission was submitted successfully.");
});


// user detail
route(.GET, "/user/:name", () {
    name, _ := param_get("name");

    user := select_from(User, where="name = ?", name, limit=1) ? Reroute(not_found);
    submissions := select_from(Submission, where="submitter_id = ?", user.id);

    param_set("user_name", user.name);
    param_set("user_id", user.id);
    param_set("user_submissions", render_each(submissions,
        #code { render_it("submission/header", it.id, it.headline); },
        "<i>This user has not submitted anything.</i>"
    ));
    param_set("user_comments", render_each(void.[], //TODO
        #code,null, //TODO
        "<i>This user has not written any comments.</i>"
    ));

    Respond_Index(tprint("user %", user.name), render("user"));
});


// login form
route(.GET, "/login", login_form);
login_form :: () {
    if is_logged_in() then Redirect("/", "You are already logged in!");
    Respond_Index("Log in", render("login"));
}


// login process
route(.POST, "/login", () {
    name, name_given := param_get("name");
    if !name_given then Reroute(login_form, "No user name provided");

    user := select_from(User, where="name = ?", name, limit=1) ? Reroute(login_form, "User does not exist");

    password, password_given := param_get("password");
    if !password_given {
        param_set("login_name", name);
        Reroute(login_form, "No password provided.");
    }

    if md5(password) != user.password_hash {
        param_set("login_name", name);
        Reroute(login_form, "Invalid password.");
    }

    session_set("user_id", user.id);
    Redirect("/", "Logged in successfully. 😀");
});


// register form
route(.GET, "/register", register_form);
register_form :: () { Respond_Index("Register account", render("register")); }


// register process
route(.POST, "/register", () {
    name, name_given := param_get("name");
    if !name_given then Reroute(register_form, "No user name provided.");

    user := select_from(User, where="name = ?", name, limit=1) ? Reroute(register_form, "User name is already taken.");

    password, password_given := param_get("password");
    if !password_given {
        param_set("register_name", name);
        Reroute(register_form, "No password provided.");
    }

    password_confirm, password_confirm_given := param_get("password_confirm");
    if !password_confirm_given {
        param_set("register_name", name);
        Reroute(register_form, "No password confirmation provided.");
    }

    if password != password_confirm {
        param_set("register_name", name);
        Reroute(register_form, "Password and password confirmation do not match.");
    }

    new_user := insert(User.{name=name, password_hash=md5(password)});

    session_set("user_id", new_user.id);
    Redirect("/", "Registered and logged in successfully. 😀");
});


// logout
route(.GET, "/logout", () {
    end_session();
    cookie_unset("saved_name");
    cookie_unset("saved_password");
    Redirect("/", "Logged out successfully.");
});


// favicon
route(.GET, "/favicon.ico", () {
    Respond(status=404);
});


// catch-all 404
route(.GET, "*", "*", not_found);
not_found :: () { Respond_Index("Not found", render("404"), status=404); }

}
