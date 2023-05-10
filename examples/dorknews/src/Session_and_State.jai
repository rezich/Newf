// user-defined persistent server-side data for user sessions
Session :: struct {
    user_id: s64;
}

// user-defined transient server-side data for a single request resolution
State :: struct {
    current_user: Cached(User);
}

// these two structs might be combined in the future
