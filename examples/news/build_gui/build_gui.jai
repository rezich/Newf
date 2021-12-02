#run {
    set_build_options_dc(.{do_output=false});
    cwd := get_working_directory();
    cwd = slice(cwd, 0, find_index_of_any_from_right(cwd, "\\/"));
    
    print("---\n%\n---\n", cwd);
    set_working_directory(cwd);
    build_gui();
    build();
}

build :: () {
    #if OS == .WINDOWS {
        script_name := "build.ps1";
        interpreter := "powershell";
        interpreter_argument := "-file %";
    }
    if !file_exists(script_name) { /*TODO: Error*/ }
    
    os_run_command(
        interpreter,
        tprint(interpreter_argument, script_name)
    );
}

build_gui :: () {
    print("This is where the GUI would be.\n");
}

#import "File_Utilities";
#import "Compiler";
#import "Process";
#import "String";
#import "Basic";
#import "File";
