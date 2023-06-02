BUILD : enum { DEVELOPING; DEPLOYING; } : .DEVELOPING;
OVERRIDE_DEPLOYING_PORT :: false;


#load "Models.jai";
#load "Routes.jai";
#load "Session_and_State.jai";


The_Algo :: (page: int = 1) -> [..] Cached(Submission) { //TODO
    return select_from(Submission, order_by=.{"created", .DESC});
}

is_logged_in :: () -> bool {
    using context.reqres;
    if !session then return false;
    return session.user_id != 0;
}


main :: () {
    context.sqlite.filename = "database.db";

    set_working_directory((#import "String").path_strip_filename((#import "System").get_path_of_running_executable()));
    #if BUILD == .DEVELOPING then (#import "File").file_delete(context.sqlite.filename); // delete the databse every run for now

    init_model_cache();
    #if BUILD == .DEVELOPING { #load "Mock_Database.jai"; mock_database(); }

    set_routes();

    PORT :: #ifx BUILD == .DEPLOYING && !OVERRIDE_DEPLOYING_PORT then 80; else 8000;
    open_for(listen(
        port=PORT,
        after=#code { reset_model_cache(); }),
    "main");

    #if BUILD == .DEVELOPING {
        SQLite.optional_cleanup();
          Newf.optional_cleanup();
        memory_visualizer_per_frame_update();
        report_memory_leaks();
    }
}


DEBUG_MEMORY, VERBOSE :: BUILD == .DEVELOPING;


#import "Basic"()(MEMORY_DEBUGGER=DEBUG_MEMORY);
#import "md5";

using Newf   :: #import,dir "../../../../Newf"  (VERBOSE=VERBOSE, STATE_TYPE=State, SESSION_TYPE=Session);
using SQLite :: #import,dir "../../../../SQLite"(VERBOSE=VERBOSE, USE_MODEL_CACHE=true);


#add_context sqlite_model_cache: SQLite_Model_Cache;
