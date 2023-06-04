#module_parameters(
    VERBOSE := false,
    HOSTNAME := "localhost",
    STATE_TYPE := void,
    SESSION_TYPE := void,
    MAX_NESTED_DELEGATED_TEMPLATE_DEPTH := 8,
    SESSIONS_PER_BUCKET := 1000,
    SESSION_TOKEN := "_SESSION_TOKEN",
    UNSEEN_TOASTS_TOKEN := "_UNSEEN_TOASTS",
    UNSEEN_TOASTS_SEPARATOR := "\n\n",
    TOAST_TEMPLATE_NAME := "toast" //TODO: remove this when Toasts become a plugin or whatever
);

#load "src/Cookie.jai";
#load "src/Header.jai";
#load "src/Request.jai";
#load "src/Request_Resolution.jai";
#load "src/Response.jai";
#load "src/Route.jai";
#load "src/Server.jai";
#load "src/Session.jai";
#load "src/Template.jai";
#load "src/Toast.jai";
#load "src/Util.jai";

optional_cleanup :: () {
    reset_temporary_storage();
    free_routes();
    free_sessions();
}

#import "Basic";
#import "Hash_Table";
#import "Bucket_Array";
#import "String";
#import "File";
#import "File_Utilities";
#import "md5";

// TODO: get rid of this lmao
#scope_module
_md5 :: #import "md5";
md5 :: (input: string) -> string #must {
    new_context := context;
    new_context.allocator = temp;
    output: string;
    push_context new_context { output = _md5.md5(input); }
    return output;
}

