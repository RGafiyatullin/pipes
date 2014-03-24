-module (gen_pipe).

-type arg() :: term().
-type state() :: term().
-type init_error() :: term().

-callback tx_init( arg() ) -> {ok, state()} | {error, init_error()}.
-callback tx_on_rx_up( RxPid :: pid(), state() ) -> state().
-callback tx_on_rx_dn( RxDownReason :: term(), state() ) -> state().

-callback rx_init( arg() ) -> {ok, state()} | {error, init_error()}.
-callback rx_msg_in( MsgIn :: term(), state() ) -> state().

% -optional_callback tx_pobox_props( state() ) -> { PoboxSize :: pos_integer(), PoboxType :: queue | stack }.

