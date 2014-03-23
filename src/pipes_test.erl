-module (pipes_test).
-behaviour (gen_pipe).
-export ([
		tx_init/1,
		tx_on_rx_up/2,
		tx_on_rx_dn/2
	]).
-compile (export_all).

app_start() ->
	application:start( sasl ),
	application:start( pipes ),
	RemoteNode = 
		case node() of
			'one@aluminumcan' -> 'two@aluminumcan';
			'two@aluminumcan' -> 'one@aluminumcan'
		end,

	pipes_mgr:tx_start( first_pipe, RemoteNode, ?MODULE, undefined ),
	pipes_mgr:tx_start( second_pipe, RemoteNode, ?MODULE, undefined ),
	pipes_mgr:tx_start( third_pipe, RemoteNode, ?MODULE, undefined ),

	{ok, RemoteNode}.

tx_init( undefined ) ->
	{ok, undefined}.

tx_on_rx_up( _RxPid, S ) -> S.
tx_on_rx_dn( _RxDownReason, S ) -> S.

% tx_pobox_props( _ ) -> { 128, queue }.