OUTPUT_NAME :: "www";
OUTPUT_PATH :: "bin";
ENTRY_POINT :: "src/Main.jai";

#run,stallable {
    do_performance_report := array_find(get_build_options().compile_time_command_line, "perf");
    performance_report := (#import "Performance_Report").get_plugin();
    w := compiler_create_workspace(OUTPUT_NAME);
    if !w { print("Workspace creation failed.\n"); return; }

    options := get_build_options(w);
    options.output_executable_name = OUTPUT_NAME;
    options.output_path = OUTPUT_PATH;
    options.text_output_flags = 0;
    set_build_options(options, w);

    intercept_flags: Intercept_Flags;
    if do_performance_report then performance_report.before_intercept(performance_report, *intercept_flags);

    compiler_begin_intercept(w, intercept_flags);
    add_build_file(ENTRY_POINT, w);

    SQL.prebuild_step(w);

    while true {
        message := compiler_wait_for_message();
        if do_performance_report && message then performance_report.message(performance_report, message);
        if !message || message.kind == .COMPLETE then break;

        SQL.build_step(message);
    }

    compiler_end_intercept(w);
    set_build_options_dc(.{do_output=false, write_added_strings=false});
}

#import "Basic";
#import "String";
#import "Compiler";

SQL :: #import,dir "../../../SQLite"(FROM_METAPROGRAM=true);
