-module (pipes_app).
-behaviour (application).
-export ([start/2, stop/1]).
start( normal, _ ) -> pipes_sup:start_link().
stop( _ ) -> ok.
