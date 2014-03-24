-module (pipes_rx_srv).
-behaviour (gen_server).
-export([start_link/5]).
-export ([
		init/1,
		handle_call/3,
		handle_cast/2,
		handle_info/2,
		terminate/2,
		code_change/3
	]).

-spec start_link( pid(), atom(), node(), atom(), term() ) -> {ok, pid()} | {error, term()}.
start_link( TxPid, Name, RemoteNode, Mod, ModArg )
	when is_pid(TxPid) andalso is_atom( Name ) andalso is_atom( RemoteNode ) andalso is_atom( Mod )
	-> gen_server:start_link( ?MODULE, {TxPid, Name, RemoteNode, Mod, ModArg}, [] ).

%%% gen_server %%%

-record(s, {
		tx_pid :: pid(),
		tx_mon_ref :: reference(),

		mod :: atom(),
		mod_s :: term()
	}).

init( {TxPid, _Name, _RemoteNode, Mod, ModArg} ) ->
	TxMonRef = erlang:monitor( process, TxPid ),
	case Mod:rx_init( ModArg ) of
		{ok, ModS0} ->
			{ok, #s{
				tx_pid = TxPid,
				tx_mon_ref = TxMonRef,

				mod = Mod,
				mod_s = ModS0
			}};

		{error, Error} -> {error, Error}
	end.

handle_call( Req, GenReplyTo, State ) ->
	error_logger:warning_report([
		?MODULE, handle_call, unexpected,
		{req, Req}, {gen_reply_to, GenReplyTo} ]),
	{reply, badarg, State}.

handle_cast( Req, State ) ->
	error_logger:warning_report([
		?MODULE, handle_cast, unexpected, {req, Req} ]),
	{noreply, State}.

handle_info( {msg, TxPid, Msg}, State = #s{ tx_pid = TxPid } ) ->
	handle_info_msg( Msg, State );

handle_info(
	{'DOWN', TxMonRef, process, TxPid, Reason},
	State = #s{ tx_pid = TxPid, tx_mon_ref = TxMonRef }
) ->
	case Reason of
		normal -> {stop, normal, State};
		shutdown -> {stop, shutdown, State};
		_ -> {stop, {tx_down, Reason}, State}
	end;

handle_info( Req, State ) ->
	error_logger:warning_report([
		?MODULE, handle_info, unexpected, {req, Req} ]),
	{noreply, State}.

terminate( _Reason, _State ) -> ignore.
code_change( _OldVsn, State, _Extra ) -> {ok, State}.

%%% Handlers %%%

handle_info_msg( Msg, State = #s{ mod = Mod, mod_s = ModS0 } ) ->
	ModS1 = Mod:rx_msg_in( Msg, ModS0 ),
	{noreply, State #s{ mod_s = ModS1 }}.

%%% Internal %%%
