Session :: struct {
    token: TOKEN;
    locator: Bucket_Locator;
    ended: bool;
    params: Table(string, string);

    TOKEN :: string;
}

sessions: Table(Session.TOKEN, *Session);
session_storage: Bucket_Array(Session, SESSIONS_PER_BUCKET, true);

begin_session :: () {
    if !context.response.session {
        session: Session;
        session.token = md5(tprint("%", get_time())); //TODO: lol
        session.locator = bucket_array_add(*session_storage, session);
        context.response.session = bucket_array_find_pointer(*session_storage, session.locator);
        table_add(*sessions, session.token, context.response.session);
        set_cookie(SESSION_TOKEN, session.token);
    }
}
load_or_begin_session :: (token: Session.TOKEN) {
    existing, found := table_find(sessions, token);
    if found && existing {
        context.response.session = existing;
        set_cookie(SESSION_TOKEN, existing.token);
    }
    else begin_session();
}
end_session :: () {
    if context.response.session == null return;
    table_remove(*sessions, context.response.session.token);
    bucket_array_remove(*session_storage, context.response.session.locator);
    context.response.session = null;
    unset_cookie(SESSION_TOKEN);
}
