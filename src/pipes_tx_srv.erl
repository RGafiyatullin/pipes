-module (pipes_tx_srv).
-behaviour (gen_server).
-export([start_link/4]).
-export ([
		cast_start_rx/1,
		pass/2
	]).
-export ([
		init/1,
		handle_call/3,
		handle_cast/2,
		handle_info/2,
		terminate/2,
		code_change/3
	]).

-spec start_link( atom(), node(), atom(), term() ) -> {ok, pid()} | {error, term()}.
start_link( Name, RemoteNode, Mod, ModArg )
	when is_atom( Name ) andalso is_atom( RemoteNode ) andalso is_atom( Mod )
	-> gen_server:start_link( ?MODULE, {Name, RemoteNode, Mod, ModArg}, [] ).

-spec cast_start_rx( Tx :: pid() ) -> ok.
cast_start_rx( Tx ) -> gen_server:cast( Tx, start_rx ).

-type pass_error() :: rx_down.
-spec pass( Tx :: atom() | pid(), Msg :: term() ) -> ok | {error, pass_error()}.
pass( Tx, Msg ) when is_pid( Tx ) orelse is_atom( Tx ) -> gen_server:call( Tx, {pass, Msg}, infinity ).


%%% gen_server %%%

-record(s, {
		name :: atom(),
		node :: node(),

		% pobox :: pid(),

		rx_pid :: undefined | pid(),
		rx_mon_ref :: undefined | reference(),

		mod :: atom(),
		mod_arg :: term(),
		mod_s :: term()
	}).

init( {Name, RemoteNode, Mod, ModArg} ) ->
	case Mod:tx_init( ModArg ) of
		{ok, ModState0} ->
			% {PoboxSize, PoboxType} = run_opt_callback( Mod, tx_pobox_props, [ModState0], {128, queue} ),
			% {ok, Pobox} = pobox:start_link(
			% 	{local, Name}, self(),
			% 	PoboxSize, PoboxType, passive ),

			ok = cast_start_rx( self() ),
			ok = pipes_registry:register_tx( Name, self() ),
			register( Name, self() ),

			{ok, #s{
				name = Name,
				node = RemoteNode,

				% pobox = Pobox,

				mod = Mod,
				mod_arg = ModArg,
				mod_s = ModState0
			}};

		{error, InitError} -> {error, InitError}
	end.

handle_call( {pass, Msg}, GenReplyTo, State ) ->
	handle_call_pass( Msg, GenReplyTo, State );

handle_call( Req, GenReplyTo, State ) ->
	error_logger:warning_report([
		?MODULE, handle_call, unexpected,
		{req, Req}, {gen_reply_to, GenReplyTo} ]),
	{reply, badarg, State}.

handle_cast( start_rx, State ) -> handle_cast_start_rx( State );

handle_cast( Req, State ) ->
	error_logger:warning_report([
		?MODULE, handle_cast, unexpected, {req, Req} ]),
	{noreply, State}.

handle_info( {'DOWN', RxMonRef, process, RxPid, RxDownReason}, State = #s{ rx_pid = RxPid, rx_mon_ref = RxMonRef } ) ->
	handle_info_rx_down( RxDownReason, State );

handle_info( Req, State ) ->
	error_logger:warning_report([
		?MODULE, handle_info, unexpected, {req, Req} ]),
	{noreply, State}.

terminate( _Reason, _State ) -> ignore.
code_change( _OldVsn, State, _Extra ) -> {ok, State}.

%%% Handlers %%%
handle_cast_start_rx( State = #s{ rx_pid = DefinedPid, rx_mon_ref = DefinedMonRef } )
	when is_pid( DefinedPid ) andalso is_reference( DefinedMonRef )
->
	error_logger:warning_report([ ?MODULE, got_unexpected_start_rx, {rx_pid, DefinedPid}, {rx_mon_ref, DefinedMonRef} ]),
	{noreply, State};
handle_cast_start_rx(
	State = #s{
		rx_pid = undefined,
		rx_mon_ref = undefined,
		node = Node, 
		mod = Mod, 
		mod_s = ModS0, 
		name = PipeName, 
		mod_arg = ModArg
	} )
->
	case rpc:call( Node, pipes_mgr, rx_start, [ self(), PipeName, node(), Mod, ModArg ] ) of
		{badrpc, nodedown} -> handle_cast_start_rx_retry( 1000, State );
		{badrpc, {'EXIT', {noproc, {gen_server, call, [ pipex_mgr | _ ]}}}} -> handle_cast_start_rx_retry( 1000, State );
		{ok, RxPid} when is_pid( RxPid ) ->
			RxMonRef = erlang:monitor( process, RxPid ),
			error_logger:info_report([?MODULE, handle_cast_start_rx, {rx, RxPid}]),
			ModS1 = Mod:tx_on_rx_up( RxPid, ModS0 ),
			{noreply, State #s{ mod_s = ModS1, rx_pid = RxPid, rx_mon_ref = RxMonRef }};
		
		{error, RxStartError} ->
			error_logger:error_report([ ?MODULE, handle_cast_start_rx,
				{local_node, node()}, {remote_node, Node},
				{pipe_name, PipeName}, {mod, Mod}, {mod_arg, ModArg},
				{rx_start_error, RxStartError} ]),
			handle_cast_start_rx_retry( 10000, State );

		{badrpc, UnexpectedError} ->
			error_logger:error_report([ ?MODULE, handle_cast_start_rx,
				{local_node, node()}, {remote_node, Node},
				{pipe_name, PipeName}, {mod, Mod}, {mod_arg, ModArg},
				{badrpc, UnexpectedError} ]),
			handle_cast_start_rx_retry( 10000, State )
	end.

handle_info_rx_down( RxDownReason, State = #s{ mod_s = ModS0, mod = Mod } ) ->
	error_logger:warning_report([?MODULE, handle_info_rx_down,
			{rx_down_reason, RxDownReason} ]),
	ModS1 = Mod:tx_on_rx_dn( RxDownReason, ModS0 ),
	cast_start_rx( self() ),
	{noreply, State #s{ mod_s = ModS1, rx_pid = undefined, rx_mon_ref = undefined }}.

handle_call_pass( _Msg, _GenReplyTo, State = #s{ rx_pid = undefined } ) ->
	{reply, {error, rx_down}, State};
handle_call_pass( Msg, _GenReplyTo, State = #s{ rx_pid = Rx } ) when is_pid( Rx ) ->
	Rx ! {msg, self(), Msg},
	{reply, ok, State}.

%%% Internal %%%

handle_cast_start_rx_retry( In, State ) ->
	error_logger:info_report([?MODULE, handle_cast_start_rx_retry, {in, In}]),
	timer:apply_after( In, ?MODULE, cast_start_rx, [ self() ] ),
	{noreply, State}.

% run_opt_callback( Mod, Func, Args, Default ) ->
% 	Exports = 
% 		try Mod:module_info(exports)
% 		catch error:undef -> [] end,
% 	LookingFor = {Func, length(Args)},
% 	case [ found || LF <- Exports, LF == LookingFor ] of
% 		[] -> Default;
% 		[found] -> erlang:apply( Mod, Func, Args )
% 	end.




