#import "Basic";
#import "String";
#import "Hash_Table";
#import "File";
#import "File_Utilities";

#load "src/Template.jai";

#add_context response: *Response = null;

Response :: struct {
}

create_response :: () -> *Response {
    res := New(Response);
    return res;
}

test_response :: () {
    res := create_response();
    new_context := context;
    new_context.response = res;
    push_context new_context {
        bind("site_title", "Best Website");
        bind("page_title", "Home");
        bind("body", "Welcome to my website.");
        output("index");
    }
    
}

main :: () {
    tpl_init();

    test_response();
}
