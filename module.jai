#module_parameters(
    BUILDING := false,
    VERBOSE := true,
    HOSTNAME := "localhost",
    SESSIONS_PER_BUCKET := 1000,
    SESSION_TOKEN := "_SESSION_TOKEN",
    UNSEEN_TOASTS_TOKEN := "_UNSEEN_TOASTS",
    UNSEEN_TOASTS_SEPARATOR := "\n\n",
    TOAST_TEMPLATE_NAME := "toast", //TODO: remove this when Toasts become a plugin or whatever
    DATABASE_BACKEND := Database_Backend.SQLITE
);

Database_Backend :: enum {
    NONE;
    SQLITE;
}

#if DATABASE_BACKEND == .SQLITE then #load "lib/sqlite/sqlite3.jai";
#if DATABASE_BACKEND == .SQLITE then #add_context db: *sqlite3;

#if BUILDING #load "src/Meta.jai";
#if !BUILDING #load "src/Web_Framework.jai";
#if !BUILDING && DATABASE_BACKEND != .NONE #load "src/ORM.jai";
#if DATABASE_BACKEND != .NONE #load "src/Model.jai";
