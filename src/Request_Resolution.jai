Request_Resolution :: struct {
    client:             Client;
    state:              STATE_TYPE;
    session:           *SESSION_TYPE;
    session_container: *Session_Container;
    req:                Request;
    res:                Response;
    buffer:             Buffer;
    //cache_settings:     Route.Cache_Settings;
}

#add_context reqres: *Request_Resolution;

Client :: struct {
    socket: Socket;
}
