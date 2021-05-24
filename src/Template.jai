templates: Table(string, *Template);
template_variables: Table(string, Any);

Template :: struct {
    body: string;
    output_body: string;
    params: [..] string;
}

init_template_system :: (relative_template_path: string, extension: string = ".template") {
    init(*template_variables, 32);
    working_directory, success := get_working_directory();
    if !success {
        print("failed to get current working directory");
        return;
    }
    template_path := tprint("%1%2", working_directory, relative_template_path);
    list := file_list(template_path, true);
    for list {
        short_name := replace(replace(it, tprint("%/", template_path), ""), extension, "");
        contents, success := read_entire_file(it);
        if success then table_add(*templates, short_name, parse(contents));
        else print("failed to load template: %\n", it);
    }
}

parse :: (input: string) -> *Template {
    tpl := New(Template);

    str := input;
    start, end: int;
    found: bool;
    output_builder: String_Builder;

    n := 1;
    
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
        else {
            inserting_n += 1;
        }

        append(*output_builder, slice(str, 0, start));
        append(*output_builder, "%");
        append(*output_builder, tprint("%", inserting_n));

        str = slice(str, end + 1, str.count);
    }
    append(*output_builder, slice(str, 0, str.count));
    tpl.output_body = builder_to_string(*output_builder);
    return tpl;
}

reset_bindings :: () {
    table_reset(*template_variables);
}

bind :: (variable_name: string, value: Any) {
    table_add(*template_variables, variable_name, value);
}

output_string :: (using template: *Template) -> string #must {
    output_params: [..] Any;
    for param: params {
        value, success := table_find(template_variables, param);
        array_add(*output_params, ifx success then value else tprint("!!PARAM ERROR: % !!", param));
    }
    return tprint(output_body, .. output_params);
}

output_string :: (template_name: string) -> string #must {
    template, success := table_find(templates, template_name);
    if success then return output_string(template);
    else print("failed to output template: %", template_name);
    return "---";
}

output :: (res: *Response, template_name: string) {
    res.body = output_string(template_name);
}

bind_output :: inline (variable_name: string, template_name: string) {
    template, success := table_find(templates, template_name);
    if success then bind(variable_name, output_string(template));
    else print("failed to output template: %", template_name);
}
