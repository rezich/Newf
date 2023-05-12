is_logged_in :: () -> bool {
    using context.reqres;
    if !session then return false;
    return session.user_id != 0;
}

set_routes :: () {


before_route(() { if is_logged_in() then context.reqres.state.current_user = select_by_id(User, context.reqres.session.user_id) ? assert(false, "THIS SHOULD NEVER HAPPEN"); });


Respond_Index :: (page_title: string, body: string, status: HTTP_Status=200) #expand {
    Index :: struct {
        site_title:   string;
        page_title:   string;
        toasts:    [] Toast;
        nav_user:     string;
        body:         string;
        current_year: int;
    }
    Respond(Render("index", Index.{
        site_title="Dorknews",
        page_title=page_title,
        toasts=get_toasts(),
        nav_user=ifx is_logged_in() then Render("nav_user/logged_in") else Render("nav_user/default"),
        body=body,
        current_year=to_calendar(current_time_consensus()).year
    }), status=status);
}




//== LANDING PAGE ==================================================================================
route(.GET, "/", () {
    Respond_Index("Homepage", Render("submission/header", The_Algo()));
}/*, cache=.{20}*/); // cache does not work yet




//== SUBMISSION ====================================================================================

//---- submission detail -------------------------------------------------------
route(.GET, "/submission/:id", () {
    id, id_valid := param_get_int("id");
    if !id_valid then Reroute(not_found);

    submission := select_by_id(Submission, id) ? Reroute(not_found);
    fetch_comments(*submission);

    Respond_Index(
        submission.headline,
        Render("submission", submission)
    );
});

//---- submission form ---------------------------------------------------------
route(.GET, "/submit", new_submission_form);
new_submission_form :: () {
    if !is_logged_in() then Redirect("/login", "You must be logged in to submit a story.");
    Respond_Index("Submit story", Render("submit", Submission.{
        headline=param_get("submission_headline"),
        body=param_get("submission_body")
    }));
}

//---- submission process ------------------------------------------------------
route(.POST, "/submit", () {
    if !is_logged_in() then Redirect("/login", "You must be logged in to submit a story.");
    new_submission: Submission;
    headline_given, body_given: bool;

    new_submission.headline, headline_given = param_get("headline");
    if !headline_given then toast("Did not provide headline.");

    new_submission.body, body_given = param_get("body");
    if !body_given then toast("Did not provide body.");

    if !headline_given || !body_given {
        //param_set("submission_headline", new_submission.headline);
        //param_set("submission_body", new_submission.body);
        Reroute(new_submission_form);
    }

    new_submission.submitter = context.reqres.state.current_user;

    submission := insert(new_submission);

    Redirect(tprint("/submission/%", submission.id), "Submission was submitted successfully.");
});




//== USER / AUTH ===================================================================================

//---- user detail -------------------------------------------------------------
route(.GET, "/user/:name", () {
    name := param_get("name");

    user := select_from(User, where="name = ?", name, limit=1) ? Reroute(not_found);
    user.submissions = select_from(Submission, where="submitter_id = ?", user.id);

    Respond_Index(tprint("user %", user.name), Render("user", user));
});

//---- login form --------------------------------------------------------------
route(.GET, "/login", login_form);
login_form :: () {
    if is_logged_in() then Redirect("/", "You are already logged in!");
    Login_Form :: struct { login_name: string; }
    Respond_Index("Log in", Render("login", Login_Form.{login_name=""}));
}

//---- login process -----------------------------------------------------------
route(.POST, "/login", () {
    name, name_given := param_get("name");
    if !name_given || name == "" then Reroute(login_form, "No user name provided.");

    user := select_from(User, where="name = ?", name, limit=1) ? Reroute(login_form, "User does not exist.");

    password, password_given := param_get("password");
    if !password_given {
        //param_set("login_name", name);
        Reroute(login_form, "No password provided.");
    }

    if md5(password) != user.password_hash {
        //param_set("login_name", name);
        Reroute(login_form, "Invalid password.");
    }

    begin_session();
    context.reqres.session.user_id = user.id;
    Redirect("/", "Logged in successfully. 😀");
});

//---- register form -----------------------------------------------------------
route(.GET, "/register", register_form);
register_form :: () {
    Register :: struct { register_name: string; }
    register := Register.{param_get("register_username")};
    Respond_Index("Register account", Render("register", register));
}

//---- register process --------------------------------------------------------
route(.POST, "/register", () {
    name, name_given := param_get("name");
    if !name_given then Reroute(register_form, "No user name provided.");

    user := select_from(User, where="name = ?", name, limit=1);
    if !is_null(user) then Reroute(register_form, "User name is already taken.");

    password, password_given := param_get("password");
    if !password_given {
        //param_set("register_name", name);
        Reroute(register_form, "No password provided.");
    }

    password_confirm, password_confirm_given := param_get("password_confirm");
    if !password_confirm_given {
        //param_set("register_name", name);
        Reroute(register_form, "No password confirmation provided.");
    }

    if password != password_confirm {
        //param_set("register_name", name);
        Reroute(register_form, "Password and password confirmation do not match.");
    }

    new_user := insert(User.{name=name, password_hash=md5(password)});

    begin_session();
    context.reqres.session.user_id = new_user.id;
    Redirect("/", "Registered and logged in successfully. 😀");
});

//---- logout ------------------------------------------------------------------
route(.GET, "/logout", () {
    end_session();
    cookie_unset("saved_name");
    cookie_unset("saved_password");
    Redirect("/", "Logged out successfully.");
});




//== ETCETERA ======================================================================================

//---- favicon -----------------------------------------------------------------
route(.GET, "/favicon.ico", () {
    Respond(status=404); //TODO
});

//---- catch-all 404 -----------------------------------------------------------
route(.GET, "*", "*", not_found);
not_found :: () { Respond_Index("Not found", Render("404"), status=404); }

}
