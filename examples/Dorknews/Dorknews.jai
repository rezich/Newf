USER_MODULES_PATH :: "../../../";
ENTRY_POINT :: "Meta.jai";

#run {
    w := compiler_create_workspace("Target Program");
    if !w { print("Workspace creation failed.\n"); return; }

    options := get_build_options(w);
    new_path: [..] string;
    array_add(*new_path, ..options.import_path);
    array_add(*new_path, USER_MODULES_PATH);
    options.import_path = new_path;
    options.text_output_flags = 0;
    set_build_options(options, w);

    compiler_begin_intercept(w);
    add_build_file(ENTRY_POINT, w);

    while true {
        message := compiler_wait_for_message();
        if !message || message.kind == .COMPLETE then break;
    }

    compiler_end_intercept(w);
    set_build_options_dc(.{do_output=false, write_added_strings=false});
}

#import "Basic";
#import "Compiler";
