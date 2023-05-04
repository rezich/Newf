Template :: struct {
    body:        string;
    params: [..] string;
    pieces: [..] Template_Piece;
}
Template_Piece :: struct {
    type:     enum { TEXT; PARAM; }
    text:     string;
    param_id: int;
}

templates: Table(string, Template);
templates_initialized := false;

init_templates :: (relative_template_path: string = "/templates", extension: string = ".html") {
    working_directory := get_working_directory();

    Visitor_Data :: struct { template_path: string; extension: string; }
    visitor_data := Visitor_Data.{
        template_path=tprint("%1%2", working_directory, relative_template_path),
        extension=extension
    };
    visitor :: (info: *File_Visit_Info, data: *Visitor_Data) {
        if !ends_with(info.short_name, data.extension) return;
        very_short_name := path_strip_extension(slice(info.full_name, data.template_path.count+1, info.full_name.count-data.template_path.count-1));
        contents: string;
        success: bool;
        new_context := context;
        new_context.allocator = temp;
        push_context new_context { contents, success = read_entire_file(info.full_name); }
        if success {
            template: Template;
            found: bool;
            n := 0;
            
            while true {
                start := find_index_from_left(contents, "%{");
                if start < 0 break;
                
                remaining_contents := slice(contents, start, contents.count);
                end := find_index_from_left(remaining_contents, "}");
                if end < 0 break;
                end += contents.count - remaining_contents.count;

                new_param := slice(contents, start + 2, end - start - 2);
                
                inserting_n: int;
                found, inserting_n = array_find(template.params, new_param);
                if !found {
                    array_add(*template.params, copy_string(new_param));
                    inserting_n = n;
                    n += 1;
                }
                
                text_before := slice(contents, 0, start);
                if text_before.count > 0 {
                    before_text: Template_Piece;
                    before_text.type = .TEXT;
                    before_text.text = copy_string(text_before);
                    array_add(*template.pieces, before_text);
                }

                param: Template_Piece;
                param.type = .PARAM;
                param.param_id = inserting_n;
                array_add(*template.pieces, param);

                contents = slice(contents, end + 1, contents.count);
            }

            text_after := slice(contents, 0, contents.count);
            if text_after.count > 0 {
                after_text: Template_Piece;
                after_text.type = .TEXT;
                after_text.text = copy_string(text_after);
                array_add(*template.pieces, after_text);
            }
            table_add(*templates, copy_string(very_short_name), template);
        }
        else print("failed to load template: %\n", info.short_name);
    }
    visit_files(visitor_data.template_path, true, *visitor_data, visitor, visit_files=true, visit_directories=false);
    templates_initialized = true;
}

free_templates :: () {
    for * templates {
        for * it.pieces if it.type ==.TEXT then free(it.text);
        array_free(it.pieces);
        for * it.params free(it.data);
        array_free(it.params);
        free(it.body);
        free(it_index.data);
    }
    table_reset(*templates);
    deinit(*templates);
}

render :: (template_name: string, args: ..Any) -> string #must {
    using context.reqres;
    if !templates_initialized init_templates();
    template := table_find_pointer(*templates, template_name);
    if !template return tprint("-- TEMPLATE NOT FOUND: % --\n", template_name);
    if args.count > 0 && args.count != template.params.count {
        return tprint("-- RENDER ARGUMENT ERROR: % --\n", template_name);
    }
    for args param_set(template.params[it_index], it);
    builder: String_Builder;
    for template.pieces if it.type == {
        case .TEXT;
            append(*builder, it.text);
        case .PARAM;
            param_name := template.params[it.param_id];
            value, found := param_get(param_name);
            if !res.rendered_toasts && param_name == "toasts" {
                _, toast_template_exists := table_find(*templates, TOAST_TEMPLATE_NAME);
                if toast_template_exists {
                    res.rendered_toasts = true;
                    value = render_each(res.toasts, #code render_it(TOAST_TEMPLATE_NAME, it));
                    found = true;
                }
            }
            append(*builder, ifx found then value else ""); // blank if nonexistent might not be the Right Thing To Do, we'll see...
    }
    return builder_to_string(*builder, allocator=temp);
}
render_each :: (items: $T, code: Code, when_empty: string = "") -> string #expand {
    using context.reqres;
    if !items.count return when_empty;
    builder: String_Builder;
    for items #insert,scope() code;
    return builder_to_string(*builder, allocator=temp);

    render_it :: (template_name: string, args: ..Any) #expand {
        append(*`builder, render(template_name, ..args));
    }
}

toast :: (message: string) { array_add(*context.reqres.res.toasts, message); }
