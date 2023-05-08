BUILD : enum { DEVELOPING; DEPLOYING; } : .DEVELOPING;


#load "Models.jai";
#load "State.jai";


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
        memory_visualizer_per_frame_update();
        report_memory_leaks();
    }
}


DEBUG_MEMORY, VERBOSE :: BUILD == .DEVELOPING;


#import "Basic"()(MEMORY_DEBUGGER=DEBUG_MEMORY);
#import "md5";


using Newf   :: #import,dir "../../../../Newf"  (VERBOSE=VERBOSE);
using SQLite :: #import,dir "../../../../SQLite"(VERBOSE=VERBOSE, USE_MODEL_CACHE=true);


#add_context sqlite_model_cache: SQLite_Model_Cache;
