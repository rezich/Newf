#import "Basic";
#import "String";
#import "Hash_Table";
#import "File";
#import "File_Utilities";

#load "src/Template.jai";
#load "src/Response.jai";

test_response :: () {
    res := create_response();
    new_context := context;
    new_context.response = res;
    push_context new_context {
        bind("site_title", "Best Website");
        bind("page_title", "Home");
        bind_output("body", "home");
        output("index");
        write_string("\n\n");
        write_string(context.response.body);
        write_string("\n\n");
    }
    
}

main :: () {
    set_working_directory(#filepath);
    init_template_system();
    test_response();
}
