Model :: struct {
    id: ID;
    ID :: int;
}
Model_Info :: struct {
    name: string;
    plural: string;
    fields: Table(string, *Field_Info);
}
Field_Info :: struct {
    tag: enum {
        INTEGER;
        FLOAT;
        BOOL;
        STRING;

        FOREIGN_KEY;
        ONE_TO_MANY;
    }
    name: string;
}
Field_Info_Integer :: struct {
    using info: Field_Info;
}
Field_Info_Float :: struct {
    using info: Field_Info;
}
Field_Info_Bool :: struct {
    using info: Field_Info;
}
Field_Info_String :: struct {
    using info: Field_Info;
}
Field_Info_Foreign_Key :: struct {
    using info: Field_Info;
    foreign_table: string;
}
Field_Info_One_To_Many :: struct {
    using info: Field_Info;
    foreign_key: string;
}

#placeholder set_model_infos;
model_infos: Table(string, Model_Info);
