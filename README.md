# wfw
web framework for a new language

for a demo, run `jai wfw.jai;.\wfw.exe`, then try the following in your browser:

 - http://localhost:8000
 - http://localhost:8000/this_path_will_404
 - http://localhost:8000/post/108
 - http://localhost:8000/post/108/edit
 - http://localhost:8000/user/adam

----

## Features
 - templates (simple)
 - routing (with parameters!)
 - HTTP server (simple, unthreaded, terrible!)

## TODO
 - ~~add HTTP server~~
 - check for memory leaks
 - improve stuff
 - encapsulate everything in module/file scopes
 - make sample website
