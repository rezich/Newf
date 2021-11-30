#module_parameters(
    //BUILDING := false,
    HOSTNAME := "localhost",
    SESSIONS_PER_BUCKET := 1000,
    SESSION_TOKEN := "_SESSION_TOKEN",
    UNSEEN_TOASTS_TOKEN := "_UNSEEN_TOASTS",
    TOAST_TEMPLATE_NAME := "toast" //TODO: remove this when Toasts become a plugin or whatever
);

/*#if BUILDING #load "src/Meta.jai";
else */#load "src/Web_Framework.jai";