-module (pipes_registry).
-export ([init/0]).
-export ([register_tx/2, unregister_tx/2, resolve_tx/1]).

-define( registry, ?MODULE ).

init() ->
	?registry = ets:new( ?registry, [ named_table, set, public ] ),
	ok.

register_tx( Name, Pid ) when is_atom( Name ) andalso is_pid( Pid ) ->
	true = ets:insert( ?registry, { {tx,Name}, Pid } ),
	ok.

unregister_tx( Name, Pid ) when is_atom( Name ) andalso is_pid( Pid ) ->
	ets:delete_object( ?registry, { {tx,Name}, Pid } ),
	ok.


resolve_tx( Name ) when is_atom( Name ) ->
	case ets:lookup( ?registry, {tx,Name} ) of
		[] -> undefined;
		[{_, Pid}] when is_pid(Pid) -> Pid
	end.

