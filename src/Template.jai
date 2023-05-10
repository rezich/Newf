Template :: struct {
    name:        string;
    filename:    string;
    body:        string;
    pieces: [..] struct {
        type:     enum { TEXT; PARAM; DELEGATED; }
        text:     string;
        delegate: string;
    };
}

Render :: (
    $template_name: string,
            __data: $T,
      nested_depth:=0,
               loc:=#caller_location, // unused, for now
       caller_code:=#caller_code      // unused, for now
) -> string
#modify {
        info := cast(*Type_Info) T;
        if (info).type == {
            case .STRUCT; return true;
            case .TYPE; return true;
            case .ARRAY;
                array_info := cast(*Type_Info_Array) info;
                if array_info.element_type.type == {
                    case .STRUCT; return true;
                    case .POINTER; return (cast(*Type_Info_Pointer) array_info).pointer_to.type == .STRUCT;
                }
            case .POINTER; return (cast(*Type_Info_Pointer) info).pointer_to.type == .STRUCT;
        }
        return false;
}
#expand {
    sb: String_Builder;
    
    /*if (cast(*Type_Info) T).type != .VOID then */#insert -> string {

        template := get_or_load_template(template_name);
        assert(!!template, "TEMPLATE NOT FOUND: [%]", template_name);

        sb: String_Builder;
        print_to_builder(*sb, #string XX
%1 {
XX,     /* 1 */ ifx (cast(*Type_Info) T).type == .ARRAY "for __data: __data");
        for template.pieces if it.type == {
            case .TEXT;
                str := #string XX_OUTER_XX
    {
        __str := #string XX_INNER_XX
%1
XX_INNER_XX;
        __str.count -= 1;
        append(*sb, __str);
    }
XX_OUTER_XX;
                str.count -= 1;
                print_to_builder(*sb, str, it.text);
            case .PARAM;
                if (cast(*Type_Info) T).type == .VOID then continue;
                print_to_builder(*sb, #string XX
    print_to_builder(*sb, "%%", %1%2);
XX,             /* 1 */ ifx !begins_with(it.text, "state.") then "__data." else "context.reqres.",
                /* 2 */ it.text
                );
            case .DELEGATED;
                info := cast(*Type_Info) T;
                assert(info.type != .VOID);
                if nested_depth >= MAX_NESTED_DELEGATED_TEMPLATE_DEPTH then continue;
                str := #string XX
    %1append(*sb, Render("%2", __data.%3, nested_depth=%4));
XX;
                str.count -= 1;
                print_to_builder(*sb, str,
                /* 1 */ ifx info.type == .ARRAY   then tprint("if __data.%1.count > 0 then ", it.text) else
                        ifx info.type == .POINTER then tprint("if !!__data.%1 then ", it.text),
                /* 2 */ it.delegate,
                /* 3 */ it.text,
                /* 4 */ nested_depth+1
                );

        }
        append(*sb, #string XX
}
XX);
        return builder_to_string(*sb);
    }
    return builder_to_string(*sb, allocator=temp);
}

Render :: (
           __data: $T,
   $template_name: string,
              loc:=#caller_location,
      caller_code:=#caller_code
) -> string
#modify { return (cast(*Type_Info) T).type != .STRING; } #expand {
    return Render(template_name, __data, loc=loc, caller_code=caller_code);
}

Render :: (
   $template_name: string,
              loc:=#caller_location,
      caller_code:=#caller_code
) -> string {
    return Render(template_name, void, loc=loc, caller_code=caller_code);
}

templates: Table(string, Template);

