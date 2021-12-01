Web_Framework
=============
check [the example](examples/simple) to see how it works. right now the
metaprogram does nothing but set the executable name; this module does not
presently require use of a metaprogram.

**presently Windows-only.**

check it out
------------
```
cd examples\news
.\build
.\www
```
then visit [localhost:8000](localhost:8000).

roadmap
-------
 - template hotloading, including graceful, helpful failure
 - static file routing
 - improve HTTP request parsing & make it completely HTTP/1.0 compliant
 - some crazy experimental ideas for interactive tooling
 - expand template syntax
    - `%{IF cond}`, `%{ELSE}`, `%{ENDIF}` for simple control flow
    - `%{TEMPLATE template_name arg1 arg2}` to insert a template directly
 - caching?
 - HTTP 1.1
 - Gemini support
 - ...
