-module (pipes_mgr).
-behaviour (gen_server).
-export ([start_link/0]).
-export ([tx_start/4, tx_stop/1]).
-export ([rx_start/5]).
-export ([
		init/1,
		handle_call/3,
		handle_cast/2,
		handle_info/2,
		terminate/2,
		code_change/3
	]).

%%% API %%%
-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() -> gen_server:start_link( {local, ?MODULE}, ?MODULE, {}, [] ).

-type sup_start_child_error() :: term().
-type pipe_start_error() :: already_started | sup_start_child_error().
-type sup_stop_child_error() :: term().
-type pipe_stop_error() :: not_found | sup_stop_child_error().

-spec tx_start( atom(), node(), atom(), term() ) -> {ok, pid()} | {error, pipe_start_error()}.
tx_start( Name, RemoteNode, Mod, ModArg )
	when is_atom( Name ) andalso is_atom( RemoteNode ) andalso is_atom( Mod )
	-> gen_server:call( ?MODULE, {tx_start, Name, RemoteNode, Mod, ModArg} ).

-spec tx_stop( atom() ) -> ok | {error, pipe_stop_error()}.
tx_stop( Name ) when is_atom( Name ) -> gen_server:call( ?MODULE, {tx_stop, Name} ).

-spec rx_start( pid(), atom(), node(), atom(), term() ) -> {ok, pid()} | {error, pipe_start_error()}.
rx_start( TxPid, Name, RemoteNode, Mod, ModArg )
	when is_pid(TxPid) andalso is_atom( Name ) andalso is_atom( RemoteNode ) andalso is_atom( Mod )
	-> gen_server:call( ?MODULE, {rx_start, TxPid, Name, RemoteNode, Mod, ModArg} ).

%%% gen_server %%%

-record(pipe, {
		name :: atom(),
		node :: node(),
		tx_pid :: pid(),
		tx_mon_ref :: reference()
	}).
-record(s, {
		pipes = [ #pipe{} ]
	}).

init( {} ) ->
	ok = pipes_registry:init(),
	{ok, #s{}}.

handle_call( {tx_start, Name, RemoteNode, Mod, ModArg}, GenReplyTo, State )
	when is_atom(Name) andalso is_atom( RemoteNode ) andalso is_atom( Mod )
	-> handle_call_tx_start( Name, RemoteNode, Mod, ModArg, GenReplyTo, State );

handle_call( {tx_stop, Name}, GenReplyTo, State ) when is_atom( Name ) ->
	handle_call_tx_stop( Name, GenReplyTo, State );

handle_call( {rx_start, TxPid, Name, RemoteNode, Mod, ModArg}, GenReplyTo, State )
	when is_pid(TxPid) andalso is_atom(Name) andalso is_atom( RemoteNode ) andalso is_atom( Mod )
	-> handle_call_rx_start( TxPid, Name, RemoteNode, Mod, ModArg, GenReplyTo, State );

handle_call( Req, GenReplyTo, State ) ->
	error_logger:warning_report([
		?MODULE, handle_call, unexpected,
		{req, Req}, {gen_reply_to, GenReplyTo} ]),
	{reply, badarg, State}.

handle_cast( Req, State ) ->
	error_logger:warning_report([
		?MODULE, handle_cast, unexpected, {req, Req} ]),
	{noreply, State}.

handle_info( {'DOWN', MonRef, process, Pid, DownReason}, State) ->
	handle_info_down( MonRef, Pid, DownReason, State );

handle_info( Req, State ) ->
	error_logger:warning_report([
		?MODULE, handle_info, unexpected, {req, Req} ]),
	{noreply, State}.

terminate( _Reason, _State ) -> ignore.
code_change( _OldVsn, State, _Extra ) -> {ok, State}.

%%% Handlers %%%

handle_call_tx_start( PipeName, RemoteNode, Mod, ModArg, _GenReplyTo, State = #s{ pipes = Ps0 } )  ->
	case lists:keyfind( PipeName, #pipe.name, Ps0 ) of
		#pipe{} -> {reply, {error, already_started}, State};
		false ->
			case pipes_sup:tx_start_child( PipeName, RemoteNode, Mod, ModArg ) of
				{ok, TxPid} ->
					TxMonRef = erlang:monitor( process, TxPid ),
					Pipe = #pipe{ name = PipeName, node = RemoteNode, tx_pid = TxPid, tx_mon_ref = TxMonRef },
					Ps1 = [ Pipe | Ps0 ],
					{reply, {ok, TxPid}, State #s{ pipes = Ps1 }};
				{error, StartError} ->
					{reply, {error, StartError}, State}
			end
	end.

handle_call_tx_stop( PipeName, _GenReplyTo, State = #s{ pipes = Ps0 } ) ->
	case lists:keyfind( PipeName, #pipe.name, Ps0 ) of
		false -> {reply, {error, not_found}, State};
		#pipe{ tx_mon_ref = TxMonRef } ->
			_ = erlang:demonitor( TxMonRef, [flush] ),
			ok = pipes_sup:tx_terminate_and_delete_child( PipeName ),
			{reply, ok, State}
	end.

handle_call_rx_start( TxPid, Name, RemoteNode, Mod, ModArg, _GenReplyTo, State ) ->
	case pipes_sup:rx_start_child( TxPid, Name, RemoteNode, Mod, ModArg ) of
		{ok, RxPid} -> {reply, {ok, RxPid}, State};
		{error, StartError} ->
			error_logger:error_report([ ?MODULE, handle_call_rx_start,
				{name, Name}, {remote_node, RemoteNode},
				{mod, Mod}, {mod_arg, ModArg},
				{rx_start_error, StartError} ]),
			{reply, {error, StartError}, State}
	end.

handle_info_down( MonRef, Pid, DownReason, State = #s{ pipes = Ps0 } ) ->
	case lists:keyfind( Pid, #pipe.tx_pid, Ps0 ) of
		false ->
			error_logger:warning_report([?MODULE, handle_info_down,
				unexpected_down_msg, {mon_ref, MonRef}, {pid, Pid}, {reason, DownReason}]),
			{noreply, State};
		OldPipe = #pipe{ name = PipeName } ->
			ok = pipes_registry:unregister_tx( PipeName, Pid ),
			[ RestartedPid ] = pipes_sup:tx_which_child( PipeName ),
			RestartedMonRef = erlang:monitor( process, RestartedPid ),
			NewPipe = OldPipe #pipe{ tx_pid = RestartedPid, tx_mon_ref = RestartedMonRef },
			Ps1 = [ NewPipe | lists:keydelete( PipeName, #pipe.name, Ps0 ) ],
			{noreply, State #s{ pipes = Ps1 }}
	end.


%%% Internal %%%
