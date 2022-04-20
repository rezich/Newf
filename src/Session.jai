Session :: struct {
    token: TOKEN;
    locator: Bucket_Locator;
    ended: bool;
    params: Table(string, string);

    TOKEN :: string;
}

sessions: Table(Session.TOKEN, *Session);
session_storage: Bucket_Array(Session, SESSIONS_PER_BUCKET, true);

begin_session :: (res: *Response) {
    if !res.session {
        session: Session;
        session.token = md5(tprint("%", get_time())); //TODO: lol
        session.locator = bucket_array_add(*session_storage, session);
        res.session = bucket_array_find_pointer(*session_storage, session.locator);
        table_add(*sessions, session.token, res.session);
        set_cookie(res, SESSION_TOKEN, session.token);
    }
}
load_or_begin_session :: (res: *Response, token: Session.TOKEN) {
    existing, found := table_find(sessions, token);
    if found && existing {
        res.session = existing;
        set_cookie(res, SESSION_TOKEN, existing.token);
    }
    else begin_session(res);
}
end_session :: (res: *Response) {
    if res.session == null return;
    table_remove(*sessions, res.session.token);
    bucket_array_remove(*session_storage, res.session.locator);
    res.session = null;
    unset_cookie(res, SESSION_TOKEN);
}
