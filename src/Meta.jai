prebuild_step :: (w: Workspace) #expand {
    options := get_build_options(w);

    templates_dest   := sprint("%/templates", options.output_path);
    templates_source := sprint("%/templates", get_working_directory());

    copy_files_recursively(templates_source, templates_dest);

    copy_files_recursively :: (source: string, dest: string) {
        paths: [2] string;
        paths[0] = source;
        paths[1] = dest;

        visitor :: (info: *File_Visit_Info, paths: [2] string) {
            relative_path := info.full_name;
            advance(*relative_path, paths[0].count);
            out_path := join(paths[1], "/", relative_path);
            make_directory_if_it_does_not_exist(path_strip_filename(out_path), recursive=true);
            copy_file(info.full_name, out_path);
        }

        res := visit_files(paths[0], true, paths, visitor);
        assert(res);
    }
}

#import "Basic";
#import "Compiler";
#import "File_Utilities";
#import "File";
#import "String";
