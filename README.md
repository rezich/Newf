Newf
====
check [the example](examples/dorknews) to see how it works.

**presently Windows-only.**


check it out
------------

```powershell
# from this directory:
cd .. # go up a level
git clone https://github.com/rezich/SQLite.git # required for the example
cd Newf\examples\dorknews
jai dorknews.jai
.\bin\www
```
then visit [localhost:8000](localhost:8000).


short-term roadmap
------------------
 - add ability for select_from to fetch nested models
 - begin work on migration system


long-term roadmap
-----------------
 - template hotloading, including graceful, helpful failure
 - static file routing
 - improve HTTP request parsing & make it completely HTTP/1.0 compliant
 - some crazy experimental ideas for interactive tooling
 - expand template syntax
    - `%{IF cond}`, `%{ELSE}`, `%{ENDIF}` for simple control flow
    - `%{TEMPLATE template_name arg1 arg2}` to insert a template directly
 - HTTP 1.1
 - linux support
 - Gemini support
 - ...