get_or_load_template :: (name: string, relative_template_path: string = "/templates", extension: string = ".html") -> *Template {
    PARSE_STRING_BEGIN   :: "%{";
    PARSE_STRING_END     :: "}";
    INCLUDE_STRING_BEGIN :: "{";
    INCLUDE_STRING_END   :: "}";
    INCLUDE_DELEGATOR    :: "->";

    existing_template := table_find_pointer(*templates, name);
    if !!existing_template then return existing_template;

    new_template := table_add(*templates, name, .{});

    filename := get_filename_from_template_name(name);
    file_contents, file_was_read := read_entire_file(filename);
    assert(file_was_read, "template file % (%) was not read!", name, filename);

    contents_remaining := copy_string(file_contents);
    while contents_remaining.count > 0 {
        index_of_start_of_parse_string_including_encapsulating_notation := find_index_from_left(contents_remaining, PARSE_STRING_BEGIN);
        if index_of_start_of_parse_string_including_encapsulating_notation < 0 then break;

        part_before_parse_string_including_encapsulating_notation := slice(contents_remaining, 0, index_of_start_of_parse_string_including_encapsulating_notation);

        index_of_start_of_parse_string := index_of_start_of_parse_string_including_encapsulating_notation + PARSE_STRING_BEGIN.count;
        is_template_include := slice(contents_remaining, index_of_start_of_parse_string, INCLUDE_STRING_BEGIN.count) == INCLUDE_STRING_BEGIN;
        is_delegated_include := false;
        if !is_template_include {
            next_include_delegator := find_index_from_left(contents_remaining, INCLUDE_DELEGATOR, index_of_start_of_parse_string_including_encapsulating_notation);
            if next_include_delegator > 0 {
                next_parse_string_end := find_index_from_left(contents_remaining, PARSE_STRING_END, index_of_start_of_parse_string_including_encapsulating_notation);
                is_delegated_include = next_include_delegator < next_parse_string_end;
            }
        }
        if is_template_include then index_of_start_of_parse_string += INCLUDE_STRING_BEGIN.count;

        index_of_end_of_parse_string_including_encapsulating_notation := find_index_from_left(contents_remaining, PARSE_STRING_END, index_of_start_of_parse_string_including_encapsulating_notation);
        if index_of_end_of_parse_string_including_encapsulating_notation < 0 then break;

        if is_template_include || is_delegated_include {
            assert(slice(contents_remaining, index_of_end_of_parse_string_including_encapsulating_notation+PARSE_STRING_END.count, INCLUDE_STRING_END.count) == INCLUDE_STRING_END, "template include is missing second closing brace!");
            index_of_end_of_parse_string_including_encapsulating_notation += INCLUDE_STRING_END.count;
        }

        count_of_parse_string_including_encapsulating_notation := index_of_end_of_parse_string_including_encapsulating_notation - index_of_start_of_parse_string_including_encapsulating_notation + PARSE_STRING_END.count + ifx is_template_include then INCLUDE_STRING_END.count;

        index_of_end_of_parse_string := index_of_end_of_parse_string_including_encapsulating_notation - ifx is_template_include then INCLUDE_STRING_BEGIN.count;
        count_of_parse_string := index_of_end_of_parse_string - index_of_start_of_parse_string;

        to_replace := slice(contents_remaining, index_of_start_of_parse_string_including_encapsulating_notation, count_of_parse_string_including_encapsulating_notation);

        to_parse := slice(contents_remaining, index_of_start_of_parse_string, count_of_parse_string);

        part_after_parse_string_including_encapsulating_notation := slice(
            contents_remaining,
            index_of_end_of_parse_string_including_encapsulating_notation + 1,
            contents_remaining.count - index_of_end_of_parse_string_including_encapsulating_notation - 1
        );

        if is_template_include {
            include_filename := get_filename_from_template_name(to_parse);
            include_contents, include_was_read := read_entire_file(include_filename);
            assert(include_was_read, "include template file % (%) was not read!", to_parse, include_filename);
            contents_remaining = tprint("%1 %2%3", copy_string(part_before_parse_string_including_encapsulating_notation), include_contents, copy_string(part_after_parse_string_including_encapsulating_notation));
            continue;
        }
        else {
            if part_before_parse_string_including_encapsulating_notation.count > 0 {
                array_add(*new_template.pieces, .{
                    type=.TEXT,
                    text=copy_string(part_before_parse_string_including_encapsulating_notation)
                });
            }
            if is_delegated_include {
                _, text, delegate := split_from_left(to_parse, INCLUDE_DELEGATOR);
                text = trim(text);
                delegate = trim(delegate);
                delegate.data += INCLUDE_STRING_BEGIN.count;
                delegate.count -= INCLUDE_STRING_BEGIN.count + INCLUDE_STRING_END.count;
                array_add(*new_template.pieces, .{
                    type=.DELEGATED,
                    text=text,
                    delegate=delegate
                });
            }
            else {
                array_add(*new_template.pieces, .{
                    type=.PARAM,
                    text=copy_string(to_parse)
                });
            }
            contents_remaining = copy_string(part_after_parse_string_including_encapsulating_notation);
        }
    }
    if contents_remaining.count > 0 {
        array_add(*new_template.pieces, .{
            type=.TEXT,
            text=copy_string(contents_remaining)
        });
    }
    return new_template;

    get_filename_from_template_name :: (template_name: string) -> string #expand {
        return tprint("%1%2/%3%4", get_working_directory(), relative_template_path, template_name, extension);
    }
}
