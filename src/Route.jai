Route :: struct {
    response: Response_Proc;
    params: [..] string;
}

routes: Table(string, Route);

init_router :: () {
    init(*routes);
}

add_route :: (path: string, response: Response_Proc) {
    route: Route;
    route.response = response;

    /*str := path;
    start, end: int;
    found: bool;
    path_builder: String_Builder;

    while true {
        start, found = index_of_string(str, "%{");
        if !found break;

        end, found = index_of_string(str, "}");
        if !found break;

        if end < start {
            print("ERROR PARSING ROUTE!\n");
            break;
        }

        new_param := slice(str, start + 2, end - start - 2);
    }*/

    table_add(*routes, path, route);
}

route_request :: (req: *Request) {
    found := false;
    for route, path: routes {
        if route_matches(req.path, path) {
            respond(req, route.response);
            found = true;
            break;
        }
    }
    if !found then print("Route not found!! %", req.path);
}

route_matches :: (req_path: string, route_path: string) -> bool {
    return true;
}
