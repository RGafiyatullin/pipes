-module (pipes).
-export ([start_pipe/4, stop_pipe/1, pass/2]).

start_pipe( Name, Node, Mod, ModArg ) -> pipes_mgr:tx_start( Name, Node, Mod, ModArg ).
stop_pipe( Name ) -> pipes_mgr:tx_stop( Name ).
pass( Pipe, Msg ) -> pipes_tx_srv:pass( Pipe, Msg ).