Route :: struct {
    method: Request.Method;
    subdomain: string;
    path: string;
    proc: Proc;
    stretches: [..] Stretch;
    params: [..] string;

    //cache_settings: Cache_Settings;
    //last_cached: Apollo_Time = APOLLO_TIME_INVALID;

    Stretch :: struct { // Merriam-Webster, Entry 2, Definition 4a
        type: Type;
        text: string;

        Type :: enum {
            WILDCARD;
            PATH;
            PARAM;
        }
    }
    Proc :: #type ();
    //Cache_Settings :: struct { seconds: int; }

    PATH_SEPARATORS :: "/";
}

routes: [..] Route;
routes_match_subdomains := false;

/*get_cached_rendering_filename_for_route :: (route: Route) -> string {
    // ignoring subdomain for now
    return tprint("%1%2%3%4%5",
    /* 1 */ get_working_directory(),
    /* 2 */ "/cached",
    /* 3 */ route.path,
    /* 4 */ ifx ends_with(route.path, "/") then "_",
    /* 5 */ ".txt"
    );
}*/

free_routes :: () {
    for routes {
        array_free(it.stretches);
        array_free(it.params);
    }
    array_free(routes);
    array_free(before_routes);
    array_free(after_routes);
}

route :: inline (
    method: Request.Method,
    path: string,
    proc: Route.Proc/*,
    cache: Route.Cache_Settings = .{}*/
) { route(method=method, subdomain="", path=path, proc=proc/*, cache=cache*/); }

route :: (
    method: Request.Method,
    subdomain: string,
    path: string,
    proc: Route.Proc/*,
    cache: Route.Cache_Settings = .{}*/
) {
    if subdomain != "" then routes_match_subdomains = true;
    r: Route;
    r.method = method;
    r.subdomain = subdomain;
    r.path = path;
    r.proc = proc;
    //r.cache_settings = cache;

    parse_route_path :: (r: *Route, path: string) {
        if path == "*" {
            s: Route.Stretch;
            s.type = .WILDCARD;
            array_add(*r.stretches, s);
            return;
        }
        if !begins_with(path, "/") {
            print("Route error, path must begin with a forward slash\n");
            return;
        }
        if ends_with(path, "/") && path.count > 1 {
            print("Route error, path must not end with forward slash\n");
            return;
        }

        str := path;
        end, next_param_start, next_param_end: int;
        found: bool;

        while str != "" {
            next_param_start := find_index_of_any_from_left(str, ":$");
            if next_param_start == 0 {
                next_param_end := find_index_from_left(str, #char "/");
                end = ifx next_param_end != -1 then next_param_end else str.count;
                new_param := slice(str, 1, end - 1);
                s: Route.Stretch;
                if !begins_with(str, ":") && !begins_with(str, "$") {
                    print("Route error, invalid param specifier\n");
                    return;
                }
                s.type = Route.Stretch.Type.PARAM;
                array_add(*r.stretches, s);
                array_add(*r.params, new_param);
                str = slice(str, end, str.count);
            }
            else {
                end = ifx next_param_start != -1 then next_param_start else str.count;
                s: Route.Stretch;
                s.type = .PATH;
                s.text = slice(str, 0, end);
                array_add(*r.stretches, s);
                str = slice(str, end, str.count);
            }
        }
    }
    
    parse_route_path(*r, path);
    array_add(*routes, r);
}

before_routes: [..] Route.Proc;
after_routes:  [..] Route.Proc;

before_route :: inline (proc: Route.Proc) { array_add(*before_routes, proc); }
after_route  :: inline (proc: Route.Proc) { array_add(*after_routes,  proc); }

Redirect :: (to: string, toast_message := "") #expand {
    using context.reqres;
    if toast_message then toast(toast_message);
    res.status = 302;
    store_unseen_toasts_in_cookie();
    header_set("Location", to);
    `return;
}

Reroute :: (to: Route.Proc, toast_message := "") #expand {
    if toast_message then toast(toast_message);
    to(); `return;
}

route_static_files :: ($directory := "static") {
    load_static_file :: (filename: string) -> [] u8 {
        file_data, success := read_entire_file(filename);
        if !success then compiler_report(tprint("Unable to read file '%'!\n", filename));
        return xx file_data;
    }

    #insert -> string {
        builder: String_Builder;

        path := tprint("%1/%2", get_working_directory(), directory);
        path_overwrite_separators(path, #char "/");
        visit_files(path, recursive=true, *builder, (info: *File_Visit_Info, builder: *String_Builder) {
            path := tprint("%1/%2", get_working_directory(), directory);
            path_overwrite_separators(path, #char "/");
            relative_filename := info.full_name;
            path_overwrite_separators(relative_filename, #char "/");
            relative_filename.data  += path.count;
            relative_filename.count -= path.count;
            _, _, extension, _ := path_decomp(relative_filename);
            
            print_to_builder(builder, #string END
    route(.GET, "%1", () {
        data :: #run add_global_data(load_static_file("%2"), .READ_ONLY);
        Respond(data, "%3");
    });
END,        /* 1 */ relative_filename,
            /* 2 */ info.full_name,
            /* 3 */ extension
            );
        });

        return builder_to_string(*builder);
    }
}

#scope_file
#import "Compiler";
