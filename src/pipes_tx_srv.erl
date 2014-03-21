-module (pipes_tx_srv).

-export([start_link/4, enter_loop/4]).

-spec start_link( atom(), node(), atom(), term() ) -> {ok, pid()} | {error, term()}.
start_link( Name, RemoteNode, Mod, ModArg ) -> proc_lib:start_link( ?MODULE, enter_loop, [ Name, RemoteNode, Mod, ModArg ] ).

enter_loop( Name, RemoteNode, Mod, ModArg ) ->
	erlang:register( Name, self() ),
	error_logger:info_report([ ?MODULE, enter_loop,
		{name, Name}, {node, RemoteNode}, {mod, Mod}, {mod_arg, ModArg} ]),
	proc_lib:init_ack({ok, self()}),
	loop().

loop() ->
	receive _ -> loop() end.
