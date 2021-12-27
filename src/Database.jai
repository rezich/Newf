Query_Result :: struct {
    query: string;
    error: struct {
        code: int;
        message: string;
    }
    rows: [..] Row;

    Row :: #type Table(string, string);
}

#placeholder Database_Cache;
#add_context db_cache: Database_Cache;

print_result :: (result: *Query_Result) {
    if result.error.code == SQLITE_OK && result.rows.count == 0 {
        print("QUERY RESULT: SUCCESS (empty)\n");
        return;
    }
    print("QUERY RESULT\n============\n");
    print("QUERY: %\n", result.query);
    if result.error.code != SQLITE_OK then print("Error\n-----\nCode: %\nMessage: %\n", result.error.code, result.error.message);
    for row, row_index: result.rows {
        print("  row %\n", row_index + 1);
        for row print("    %: %\n", it_index, it);
    }
    print("\n");
}

query_exec :: (query: string) -> Query_Result {
    error_message: *s8;
    result: Query_Result;
    result.query = query;
    query_cstr := cast(*s8) to_c_string(query); defer free(query_cstr);
    result.error.code = sqlite3_exec(context.db, query_cstr, (_result: *void, argc: s32, argv: **s8, column_name: **s8) -> s32 #c_call {
        new_context: Context;
        push_context new_context {
            result := cast(*Query_Result) _result;
            row: Query_Result.Row;
            array_add(*result.rows, row);
            for 0..argc-1 {
                k := to_string(cast(*u8) column_name[it]);
                v := ifx argv[it] then to_string(cast(*u8) argv[it]) else "NULL";
                table_set(*result.rows[0], copy_temporary_string(k), copy_temporary_string(v));
            }
        }
        return 0;
    }, *result, *error_message);
    if result.error.code != SQLITE_OK {
        result.error.message = tprint("%", to_string(cast(*u8) sqlite3_errmsg(context.db)));
        sqlite3_free(error_message);
    }
    print_result(*result);
    return result;
}

query :: (query: string) -> Query_Result {
    error_message: *s8;
    result: Query_Result;
    result.query = query;
    result.error.code = SQLITE_BUSY;
    prepared_statement: *sqlite3_stmt;
    //sqlite3_mutex_enter(context.db.mutex);
    sqlite3_prepare_v2(context.db, cast(*s8) query.data, cast(s32) query.count, *prepared_statement, null);
    while result.error.code == SQLITE_BUSY || result.error.code == SQLITE_ROW {
        result.error.code = sqlite3_step(prepared_statement);
        if result.error.code == SQLITE_ROW {
            _row: Query_Result.Row;
            array_add(*result.rows, _row);
            i := result.rows.count-1;
            row := *result.rows[i];
            column_count := sqlite3_column_count(prepared_statement);
            for 0..column_count-1 {
                table_set(
                    row,
                    copy_temporary_string(to_string(cast(*u8) sqlite3_column_name(prepared_statement, it))),
                    copy_temporary_string(to_string(cast(*u8) sqlite3_column_text(prepared_statement, it)))
                );
            }
        }
    }
    rc := sqlite3_finalize(prepared_statement);
    //sqlite3_mutex_leave(context.db.mutex);
    if result.error.code == SQLITE_OK then result.error.code = rc;
    if result.error.code == SQLITE_DONE then result.error.code = SQLITE_OK;
    if result.error.code != SQLITE_OK {
        result.error.message = tprint("%", to_string(cast(*u8) sqlite3_errmsg(context.db)));
    }
    print_result(*result);
    return result;
}

//TODO: restrict type to only Models
select_from :: ($type: Type, fields: [] string = .["*"], where: string = "", limit: int = 0, offset: int = 0, fetch: [] string = .[]) -> [..] *type {
    results: [..] *type;
    q := xprint(
        "SELECT * FROM ",
        type, " ",
        ifx where != "" then tprint("WHERE % ", where) else "",
        ifx limit != 0 then tprint("LIMIT % ", limit) else "",
        ifx offset != 0 then tprint("OFFSET % ", offset) else ""
    );
    db_open(); //TODO: remove!
    q_result := query(q);
    db_close(); //TODO: remove!
    for q_result.rows {
        received := db_receive(type, it);
        inserted: *type;
        #insert #run sprint("inserted = table_set(*context.db_cache._%1, received.id, received);", type);
        array_add(*results, inserted);
    }
    return results;
}

insert :: (obj: $T/Model) -> int {
    info := type_info(T);
    names_string, values_string: string;
    {
        sb_names: String_Builder; defer free_buffers(*sb_names);
        sb_values: String_Builder; defer free_buffers(*sb_values);
        field_number := 0;
        for member: info.members {
            if member.flags != 0 continue;
            comma_space := ifx field_number > 0 then ", " else "";
            is_pointer := false;
            if member.type.type == {
                case .INTEGER;
                    print_to_builder(*sb_values, "%1%2", comma_space, << cast(*int) (cast(*void) *obj + member.offset_in_bytes));
                case .FLOAT;
                    print_to_builder(*sb_values, "%1%2", comma_space, << cast(*float) (cast(*void) *obj + member.offset_in_bytes));
                case .BOOL;
                    print_to_builder(*sb_values, "%1%2", comma_space, << cast(*bool) (cast(*void) *obj + member.offset_in_bytes));
                case .STRING;
                    print_to_builder(*sb_values, "%1'%2'", comma_space, << cast(*string) (cast(*void) *obj + member.offset_in_bytes));
                case .POINTER;
                    other := << cast(**Model) (cast(*void) *obj + member.offset_in_bytes);
                    id := ifx other != null then tprint("%", other.id) else "NULL";
                    print_to_builder(*sb_values, "%1%2", comma_space, id);
                    is_pointer = true;
            }
            print_to_builder(*sb_names, "%1%2%3", comma_space, member.name, ifx is_pointer then "_id" else "");
            field_number += 1;
        }
        names_string = builder_to_string(*sb_names);
        values_string = builder_to_string(*sb_values);
    }
    q := tprint(#string XX
INSERT INTO %1(%2) VALUES (%3) RETURNING id;
XX,     T, names_string, values_string
    );
    db_open(); //TODO: remove!
    result := query(q);
    db_close(); //TODO: remove!
    id := -1;
    if result.rows.count > 0 {
        row := result.rows[0];
        row_id, success := table_find(row, "id");
        if success then id = parse_int(*row_id);
    }
    return id;
}

db_receive :: ($type: Type, row: Query_Result.Row) -> type {
    result: type;
    info := type_info(type);
    for member: info.members {
        if member.flags != 0 continue;
        received := table_find_pointer(row, member.name);
        if received == null continue;
        value_location: *void = (cast(*void) *result + member.offset_in_bytes);
        if member.type.type == {
            case .INTEGER;
                << cast(*int) value_location = string_to_int(<<received);
            case .FLOAT;
            case .BOOL;
            case .STRING;
                << cast(*string) value_location = tprint(<<received);
            case .POINTER;
                << cast(**Model) value_location = null; //TODO
            case .ARRAY;
        }
    }
    id, id_exists := table_find(row, "id");
    if !id_exists then print("!!!!!!!! ID NOT FOUND!!!\n");
    result.id = string_to_int(id);
    return result;
}

db_open :: () {
    #if DATABASE_BACKEND == .SQLITE {
        error_message: *s8;
        rc := sqlite3_open(cast(*s8) to_c_string("database.db"), *context.db);
        if rc then print("!!! Can't open database.\n");
    }
}

db_close :: () {
    #if DATABASE_BACKEND == .SQLITE {
        sqlite3_close(context.db);
    }
}
