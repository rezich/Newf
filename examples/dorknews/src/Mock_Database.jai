mock_database :: () { open_for(#code {

    admin := insert(User.{
        name="admin",
        password_hash=#run md5("hunter2")
    });


    for string.[
        "Ask DN: How do you hate on pointless iPhone apps?",
        "Running Tails on a Raspberry Pi Maximum",
        "Introducing MetalBloat: a WebGL library add-on",
        "A fully functional POSIX-compliant 64-bit multitasking operating system in 14 lines of Ruby",
        "Ask DN: Has anyone else lost their laptop in the house?",
        "Show DN: I made a new stand-alone SaaS, or two, blockchain backed open-source platform",
        "Introducing BushMagic: a Haskell library optimizer",
        "An ex-Microsoft engineer has built the world's smallest USB hub",
        "An Ebay clone in 10 lines of Python"
    ] insert(Submission.{
        submitter=admin,
        headline=it,
        body="Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
    });

    for submission: select_from(Submission) {
        Data :: struct { body: string; is_child := false; }

        parent: Cached(Comment);

        for Data.[
            .{ body="first"                 },
            .{ body="second", is_child=true },
            .{ body="third",  is_child=true },
            .{ body="fourth"                } 
        ] parent = insert(Comment.{
            submission=submission,
            parent=ifx it.is_child then parent,
            author=admin,
            body=it.body
        });
    }

    reset_model_cache();
    reset_temporary_storage();

}, "mock database setup"); }
