#module_parameters(
    //BUILDING := false,
    HOSTNAME := "localhost",
    SESSIONS_PER_BUCKET := 1000,
    SESSION_TOKEN := "_SESSION_TOKEN"
);

/*#if BUILDING #load "src/Meta.jai";
else */#load "src/Web_Framework.jai";