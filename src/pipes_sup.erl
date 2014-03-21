-module (pipes_sup).
-behaviour (supervisor).
-export ([start_link/0, start_link_rx_sup/0, start_link_tx_sup/0]).
-export ([tx_start_child/4]).
-export ([init/1]).

-define( sup, ?MODULE ).
-define( tx_sup, pipes_tx_sup ).
-define( rx_sup, pipes_rx_sup ).

%%% API %%%

start_link() -> supervisor:start_link( {local, ?MODULE}, ?MODULE, {} ).
start_link_rx_sup() -> supervisor:start_link( {local, ?rx_sup}, ?MODULE, {rx} ).
start_link_tx_sup() -> supervisor:start_link( {local, ?tx_sup}, ?MODULE, {tx} ).

-type sup_start_child_error() :: term().
-spec tx_start_child( atom(), node(), atom(), term() ) -> {ok, pid()} | {error, sup_start_child_error()}.
tx_start_child( Name, RemoteNode, Mod, ModArg ) ->
	supervisor:start_child( ?tx_sup, { Name,
		{ pipes_tx_srv, start_link, [ Name, RemoteNode, Mod, ModArg ] }, 
		permanent, 1000, worker, [ pipes_tx_srv ] } ).


%%% supervisor %%%

init( {} ) -> init_sup();
init( {rx} ) -> init_rx_sup();
init( {tx} ) -> init_tx_sup().

init_sup() ->
	{ok, {
		{one_for_all, 0, 1},
		[
			{rx_sup, {?MODULE, start_link_rx_sup, []}, permanent, infinity, supervisor, [ ?MODULE ]},
			{tx_sup, {?MODULE, start_link_tx_sup, []}, permanent, infinity, supervisor, [ ?MODULE ]},
			{mgr, {pipes_mgr, start_link, []}, permanent, 1000, worker, [ pipes_mgr ]}
		]
	}}.

init_tx_sup() -> {ok, { {one_for_one, 3, 10}, [] }}.
init_rx_sup() -> {ok, { {one_for_one, 3, 10}, [] }}.
