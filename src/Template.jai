templates: Table(string, *Template);
Template_Variables :: #type Table(string, string);

Template_Piece :: struct {
    type: enum {
        TEXT;
        PARAM;
    }
    text: string;
    param_id: int;
}

Template :: struct {
    body: string;
    params: [..] string;
    pieces: [..] Template_Piece;
}

init_template_system :: (relative_template_path: string, extension: string = ".template") {
    working_directory, success := get_working_directory();
    if !success {
        print("failed to get current working directory");
        return;
    }
    template_path := tprint("%1%2", working_directory, relative_template_path);
    list := file_list(template_path, true);
    for list {
        if !ends_with(it, extension) then continue;
        short_name := replace(replace(it, tprint("%/", template_path), ""), extension, "");
        contents, success := read_entire_file(it);
        if success {
            parsed := parse(contents);
            /*write_string("\n\n---\n");
            for parsed.pieces {
                if it.type == {
                    case .TEXT;
                        write_string("TEXT: ");
                        write_string(it.text);
                        write_string("\n");
                    case .PARAM;
                        write_string("PARAM: ");
                        print("% (%)", it.param_id, parsed.params[it.param_id]);
                        write_string("\n");
                }
            }
            write_string("\n---\n\n");*/
            table_add(*templates, short_name, parsed);
        }
        else print("failed to load template: %\n", it);
    }
}

parse :: (input: string) -> *Template {
    tpl := New(Template);

    str := input;
    start, end: int;
    found: bool;

    n := 0;
    
    while true {
        start, found = index_of_string(str, "%{");
        if !found break;

        end, found = index_of_string(str, "}");
        if !found break;

        if end < start {
            print("ERROR PARSING TEMPLATE!\n");
            break;
        }

        new_param := slice(str, start + 2, end - start - 2);
        
        inserting_n: int;
        found, inserting_n = array_find(tpl.params, new_param);
        if !found {
            array_add(*tpl.params, new_param);
            inserting_n = n;
            n += 1;
        }
        
        text_before := slice(str, 0, start);
        if text_before.count > 0 {
            before_text: Template_Piece;
            before_text.type = .TEXT;
            before_text.text = text_before;
            array_add(*tpl.pieces, before_text);
        }

        param: Template_Piece;
        param.type = .PARAM;
        param.param_id = inserting_n;
        array_add(*tpl.pieces, param);

        str = slice(str, end + 1, str.count);
    }

    text_after := slice(str, 0, str.count);
    if text_after.count > 0 {
        after_text: Template_Piece;
        after_text.type = .TEXT;
        after_text.text = text_after;
        array_add(*tpl.pieces, after_text);
    }

    return tpl;
}

bind :: (res: *Response, variable_name: string, value: Any) {
    table_add(*res.template_variables, variable_name, tprint("%", value));
}

output_string :: (res: *Response, template: *Template) -> string #must {
    output_builder: String_Builder;
    
    for template.pieces {
        if it.type == {
            case .TEXT;
                append(*output_builder, it.text);
            case .PARAM;
                value, success := table_find(res.template_variables, template.params[it.param_id]);
                append(*output_builder, ifx success then value else "!!PARAM ERROR!!");
        }
    }
    return builder_to_string(*output_builder);
}

output_string :: (res: *Response, template_name: string) -> string #must {
    template, success := table_find(templates, template_name);
    if success then return output_string(res, template);
    else print("failed to output template: %", template_name);
    return "---";
}

output :: (res: *Response, template_name: string) {
    res.body = output_string(res, template_name);
}

bind_output :: (res: *Response, variable_name: string, template_name: string) {
    template, success := table_find(templates, template_name);
    if success then bind(res, variable_name, output_string(res, template));
    else print("failed to output template: %", template_name);
}
