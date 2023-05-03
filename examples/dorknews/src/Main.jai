Comment :: struct { using #as model: Model;
    submission: Cached(Submission);
    parent:     Cached(Comment);
    author:     Cached(User);
    body:       string;
}

Submission :: struct { using #as model: Model;
    submitter: Cached(User);
    headline:  string;
    body:      string;
}

User :: struct { using #as model: Model;
    name:          string;
    password_hash: string;
}

Vote :: struct { using #as model: Model;
    user:       Cached(User);
    submission: Cached(Submission);
}

get_current_year :: () => to_calendar(current_time_consensus()).year;


main :: () {
    DATABASE_FILENAME :: "database.db";
    context.sqlite.filename = DATABASE_FILENAME;
    set_working_directory((#import "String").path_strip_filename((#import "System").get_path_of_running_executable()));
    (#import "File").file_delete(DATABASE_FILENAME); // delete the databse every run for now
    init_ORM();

    open_for(#code {
        user := insert(User.{name="admin", password_hash=#run md5("hunter2")});
        for string.[
            "Ask DN: How do you hate on pointless iPhone apps?",
            "Review my startup: www.copymoldyfridgeleftovers.org",
            "Introducing MetalBloat: a WebGL library add-on",
            "A fully functional POSIX-compliant 64-bit multitasking operating system in 14 lines of Ruby",
            "How I turned coding Vanilla Ice Tour '91 merchandise into a $14 million a year business",
            "Ask DN: Am I crazy to try to market panda breeding technology?",
            "Introducing BushMagic: a Haskell library optimizer",
            "How I turned hating on Megan Fox pictures into a $10 million a year business",
            "An Ebay clone in 10 lines of Python"
        ] insert(Submission.{submitter=user, headline=it, body="Lorem ipsum"});
    }, "mock database setup");


    using Newf;


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
                toast("Something happened—please log in again.");
                param_set("nav_user", render("nav_user/default"));
                Reroute(login_form);
                //TODO: make sure this works
            };
            param_set("current_user_id", user.id);
            param_set("current_user_name", user.name);
            param_set("nav_user", render("nav_user/logged_in"));
        }
        else param_set("nav_user", render("nav_user/default"));
    });


    /*after_route(() {
        flush_cache();
    });*/


    // landing page
    route(.GET, "/", () {
        submissions := select_from(Submission);
        param_set("submissions", render_each(submissions,
            #code { render_it("submission/header", it.id, it.headline); },
            "<em>There are no submissions to display at the moment.</em>"
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
                render("submission/header", submission.id, submission.headline),
                render("submission/body", submission.body)
        ));
    });


    // new submission form
    route(.GET, "/submit", new_submission_form);
    new_submission_form :: () {
        _, logged_in := session_get_int("user_id");
        if !logged_in {
            toast("You must be logged in to submit a story.");
            Redirect("/login");
        }
        Respond_Index("Submit story", render("submit"));
    }


    // submission submission
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

        submission := insert(new_submission);

        toast("Submission was submitted successfully.");
        Redirect("/submission/%", submission.id);
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
            "<em>This user has not submitted anything.</em>"
        ));
        param_set("user_comments", render_each(void.[],
            #code,null, //TODO
            "<em>This user has not written any comments.</em>"
        ));

        Respond_Index(tprint("user %", user.name), render("user"));
    });


    // login form
    route(.GET, "/login", login_form);
    login_form :: () { Respond_Index("Log in", render("login")); }


    // login process
    route(.POST, "/login", () {
        name, name_given := param_get("name");
        if !name_given {
            toast("No user name provided");
            Reroute(login_form);
        }

        user := select_from(User, where="name = ?", name, limit=1) ? #code {
            toast("User does not exist");
            Reroute(login_form);
        };

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


    // register form
    route(.GET, "/register", register_form);
    register_form :: () { Respond_Index("Register account", render("register")); }


    // register process
    route(.POST, "/register", () {
        name, name_given := param_get("name");
        if !name_given {
            toast("No user name provided.");
            Reroute(register_form);
        }

        user := select_from(User, where="name = ?", name, limit=1) ? #code {
            toast("User name is already taken.");
            Reroute(register_form);
        };

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

        new_user := insert(User.{name=name, password_hash=md5(password)});

        session_set("user_id", new_user.id);
        toast("Registered and logged in successfully. 😀");
        Redirect("/");
    });


    // logout
    route(.GET, "/logout", () {
        end_session();
        cookie_unset("saved_name");
        cookie_unset("saved_password");
        toast("Logged out successfully.");
        Redirect("/");
    });


    // favicon
    route(.GET, "/favicon.ico", () {
        Respond(status=404);
    });


    // catch-all 404
    route(.GET, "*", "*", not_found);
    not_found :: () { Respond_Index("Not found", render("404"), status=404); }


    open_for(listen(8000), "main");
}


#import "Basic";
#import "md5";

Newf :: #import,dir "../../../../Newf"  (              VERBOSE=true);
        #import,dir "../../../../SQLite"(USE_ORM=true, VERBOSE=true);

#add_context db_cache: Database_Cache;