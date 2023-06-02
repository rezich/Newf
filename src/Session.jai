Session_Container :: struct {
    session:     SESSION_TYPE;
    token:       Token;
    toasts: [..] Toast;

    Token :: #type string;
}

sessions: Table(Session_Container.Token, Session_Container);

begin_session :: () {
    using context.reqres;
    new_context := context;
    new_context.allocator = context.default_allocator;
    push_context new_context {
        if !session {
            new_session_container: Session_Container;
            token := md5(tprint("%", get_time())); //TODO: lol
            added := table_add(*sessions, new_session_container.token, new_session_container);
            added.token = copy_string(token);
            session = *added.session;
            session_container = added;
            cookie_set(SESSION_TOKEN, new_session_container.token);
            move_toasts_from_res_to_session();
        }
    }
}

load_or_reset_session :: (token: Session_Container.Token) {
    using context.reqres;
    found_session := table_find_pointer(*sessions, token);
    if found_session {
        session = *found_session.session;
        session_container = found_session;
        cookie_set(SESSION_TOKEN, token);
        move_toasts_from_res_to_session();
    }
    else cookie_unset(SESSION_TOKEN);
}

move_toasts_from_res_to_session :: () {
    if context.reqres.res.toasts.count == 0 then return;
    for context.reqres.res.toasts array_add(*context.reqres.session_container.toasts, it);
    array_reset(*context.reqres.res.toasts);
}

end_session :: () {
    using context.reqres;
    cookie_unset(SESSION_TOKEN);
    if !session then return;
    table_remove(*sessions, session_container.token);
    session = null;
    session_container = null;
}

free_sessions :: () {
    for * sessions {
        free(it.token);
        array_free(it.toasts);
    }
    deinit(*sessions);
}
