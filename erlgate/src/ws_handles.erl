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
    ?LOG_ERROR("Triggeer"),
    {[], State};

on(_WsPid, Msg, State) ->
    ?LOG_DEBUG("Unhandled WS handle: ~p", [Msg]),
    {[], State}.
