#load "Cookie.jai";
#load "Header.jai";
#load "Request.jai";
#load "Request_Resolution.jai";
#load "Response.jai";
#load "Route.jai";
#load "Server.jai";
#load "Session.jai";
#load "Template.jai";
#load "Toast.jai";
#load "Util.jai";

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

_md5 :: #import "md5";
md5 :: (input: string) -> string #must {
    new_context := context;
    new_context.allocator = temp;
    output: string;
    push_context new_context { output = _md5.md5(input); }
    return output;
}
