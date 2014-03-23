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
		tx_mon_ref :: reference()
	}).

init( {TxPid, _Name, _RemoteNode, _Mod, _ModArg} ) ->
	TxMonRef = erlang:monitor( process, TxPid ),
	{ok, #s{
		tx_pid = TxPid,
		tx_mon_ref = TxMonRef
	}}.

handle_call( Req, GenReplyTo, State ) ->
	error_logger:warning_report([
		?MODULE, handle_call, unexpected,
		{req, Req}, {gen_reply_to, GenReplyTo} ]),
	{reply, badarg, State}.

handle_cast( Req, State ) ->
	error_logger:warning_report([
		?MODULE, handle_cast, unexpected, {req, Req} ]),
	{noreply, State}.

handle_info( {'DOWN', TxMonRef, process, TxPid, _Reason}, State = #s{ tx_pid = TxPid, tx_mon_ref = TxMonRef } ) ->
	{stop, tx_down, State};

handle_info( Req, State ) ->
	error_logger:warning_report([
		?MODULE, handle_info, unexpected, {req, Req} ]),
	{noreply, State}.

terminate( _Reason, _State ) -> ignore.
code_change( _OldVsn, State, _Extra ) -> {ok, State}.

%%% Handlers %%%

%%% Internal %%%
