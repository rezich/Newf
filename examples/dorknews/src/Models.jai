//---- Comment -------------------------------------------------------------------------------------
Comment :: struct { using #as model: Model;
    submission:    Cached(Submission);
    parent:        Cached(Comment);
    author:        Cached(User); @autofetch
    body:          string;
    //comments: [..] Cached(Comment); @do_not_serialize
}

Comment_With_Threaded_Comments :: struct {
    using comment: Cached(Comment);
    threaded_comments: [..] Comment_With_Threaded_Comments;
}




//---- Submission ----------------------------------------------------------------------------------
Submission :: struct { using #as model: Model;
    submitter: Cached(User); @autofetch
    headline:  string;
    body:      string;
    score:     int; @do_not_serialize
}

Submission_With_Threaded_Comments :: struct {
    using submission: Cached(Submission);
    threaded_comments: [..] Comment_With_Threaded_Comments;
}
Render_With_Threaded_Comments :: (submission: Cached(Submission)) -> string {
    return Render("submission", Submission_With_Threaded_Comments.{
        submission=submission,
        threaded_comments=Get_Threaded_Comments_For(submission)
    });

    // this is probably not the best way to do this
    Get_Threaded_Comments_For :: (submission: Cached(Submission)) -> [..] Comment_With_Threaded_Comments {
        all_comments_for_submission := select_from(Comment, where="submission_id = ?", submission.id);
        for all_comments_for_submission log("%", it);
        unthreaded_comments: [..] Cached(Comment);
        unthreaded_comments.allocator = temp; // bleh
          threaded_comments: [..] Comment_With_Threaded_Comments;
          threaded_comments.allocator = temp; // bleh
        array_copy(*unthreaded_comments, all_comments_for_submission);
        for unthreaded_comments if is_null(it.parent) {
            array_add(*threaded_comments, .{comment=it});
            remove it;
        }
        unthreaded_comments_count_last_time := unthreaded_comments.count;
        while the_loop := unthreaded_comments.count > 0 {
            defer unthreaded_comments_count_last_time = unthreaded_comments.count;
            defer assert(unthreaded_comments.count != unthreaded_comments_count_last_time, "this should never happen: %", unthreaded_comments.count);
            for unthreaded, unthreaded_index: unthreaded_comments
            for * threaded,   threaded_index:   threaded_comments {
                if unthreaded.parent == threaded.comment {
                    newly_threaded := Comment_With_Threaded_Comments.{comment=unthreaded};
                    newly_threaded.threaded_comments.allocator = temp;
                    array_add(*threaded.threaded_comments, newly_threaded);
                    array_add(         *threaded_comments, newly_threaded); // temporary, until the end
                    remove unthreaded;
                    continue the_loop;
                }
            }
        }
        for threaded_comments if !is_null(it.comment.parent) then remove it;
        return threaded_comments;
    }
}




//---- User ----------------------------------------------------------------------------------------
User :: struct { using #as model: Model;
    name:          string;
    password_hash: string;
}




//---- Vote ----------------------------------------------------------------------------------------
Vote :: struct { using #as model: Model;
    user:      Cached(User);
    sumission: Cached(Submission);
}
