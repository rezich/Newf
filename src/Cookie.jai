cookie_get :: (key: string) -> value := "", success := true {
    value, success := table_find(context.reqres.req.cookies, key);
    if !success return success = false;
    return decode_uri_component(value), success = value != "";
}
cookie_set :: (key: string, value: Any) { cookie_set(key, tprint("%", value)); }
cookie_set :: (key: string, value: string) { table_set(*context.reqres.res.cookies, key, encode_uri_component(value)); }
cookie_unset :: (key: string) { table_set(*context.reqres.res.cookies, key, "INVALID_TOKEN; expires=Thu, 01 Jan 1970 00:00:00 GMT"); }
