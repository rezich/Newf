OUTPUT_NAME :: "www";
OUTPUT_PATH :: "bin";
ENTRY_POINT :: "src/Main.jai";

#run {
    w := compiler_create_workspace(OUTPUT_NAME);
    if !w { print("Workspace creation failed.\n"); return; }

    options := get_build_options(w);
    options.output_executable_name = OUTPUT_NAME;
    options.output_path = OUTPUT_PATH;
    options.text_output_flags = 0;
    set_build_options(options, w);

    compiler_begin_intercept(w);
    add_build_file(ENTRY_POINT, w);

     SQL.prebuild_step(w);
    Newf.prebuild_step(w);

    while true {
        message := compiler_wait_for_message();
        if !message || message.kind == .COMPLETE then break;
    
        SQL.build_step(message);
    
        if message.kind == .FAILED_IMPORT {
            m := cast(*Message_Failed_Import) message;
            if m.target_module_name == "Newf" || m.target_module_name == "SQLite"
                provide_import(message.workspace, m, .PATH_TO_DIRECTORY, join(#filepath, "../../../", m.target_module_name));
            continue;
        }
    }

    compiler_end_intercept(w);
    set_build_options_dc(.{do_output=false, write_added_strings=false});
}

#import "Basic";
#import "String";
#import "Compiler";

Newf :: #import,dir "../../../Newf"  (FROM_METAPROGRAM=true);
SQL  :: #import,dir "../../../SQLite"(FROM_METAPROGRAM=true);
