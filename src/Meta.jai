prebuild_step :: (w: Workspace) {
    array_reset(*model_names);
    /*generated_code = false;
    array_reset(*entity_type_names);
    table_reset(*entity_items_per_bucket);
    _entity_type_name = entity_type_name;
    if autoload {
        assert(file_exists(autoload_directory), sprint("Entity autoload directory % not found.", autoload_directory));
        entity_files := file_list(autoload_directory);
        for entity_files add_build_string(tprint("#load \"%\";", it), w);
    }

    init(*entity_items_per_bucket);*/
}

build_step :: inline (message: *Message) {
    if message.kind == {
        case .TYPECHECKED;
            typechecked := cast(*Message_Typechecked) message;
            for typechecked_struct: typechecked.structs {
                code_struct := typechecked_struct.expression;
                name := code_struct.defined_type.name;
                // get all Model
                if is_subclass_of(code_struct.defined_type, "Model") {
                    name_lower := copy_string(name);
                    to_lower(name_lower);
                    plural := tprint("%1%2", name_lower, "s");
                    for note: code_struct.notes if begins_with(note.text, NOTE_PLURAL) then plural = slice(note.text, NOTE_PLURAL.count, note.text.count);
                    model_info: *Model_Info;
                    _model_info: Model_Info;
                    _model_info.name = name;
                    _model_info.plural = plural;
                    model_info = table_set(*models, name, _model_info);
                    if array_add_if_unique(*model_names, name) {
                        log_verbose("Model: % | plural: %\n", name, plural);
                        code_struct_type_info := code_struct.defined_type;
                        for member: code_struct_type_info.members {
                            if member.type.type == {
                                 case .INTEGER;
                                    field_info := New(Field_Info_Integer);
                                    field_info.tag = .INTEGER;
                                    field_info.name = member.name;
                                    table_set(*model_info.fields, member.name, field_info);
                                    log_verbose("  field: INTEGER %", member.name);
                                 case .FLOAT;
                                    field_info := New(Field_Info_Float);
                                    field_info.tag = .FLOAT;
                                    field_info.name = member.name;
                                    table_set(*model_info.fields, member.name, field_info);
                                    log_verbose("  field: FLOAT %", member.name);
                                 case .BOOL;
                                    field_info := New(Field_Info_Bool);
                                    field_info.tag = .BOOL;
                                    field_info.name = member.name;
                                    table_set(*model_info.fields, member.name, field_info);
                                    log_verbose("  field: BOOL %", member.name);
                                case .STRING;
                                    field_info := New(Field_Info_String);
                                    field_info.tag = .STRING;
                                    field_info.name = member.name;
                                    table_set(*model_info.fields, member.name, field_info);
                                    log_verbose("  field: STRING %", member.name);
                                case .POINTER;
                                    field_info := New(Field_Info_Foreign_Key);
                                    field_info.tag = .FOREIGN_KEY;
                                    field_info.name = member.name;
                                    fk_model := (cast(*Type_Info_Struct) ((cast(*Type_Info_Pointer) (member.type)).pointer_to)).name;
                                    log_verbose("  field: FOREIGN_KEY % -> %", member.name, fk_model);
                                    field_info.foreign_table = fk_model;
                                    table_set(*model_info.fields, member.name, field_info);
                                case .ARRAY;
                                    array_info := cast(*Type_Info_Array) member.type;
                                    assert(array_info.array_type == .RESIZABLE && array_info.element_type.type == .POINTER, ERROR_FIELD_DECLARATION);
                                    fk := name_lower;
                                    for note: member.notes if begins_with(note, NOTE_FOREIGN_KEY) then fk = slice(note, NOTE_FOREIGN_KEY.count, note.count);
                                    field_info := New(Field_Info_One_To_Many);
                                    field_info.tag = .ONE_TO_MANY;
                                    field_info.name = member.name;
                                    field_info.foreign_key = fk;
                                    table_set(*model_info.fields, member.name, field_info);
                                    log_verbose("  field: ONE_TO_MANY % <- %", member.name, field_info.foreign_key);
                            }
                        }
                    }
                }
            }
        
        case .PHASE;
            phase := cast(*Message_Phase) message;
            if phase.phase == .TYPECHECKED_ALL_WE_CAN {
                /*if !generated_code {
                    generate_code(message.workspace);
                    generated_code = true;
                }*/
            }
    }
}


#scope_file

ERROR_FIELD_DECLARATION :: "Model fields can only be integers, floats, bools, strings, pointer-to-other-models, and resizable-array-of-pointer-to-other-models.";
NOTE_PLURAL ::"plural=";
NOTE_FOREIGN_KEY :: "fk=";

/*generate_code :: (w: Workspace) {
    builder: String_Builder; defer free_buffers(*builder);
    //print_to_builder(*builder, )
    add_build_string(builder_to_string(*builder), w);
}*/

model_names: [..] string;
models: Table(string, Model_Info);

log_verbose :: (data: string, args: ..Any) { /*#if VERBOSE print(data, ..args);*/ }

#import "Web_Framework"(BUILDING=true);

#import "Basic";
#import "Compiler";
#import "String";
#import "Sort";
#import "File_Utilities";
#import "Hash_Table";
