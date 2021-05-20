templates: Table(string, *Template);
template_variables: Table(string, Any);

Template :: struct {
    body: string;
    output_body: string;
    parameters: [..] string;
}

tpl_init :: () {
    init(*template_variables, 32);
    template_path := tprint("%/templates", #filepath);
    list := file_list(template_path, true);
    for list {
        short_name := replace(replace(it, tprint("%/", template_path), ""), ".template", "");
        contents, success := read_entire_file(it);
        if success then table_add(*templates, short_name, parse(contents));
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
        found, inserting_n = array_find(tpl.parameters, new_param);
        if !found {
            array_add(*tpl.parameters, new_param);
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

output :: (template: *Template) {
    output_params: [..] Any;
    for param: template.parameters {
        value, success := table_find(template_variables, param);
        array_add(*output_params, ifx success then value else tprint("!!PARAM ERROR: % !!", param));
    }
    print(template.output_body, .. output_params);
}

output :: (template_name: string) {
    template, success := table_find(templates, template_name);
    if success then output(template);
}
