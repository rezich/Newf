#module_parameters(
    BUILDING := false,
    HOSTNAME := "localhost:8000"
);

#if BUILDING #load "src/Meta.jai";
else #load "src/Web_Framework.jai";