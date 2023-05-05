mock_database :: () { open_for(#code {

    admin := insert(User.{
        name="admin",
        password_hash=#run md5("hunter2")
    });


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
