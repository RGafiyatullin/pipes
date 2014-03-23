-module (pipes_app).
-behaviour (application).
-export ([start/2, stop/1]).

-spec start( normal, any() ) -> {ok, pid()}.
start( normal, _ ) -> pipes_sup:start_link().
-spec stop( any() ) -> ok.
stop( _ ) -> ok.
