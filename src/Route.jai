ROUTE_PATH_SEPARATORS :: "/";
Route :: struct {
    method: Request_Method;
    subdomain: string;
    proc: Proc;
    stretches: [..] Stretch;
    params: [..] string;

    Stretch :: struct { // Merriam-Webster, Entry 2, Definition 4a
        type: Type;
        text: string;

        Type :: enum {
            WILDCARD;
            PATH;
            PARAM;
        }
    }
    Proc :: #type (Payload);
    Payload :: struct {
        req: *Request;
        res: *Response;
    }
}

routes: [..] Route;
routes_match_subdomains := false;

route :: (method: Request_Method, path: string, proc: Route.Proc) { route(method, "", path, proc); }
route :: (method: Request_Method, subdomain: string, path: string, proc: Route.Proc) {
    if subdomain != "" then routes_match_subdomains = true;
    r: Route;
    r.method = method;
    r.subdomain = subdomain;
    r.proc = proc;
    parse_route_path(*r, path);

    array_add(*routes, r);

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
}

before_routes: [..] Route.Proc;
after_routes: [..] Route.Proc;

before_route :: inline (proc: Route.Proc) { array_add(*before_routes, proc); }
after_route :: inline (proc: Route.Proc) { array_add(*after_routes, proc); }
