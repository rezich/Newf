Comment :: struct { using #as model: Model;
    submission:   Cached(Submission);
    parent:       Cached(Comment);
    author:       Cached(User);       @autofetch
    body:         string;
    replies: [..] Cached(Comment);               @do_not_serialize
}

//==================================================================================================

Submission :: struct { using #as model: Model;
    submitter:     Cached(User);      @autofetch
    headline:      string;
    body:          string;
    score:         int;                          @do_not_serialize
    comments: [..] Cached(Comment);              @do_not_serialize
    comments_count: int;              @autofetch @do_not_serialize

    // models with members that are @autofetch AND @do_not_serialize need to have a procedure
    // defined IN THE STRUCT named fetch_ + the name of the member, which takes a *Cached(T)
    fetch_comments_count :: (using submission: *Cached(Submission)) {
        result: SQLite.Result; success: bool;
        result, comments_count, success = exec_value(int, "SELECT COUNT(*) FROM Comment WHERE submission_id = ?", id);
        assert(result == .OK && success);
    }
}

// this is NOT autofetched, because we don't always want to fetch all comments (and do the work of
// threading them) every time we retrieve a Submission (i.e. on the landing page)!
fetch_comments :: (submission: *Cached(Submission)) {
    unthreaded_comments := select_from(Comment, where="submission_id = ?", submission.id);
    for unthreaded_comments if is_null(it.parent) {
        array_add(*submission.comments, it);
        remove it;
    }
    unthreaded_comments_count_last_time := unthreaded_comments.count;
    while the_loop := unthreaded_comments.count > 0 {
        defer unthreaded_comments_count_last_time = unthreaded_comments.count;
        #if BUILD == .DEVELOPING then defer assert(
            unthreaded_comments.count != unthreaded_comments_count_last_time,
            "infinite loop encountered while threading comments; could not thread % comments",
            unthreaded_comments.count
        );
        for unthreaded, unthreaded_index: unthreaded_comments
        for * threaded,   threaded_index: submission.comments {
            if unthreaded.parent == threaded {
                array_add(*threaded.replies,    unthreaded);
                array_add(*submission.comments, unthreaded); // temporary, until the end
                remove unthreaded;
                continue the_loop;
            }
        }
    }
    for submission.comments if !is_null(it.parent) then remove it;
}

//==================================================================================================

User :: struct { using #as model: Model;
    name:             string;
    password_hash:    string;
    karma:            int;                @do_not_serialize
    submissions:   [] Cached(Submission); @do_not_serialize
    comments:      [] Cached(Comment);    @do_not_serialize
}

//==================================================================================================

Vote :: struct { using #as model: Model;
    user:      Cached(User);
    sumission: Cached(Submission);
}
