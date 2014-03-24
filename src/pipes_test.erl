-module (pipes_test).
-behaviour (gen_pipe).
-export ([
		tx_init/1,
		tx_on_rx_up/2,
		tx_on_rx_dn/2
	]).
-export ([
		rx_init/1,
		rx_msg_in/2
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

	{ok, _} = pipes_mgr:tx_start( first_pipe, RemoteNode, ?MODULE, undefined ),
	{ok, _} = pipes_mgr:tx_start( second_pipe, RemoteNode, ?MODULE, undefined ),
	{ok, _} = pipes_mgr:tx_start( third_pipe, RemoteNode, ?MODULE, undefined ),

	{ok, RemoteNode}.

load( P ) ->
	timer:tc( fun() ->
		lists:foreach(
			fun( Idx ) ->
				Msg = {Idx, test_payload()},
				ok = pipes_tx_srv:pass( P, Msg )
			end,
			lists:seq(1, 100000) ) end).

tx_init( undefined ) -> {ok, undefined}.
tx_on_rx_up( _RxPid, S ) -> S.
tx_on_rx_dn( _RxDownReason, S ) -> S.

% tx_pobox_props( _ ) -> { 128, queue }.

rx_init( undefined ) -> {ok, undefined}.
rx_msg_in( _, undefined ) -> undefined.

test_payload() ->
	[
		{xe, <<"serasdf">>, <<"asdfdsfasdf">>, [], [
			{xe, <<"serasdf">>, <<"asdfdsfasdf">>, [], []},
			{xe, <<"serasdf">>, <<"asdfdsfasdf">>, [], []},
			{xe, <<"serasdf">>, <<"asdfdsfasdf">>, [], []}
		]},
		{xe, <<"serasdf">>, <<"asdfdsfasdf">>, [], [
			{xe, <<"serasdf">>, <<"asdfdsfasdf">>, [], []},
			{xe, <<"serasdf">>, <<"asdfdsfasdf">>, [], []},
			{xe, <<"serasdf">>, <<"asdfdsfasdf">>, [], []}
		]},
		{xe, <<"serasdf">>, <<"asdfdsfasdf">>, [], [
			{xe, <<"serasdf">>, <<"asdfdsfasdf">>, [], []},
			{xe, <<"serasdf">>, <<"asdfdsfasdf">>, [], []},
			{xe, <<"serasdf">>, <<"asdfdsfasdf">>, [], []}
		]},
		{xe, <<"serasdf">>, <<"asdfdsfasdf">>, [], [
			{xe, <<"serasdf">>, <<"asdfdsfasdf">>, [], []},
			{xe, <<"serasdf">>, <<"asdfdsfasdf">>, [], []},
			{xe, <<"serasdf">>, <<"asdfdsfasdf">>, [], []}
		]}
	].
