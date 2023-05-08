#module_parameters(
    VERBOSE := false,
    HOSTNAME := "localhost",
    SESSIONS_PER_BUCKET := 1000,
    SESSION_TOKEN := "_SESSION_TOKEN",
    UNSEEN_TOASTS_TOKEN := "_UNSEEN_TOASTS",
    UNSEEN_TOASTS_SEPARATOR := "\n\n",
    TOAST_TEMPLATE_NAME := "toast" //TODO: remove this when Toasts become a plugin or whatever
);

#load "src/Newf.jai";
