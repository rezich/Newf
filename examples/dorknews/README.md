dorknews
========
This is a work-in-progress barebones Digg/Hacker News/reddit/etc. clone that shows an example of how
Newf can be used to create simple websites fairly easily.

 - [**`dorknews.jai`**](dorknews.jai) is the metaprogram that builds the website executable as **`bin/www`**.
 - [**`src/Main.jai`**](src/Main.jai) is the main website executable entry point.
 - [**`src/Models.jai`**](src/Models.jai) contains all of the "Models", i.e. structs that automatically serialize to SQLite table rows.
 - [**`src/Routes.jai`**](src/Routes.jai) contains all of the "Routes", which define how the server responds to variously-shaped HTTP requests.
 - [**`src/Session_and_State.jai`**](src/Session_and_State.jai) defines the "Session" and "State" structs, which are user-defined server-side data. The former is for persistent user session data, while the latter is for transient data for a single request resolution.
 - [**`src/Mock_Database.jai`**](src/Mock_Database.jai) contains some mock data to fill into the database, for testing.
 - [**`templates/`**](templates/) contains all of the HTML templates, rendered with the `Render()` macro. These are type-checked and baked into the website executable at compile time. See [the Newf README](../../README.md) for a template syntax explanation.




Building
--------
To build dorknews, [rezich/SQLite](https://github.com/rezich/SQLite.git) needs to be in the same directory as Newf. Then, you just run
```sh
jai dorknews.jai
.\bin\www
```
This serves dorknews locally on port 8000 (when `BUILD` is set to `.DEVELOPMENT` -- see [`src/Main.jai`](src/Main.jai)). Visit [localhost:8000](http://localhost:8000) in your browser to view the website.

Alternatively, you can simply run
```sh
jai dorknews.jai - dev
```
This does the same thing as above, except it automatically runs the server after successfully compiling it, plus, it automatically recompiles & reruns the server if any changes are detected in `src/` or `templates/`. This is useful during development.

To run a performance report on the compilation process, do `jai dorknews.jai - perf`.
