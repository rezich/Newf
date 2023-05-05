BUILD : enum { DEVELOPING; DEPLOYING; } : .DEVELOPING;


Comment :: struct { using #as model: Model;
    submission:    Cached(Submission);
    parent:        Cached(Comment);
    author:        Cached(User); @autofetch
    body:          string;
    children: [..] Cached(Comment); @do_not_serialize
}


Submission :: struct { using #as model: Model;
    submitter: Cached(User); @autofetch
    headline:  string;
    body:      string;
    score:     int; @do_not_serialize
}
render_comments_for :: (submission: Cached(Submission)) -> string {
    return render_each(get_threaded_comments_for(submission),
        #code { render_it("comment", it.author.name, it.body, `render_children_of(it)); },
        "<i>There are no comments on this submission at the moment.</i>"
    );

    render_children_of :: (comment: Cached(Comment)) -> string {
        return render_each(comment.children,
            #code { render_it("comment", it.author.name, it.body, `render_children_of(it)); }
        );
    }
    // this is probably not the best way to do this
    get_threaded_comments_for :: (submission: Cached(Submission)) -> [..] Cached(Comment) {
        all_comments_for_submission := select_from(Comment, where="submission_id = ?", submission.id);
        unthreaded_comments, threaded_comments: [..] Cached(Comment);
        unthreaded_comments.allocator = temp; // bleh
        threaded_comments.allocator = temp; // bleh
        array_copy(*unthreaded_comments, all_comments_for_submission);
        for unthreaded_comments if is_null(it.parent) {
            array_add(*threaded_comments, it);
            remove it;
        }
        unthreaded_comments_count_last_time := unthreaded_comments.count;
        while unthreaded_comments.count > 0 {
            for unthreaded, unthreaded_index: unthreaded_comments
            for   threaded,   threaded_index:   threaded_comments
            if  unthreaded.parent       ==      threaded {
                threaded.pointer.children.allocator = temp;
                array_add(*threaded.children, unthreaded);
                array_add(*threaded_comments, unthreaded);
                remove unthreaded;
            }
            assert(unthreaded_comments.count != unthreaded_comments_count_last_time, "this should never happen");
            unthreaded_comments_count_last_time = unthreaded_comments.count;
        }
        for threaded_comments if !is_null(it.parent) then remove it;
        return threaded_comments;
    }
}


User :: struct { using #as model: Model;
    name:          string;
    password_hash: string;
}


Vote :: struct { using #as model: Model;
    user:       Cached(User);
    sumission: Cached(Submission);
}


get_current_year :: () => to_calendar(current_time_consensus()).year;
is_logged_in     :: () -> bool { _, logged_in := session_get_int("user_id"); return logged_in; }


The_Algo :: (page: int = 1) -> [..] Cached(Submission) { //TODO
    return select_from(Submission, order_by=.{"created", .DESC});
}


//TODO: get rid of this!
Get_Logged_In_User :: () -> Cached(User) {
    id := session_get_int("user_id");
    if id == -1 then return .{};
    return select_by_id(User, id);
}


main :: () {
    DATABASE_FILENAME :: "database.db";
    context.sqlite.filename = DATABASE_FILENAME;

    set_working_directory((#import "String").path_strip_filename((#import "System").get_path_of_running_executable()));
    #if BUILD == .DEVELOPING then (#import "File").file_delete(DATABASE_FILENAME); // delete the databse every run for now

    init_model_cache();
    #if BUILD == .DEVELOPING {
        #load "Mock_Database.jai";
        mock_database();
    }

    #load "Routes.jai";
    set_routes();

    open_for(listen(8000, after=#code { reset_model_cache(); }), "main");


    #if BUILD == .DEVELOPING {
        SQLite.optional_cleanup();
          Newf.optional_cleanup();
    }
}


DEBUG_MEMORY, VERBOSE :: BUILD == .DEVELOPING;


#import "Basic"()(MEMORY_DEBUGGER=DEBUG_MEMORY);
#import "md5";


using Newf   :: #import,dir "../../../../Newf"  (VERBOSE=VERBOSE);
using SQLite :: #import,dir "../../../../SQLite"(VERBOSE=VERBOSE, USE_MODEL_CACHE=true);


#add_context sqlite_model_cache: SQLite_Model_Cache;
