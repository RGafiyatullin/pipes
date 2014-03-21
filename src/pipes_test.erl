-module (pipes_test).
-compile (export_all).

app_start() ->
	application:start( sasl ),
	application:start( pipes ),
	RemoteNode = 
		case node() of
			'one@aluminumcan' -> 'two@aluminumcan';
			'two@aluminumcan' -> 'one@aluminumcan'
		end,
	pipes_mgr:pipe_start( first_pipe, RemoteNode, undefined, undefined ),
	pipes_mgr:pipe_start( second_pipe, RemoteNode, undefined, undefined ),
	pipes_mgr:pipe_start( third_pipe, RemoteNode, undefined, undefined ).
