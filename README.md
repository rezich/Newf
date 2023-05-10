Newf
====
Newf is a new web framework for a new language, designed to make it as easy as possible to create
high-performance website backends that can be deployed as a single executable.

**Newf is presently Windows-only.** But this is only because the server part is written using
Winsock, for now -- it'll be rewritten to use the cross-platform `Socket` module, eventually.

Check [the example](examples/dorknews) out to see how it works:

```sh
git clone https://github.com/rezich/Newf.git
git clone https://github.com/rezich/SQLite.git # required for the example
cd Newf\examples\dorknews
jai dorknews.jai
.\bin\www
```

This will host the example website at [localhost:8000](http://localhost:8000).




Object-relational mapping/database stuff (or lack thereof)
----------------------------------------------------------
Despite being a Modern Web Framework, Newf does not include anything like this! However, Newf pairs
well with [rezich/SQLite](https://github.com/rezich/SQLite), and in fact was developed alongside it.
If you want to use Newf to make a website with any kind of database functionality, it's highly
recommended that you check it out -- [the included example](examples/dorknews/) shows how easy it is
to use.

In the future, SQLite may be *required* to use Newf, because it'll allow for better storage of user
sessions, among other things.




Template syntax
---------------
Template files are just normal HTML files, but with "parse strings" surrounded by `%{` and `}`,
which are parsed and interpreted at compile time.


### Parameters
The most straightforward use of the template syntax, this is how you render dynamic content within
your static HTML templates:

#### `%{member}`
Render the member `member` of the struct passed into `Render()`
#### ~~`%{member|Default text}`~~
**(not yet implemented)**
#### ~~`%{member|{{default_template_name}}}`~~
**(not yet implemented)**


### Includes
Sometimes it's useful to compose templates from other templates. There's no need to worry about any
runtime performance hit for doing this, because templates are baked into the executable at compile
time!

#### `%{{template_name}}`
Include the template named `template_name` inside of this one


### Delegated includes
It's a pretty common situation: you have a struct member that's an array of something, and you want
to render each item in the array with a template. This is where the delegated include syntax comes
in handy.

#### `%{member -> {template_name}}`
Render each item in the array member `member` of the struct passed in using the `template_name` template
#### ~~`%{member -> {template_name}|Default text}`~~
**(not yet implemented)**
#### ~~`%{member -> {template_name}|{{default_template_name}}}`~~
**(not yet implemented)**


In addition to being able to access any member of the struct you pass to `Render()`, you can also
access members of `context.reqres.state` by using `state.member` as the parameter name in your
template HTML.




TODO
====
 - implement the not-yet-implemented template syntax items above
 - store session data in a SQLite table instead of in memory
 - session expiry; automatically remove expired sessions
 - big cleanup in [Server.jai](src/Server.jai)
 - caching on routes!
 - a compile flag to enable template "hotloading" (actually just program-restarting), including helpful error messages
 - static file routing
 - improve HTTP request parsing & make it completely HTTP/1.0 compliant
 - HTTP 1.1
 - Linux support
 - Gemini support
 - some crazy experimental ideas for interactive tooling
 - ...
