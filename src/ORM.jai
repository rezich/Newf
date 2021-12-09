Model :: struct {
    id: ID;
    ID :: int;
}

QuerySet :: struct {

}

One :: struct(type: Type) { item: *type; }
Many :: struct(type: Type) { items: [..] *type; }
// ...probably not.

insert :: (item: $T/Model) {

}
update :: (item: $T/Model) {

}
select :: ($type: Type, prefetch: [] string = .[], where: (x: type) -> bool = null) -> [..] type {
    results: [..] type;
    return results;
}
select_one :: ($type: Type, where: (x: type) -> bool = null) -> type {
    result: type;
    return result;
}
delete :: (item: $T/Model) {

}
