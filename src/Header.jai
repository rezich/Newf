header_get :: (key: string) -> value := "", success := true {
    value, success := table_find(context.reqres.req.uri.headers, key);
    if !success return success = false;
    return value;
}
header_set :: inline (key: string, value: Any) { header_set(key, tprint("%", value)); }
header_set :: inline (key: string, value: string) { table_set(*context.reqres.res.headers, key, value); }
