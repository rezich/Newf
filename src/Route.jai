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
    // TODO: route path preprocessing?
    table_add(*routes, path, route);
}

route_request :: (req: *Request) {
    found := false;
    for route, path: routes {
        if route_matches(req, path) {
            respond(req, route.response);
            found = true;
            break;
        }
    }
    if !found then print("Route not found!! %", req.path);
}

route_matches :: (req: *Request, route_path: string) -> bool {
    // TODO: extract parameters from request path & put into req.params
    return re_match(route_path, req.path);
}
