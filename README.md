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


TODO
====
 - caching on routes!
 - don't require that your website creates a new Session for every single user, because that's crazytown
 - better template loading/unloading, so we can have...
 - template hotloading, including graceful, helpful failure
 - static file routing
 - improve HTTP request parsing & make it completely HTTP/1.0 compliant
 - some crazy experimental ideas for interactive tooling
 - HTTP 1.1
 - linux support
 - Gemini support
 - ...
