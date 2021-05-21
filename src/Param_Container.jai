Param_Container :: struct {
    ints: Table(string, int);
    strings: Table(string, string);
}

init :: (param_container: *Param_Container) {
    init(*param_container.ints);
    init(*param_container.strings);
}

deinit :: (param_container: *Param_Container) {
    uninit(*param_container.ints);
    uninit(*param_container.strings);
}

copy :: (a: *Param_Container, b: *Param_Container) {
    for value, key: *a.ints {
        table_add(*b.ints, key, value);
    }
    for value, key: *a.strings {
        table_add(*b.strings, key, value);
    }
}

add_int :: inline (param_container: *Param_Container, key: string, value: int) {
    table_add(*param_container.ints, key, value);
}

add_string :: inline (param_container: *Param_Container, key: string, value: string) {
    table_add(*param_container.strings, key, value);
}

get_int :: inline (param_container: *Param_Container, key: string) -> int {
    param, success := table_find(param_container.ints, key);
    assert(success);
    return param;
}

get_string :: inline (param_container: *Param_Container, key: string) -> string {
    param, success := table_find(param_container.strings, key);
    assert(success);
    return param;
}
