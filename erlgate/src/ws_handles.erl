-module(ws_handles).
-export([
    on/3
]).
-include_lib("kernel/include/logger.hrl").

on(_WsPid, [<<"ping">>], State) ->
    {[
        <<"pong">>
    ], State};

on(_WsPid, [<<"trigger">>], State) ->
    whereis(bt_gate_reader) ! trigger,
    ?LOG_NOTICE("Triggered gate"),
    {[], State};

on(_WsPid, Msg, State) ->
    ?LOG_ERROR("Unhandled WS handle: ~p", [Msg]),
    {[], State}.
