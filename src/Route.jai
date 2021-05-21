/*
route syntax:

parameters:
    $string
    :int

examples:
    /
    /home
    /about/history
    /posts/:id
    /users/$username

notes:
    must begin with slash (except for the path "*")
    must not end with a slash (except for the path "/")
*/


Route :: struct {
    response: Response_Proc;
    params: [..] string;
    pieces: [..] Route_Piece;
}

Route_Piece_Type :: enum {
    WILDCARD;
    PATH;
    PARAM_INT;
    PARAM_STRING;
}

Route_Piece :: struct {
    type: Route_Piece_Type;
    text: string;
}

routes: [..] Route;

add_route :: (path: string, response: Response_Proc) {
    route: Route;
    route.response = response;
    parse_route_path(*route, path);
    array_add(*routes, route);
}

route_request :: (req: *Request) {
    found := false;
    for * route: routes {
        if route_matches(req, route) {
            respond(req, route.response);
            found = true;
            break;
        }
    }
    if !found then print("Route not found!! %", req.path);
    deinit(req);
}

parse_route_path :: (route: *Route, path: string) {
    if path == "*" {
        piece: Route_Piece;
        piece.type = .WILDCARD;
        array_add(*route.pieces, piece);
        return;
    }
    if !begins_with(path, "/") {
        print("Path must begin with a forward slash!!");
        return;
    }
    else if ends_with(path, "/") && path.count > 1 {
        print("Path must not end with a forward slash!!");
        return;
    }

    str := path;
    end, next_param_start, next_param_end: int;
    found: bool;

    while compare(str, "") != 0 {
        next_param_start, found = index_of_any_char(str, ":$");
        if next_param_start == 0 {
            next_param_end, found = index_of_char(str, #char "/");
            end = ifx found then next_param_end else str.count;
            new_param := slice(str, 1, end - 1);
            piece: Route_Piece;
            if begins_with(str, ":") then piece.type = Route_Piece_Type.PARAM_INT;
            else piece.type = Route_Piece_Type.PARAM_STRING;
            array_add(*route.pieces, piece);
            array_add(*route.params, new_param);
            str = slice(str, end, str.count);
        }
        else {
            end = ifx found then next_param_start else str.count;
            piece: Route_Piece;
            piece.type = .PATH;
            piece.text = slice(str, 0, end);
            array_add(*route.pieces, piece);
            str = slice(str, end, str.count);
        }
    }
}

route_matches :: (req: *Request, route: *Route) -> bool {
    str := req.path;
    n := 0;
    current_param := 0;
    end_of_param: int;
    found: bool;

    params: Param_Container;
    init(*params);

    while compare(str, "") != 0 && n < route.pieces.count {
        piece := *route.pieces[n];

        if piece.type == {
            case .WILDCARD;
                str = ""; // hack?
            case .PATH;
                if !begins_with(str, piece.text) then return false;
                str = slice(str, piece.text.count, str.count);
            case .PARAM_INT;
                end_of_param, found = index_of_char(str, #char "/");
                if !found then end_of_param = str.count;
                if end_of_param == 0 then break;
                add_int(*params, route.params[current_param], string_to_int(slice(str, 0, end_of_param)));
                str = slice(str, end_of_param, str.count);
                current_param += 1;
            case .PARAM_STRING;
                end_of_param, found = index_of_char(str, #char "/");
                if !found then end_of_param = str.count;
                if end_of_param == 0 then break;
                add_string(*params, route.params[current_param], slice(str, 0, end_of_param));
                str = slice(str, end_of_param, str.count);
                current_param += 1;
        }
        n += 1;
    }

    success := compare(str, "") == 0 && n == route.pieces.count;
    if success {
        copy(*params, *req.params);
    }

    deinit(*params);

    return success;
}
