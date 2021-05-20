/*Route :: struct {
    params: [..] string;
    response: Response_Proc;
}*/

routes: Table(string, Response_Proc);

init_router :: () {
    init(*routes);
}

add_route :: (path: string, response: Response_Proc) {
    table_add(*routes, path, response);
}

route_request :: (req: *Request) {
    found := false;
    for proc, path: routes {
        if route_matches(req.path, path) {
            respond(req, proc);
            found = true;
            break;
        }
    }
    if !found then print("Route not found!! %", req.path);
}

route_matches :: (req_path: string, route_path: string) -> bool {
    return true;
}
