-module (pipes_mgr).
-behaviour (gen_server).
-export ([start_link/0]).
-export ([pipe_start/4]).
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
-spec pipe_start( atom(), node(), atom(), term() ) -> {ok, pid()} | {error, pipe_start_error()}.
pipe_start( Name, RemoteNode, Mod, ModArg )
	when is_atom( Name ) andalso is_atom( RemoteNode ) andalso is_atom( Mod )
	-> gen_server:call( ?MODULE, {pipe_start, Name, RemoteNode, Mod, ModArg} ).

%%% gen_server %%%

-record(pipe, {
		name :: atom(),
		node :: node(),
		tx_pid :: pid()
	}).
-record(s, {
		pipes = dict:new() :: dict() %% PipeName :: atom() -> #pipe{}
	}).

init( {} ) ->
	{ok, #s{}}.

handle_call( {pipe_start, Name, RemoteNode, Mod, ModArg}, GenReplyTo, State )
	when is_atom(Name) andalso is_atom( RemoteNode ) andalso is_atom( Mod )
	-> handle_call_pipe_start( Name, RemoteNode, Mod, ModArg, GenReplyTo, State );

handle_call( Req, GenReplyTo, State ) ->
	error_logger:warning_report([
		?MODULE, handle_call, unexpected,
		{req, Req}, {gen_reply_to, GenReplyTo} ]),
	{reply, badarg, State}.

handle_cast( Req, State ) ->
	error_logger:warning_report([
		?MODULE, handle_cast, unexpected, {req, Req} ]),
	{reply, badarg, State}.

handle_info( Req, State ) ->
	error_logger:warning_report([
		?MODULE, handle_info, unexpected, {req, Req} ]),
	{reply, badarg, State}.

terminate( _Reason, _State ) -> ignore.
code_change( _OldVsn, State, _Extra ) -> {ok, State}.

%%% Internal %%%


handle_call_pipe_start( PipeName, RemoteNode, Mod, ModArg, _GenReplyTo, State = #s{ pipes = Ps0 } )  ->
	case dict:find( PipeName, Ps0 ) of
		{ok, #pipe{}} -> {reply, {error, already_started}, State};
		error ->
			case pipes_sup:tx_start_child( PipeName, RemoteNode, Mod, ModArg ) of
				{ok, TxPid} ->
					Pipe = #pipe{ name = PipeName, node = RemoteNode, tx_pid = TxPid },
					Ps1 = dict:store( PipeName, Pipe, Ps0 ),
					{reply, {ok, TxPid}, State #s{ pipes = Ps1 }};
				{error, StartError} ->
					{reply, {error, StartError}, State}
			end
	end.
