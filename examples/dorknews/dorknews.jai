OUTPUT_NAME :: "www";
OUTPUT_PATH :: "bin";
ENTRY_POINT :: "src/Main.jai";
DIRECTORIES :: string.["src", "static", "templates"];

SQLite :: #import,dir "../../../SQLite"(FROM_METAPROGRAM=true);

watcher: File_Watcher(void);
process: Process;

compile :: () -> bool {
    do_performance_report := array_find(get_build_options().compile_time_command_line, "perf");
    performance_report := (#import "Performance_Report").get_plugin();
    w := compiler_create_workspace(OUTPUT_NAME);
    if !w { print("Workspace creation failed.\n"); return false; }

    options := get_build_options(w);
    options.output_executable_name = OUTPUT_NAME;
    options.output_path = OUTPUT_PATH;
    options.text_output_flags = 0;
    set_build_options(options, w);

    intercept_flags: Intercept_Flags;
    if do_performance_report then performance_report.before_intercept(performance_report, *intercept_flags);

    compiler_begin_intercept(w, intercept_flags);
    add_build_file(ENTRY_POINT, w);

    SQLite.prebuild_step(w);
    defer SQLite.reset_build();

    errored := false;
    while true {
        message := compiler_wait_for_message();
        if do_performance_report && message then performance_report.message(performance_report, message);
        if !message || message.kind == .COMPLETE then break;
        if message.kind == .ERROR then errored = true;

        SQLite.build_step(message);
    }

    compiler_end_intercept(w);
    set_build_options_dc(.{do_output=false, write_added_strings=false});
    compiler_destroy_workspace(w);
    return !errored;
}

run :: () {
    if !create_process(*process, tprint("%1%2%3", OUTPUT_PATH, ifx OUTPUT_PATH then "/", OUTPUT_NAME)) then log_error("Could not launch child process.");
}

#run,stallable {
    if array_find(get_build_options().compile_time_command_line, "dev") {
        if compile() then run();
        init(
            *watcher,
            (watcher: *File_Watcher(void), change: *File_Change, user_data: *void) {
                if !kill_process(*process) then log_error("Failed to kill process.");
                if compile() then run();
            },
            null,
            events_to_watch=.ALL_EVENTS
        );
        add_directories(*watcher, ..DIRECTORIES);
        while true {
            changed, needs_wait, wait_seconds := process_changes(*watcher);
            reset_temporary_storage();
            sleep_milliseconds(100);
        }
    }
    else compile();
}

#import "Basic";
#import "String";
#import "Compiler";
#import "File_Watcher";
#import "Process";
