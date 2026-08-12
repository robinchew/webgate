-module(home_battery).
-export([
    start_link/0
]).

get_datetime() ->
    {{Year, Month, Day}, {Hour, Min, _Sec}} = erlang:localtime(),
    %io_lib:format("~4..0w-~2..0w-~2..0w ~2..0w:~2..0w:~2..0w", 
    %  [Year, Month, Day, Hour, Min, Sec]).
    io_lib:format("~4..0w-~2..0w-~2..0w ~2..0w:~2..0w", 
      [Year, Month, Day, Hour, Min]).

read(RegisterId) ->
    try
        gen_server:call(modbus_tcp_client, {pdu, 247, 3, <<RegisterId:16, 1:16>>})
    of
        {error, not_connected} ->
            io:format("Read register ~p. NOT CONNECTED, trigger a restart~n", [RegisterId]),
            modbus_tcp_client:restart();
        {ok, Val} -> {ok, Val};
        Unexpected ->
            io:format("Unexpected ~p~n", [Unexpected])
    catch
        exit:{timeout, ErrMsg} ->
            io:format("Timeout caught: ~p~n", [ErrMsg]),
            timer:sleep(10000),
            modbus_tcp_client:restart(),
            caught_timeout;
        Err:Reason ->
            io:format("read error, ~p:~p~n", [Err, Reason]),
            {unexpected_catch, Err, Reason}
    end.

start_link() ->
    {ok, spawn_link(fun F() ->
        io:format("~s, ~p%, ~pW~n", [
            get_datetime(),
            case read(37007) of
                {ok, <<2, 0, Percent>>} -> Percent;
                _ -> "BATTERY LEVEL ERROR"
            end,
            case read(35171) of
                {ok, <<2, H, L>>} -> H * 256 + L;
                _ -> "HOUSEHOLD LOAD ERROR"
            end
        ]),
        timer:sleep(60000),
        F()
    end)}.
