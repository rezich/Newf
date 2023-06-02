Toast :: struct { message: string; }

toast :: (message: string) {
    if context.reqres.session_container then array_add(*context.reqres.session_container.toasts, .{message});
    else array_add(*context.reqres.res.toasts, .{message});
}

get_toasts :: () -> [..] Toast {
    toasts: [..] Toast;
    if !context.reqres.session_container {
        array_copy(*toasts, context.reqres.res.toasts);
        return toasts;
    }
    array_copy(*toasts, context.reqres.session_container.toasts);
    array_reset(*context.reqres.session_container.toasts);
    return toasts;
}

#scope_module
store_unseen_toasts_in_cookie :: () {
    using context.reqres;
    sb: String_Builder;
    first := true;
    if session && session_container.toasts.count > 0 {
        for session_container.toasts {
            append(*sb, ifx first then it.message else tprint("%1%2", UNSEEN_TOASTS_SEPARATOR, it.message));
            if first then first = false;
        }
        array_reset(*session_container.toasts);
    }
    for res.toasts {
        append(*sb, ifx first then it.message else tprint("%1%2", UNSEEN_TOASTS_SEPARATOR, it.message));
        if first then first = false;
    }
    cookie_set(UNSEEN_TOASTS_TOKEN, builder_to_string(*sb, allocator=temp));
}
