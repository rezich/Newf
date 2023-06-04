bucket_array_find_pointer :: (using array: *Bucket_Array, locator: Bucket_Locator) -> *array.type {
    bucket := all_buckets[locator.bucket_index];
    assert(bucket.occupied[locator.slot_index] == true);
    result := *bucket.data[locator.slot_index];
    return result;
}

encode_uri_component :: (text: string) -> string {
    new_context := context;
    push_context new_context {
        should_encode :: (char: u8) -> bool {
            if  (char >= #char "A" && char <= #char "Z") ||
                (char >= #char "a" && char <= #char "z") ||
                (char >= #char "0" && char <= #char "9") ||
                 char == #char "-" || char == #char "_"  || char == #char "." ||
                 char == #char "!" || char == #char "~"  || char == #char "*" ||
                 char == #char "'" || char == #char "("  || char == #char ")"
            then return false;
            return true;
        }
        builder: String_Builder;
        format_int := *context.print_style.default_format_int;
        format_int.base = 16;
        format_int.minimum_digits = 2;
        for 0..text.count-1 {
            if should_encode(text[it]) then print_to_builder(*builder, "%%%1", text[it]);
            else append(*builder, text[it]);
        }
        return builder_to_string(*builder, allocator=temp);
    }
}

decode_uri_component :: (text: string) -> string {
    builder: String_Builder;
    str := text;
    while str != "" {
        next_percent := find_index_from_left(str, #char "%");
        if next_percent == -1 || next_percent + 2 >= str.count {
            append(*builder, str);
            break;
        }
        if next_percent > 0 then append(*builder, slice(str, 0, next_percent));
        a := str[next_percent+1];
        b := str[next_percent+2];
        if is_hex_number(a) && is_hex_number(b) {
            if a >= #char "a" then a -= #char "a" - #char "A";
            if a >= #char "A" then a -= #char "A" - 10;
            else a -= #char "0";
            if b >= #char "a" then b -= #char "a" - #char "A";
            if b >= #char "A" then b -= #char "A" - 10;
            else b -= #char "0";
            append(*builder, cast(u8) 16 * a + b);
        }
        else append(*builder, slice(str, next_percent, next_percent + 2));
        str = slice(str, next_percent + 3, str.count);
    }
    return builder_to_string(*builder, allocator=temp);
}

decode_form :: (text: string) -> string {
    str := text;
    replace_chars(str, "+", #char " ");
    return decode_uri_component(str);
}

is_hex_number :: inline (c: u32) -> bool { return (c >= #char "a" && c <= #char "f") || (c >= #char "A" && c <= #char "F") || is_digit(xx c); }
