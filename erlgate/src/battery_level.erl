-module(battery_level).
-export([
    start_link/0
]).

get_datetime() ->
    {{Year, Month, Day}, {Hour, Min, _Sec}} = erlang:localtime(),
    %io_lib:format("~4..0w-~2..0w-~2..0w ~2..0w:~2..0w:~2..0w", 
    %  [Year, Month, Day, Hour, Min, Sec]).
    io_lib:format("~4..0w-~2..0w-~2..0w ~2..0w:~2..0w", 
      [Year, Month, Day, Hour, Min]).

call(RegisterId) ->
    case gen_server:call(modbus_tcp_client, {pdu, 247, 3, <<RegisterId:16, 1:16>>}) of
        {error, not_connected} ->
            io:format("Read register ~p. NOT CONNECTED, trigger a restart~n", [RegisterId]),
            modbus_tcp_client:restart();
        {ok, Val} -> {ok, Val};
        Unexpected ->
            io:format("Unexpected ~p~n", [Unexpected])
    end.

start_link() ->
    {ok, spawn_link(fun F() ->
        case call(37007) of
            {ok, <<2, 0, Percent>>} ->
                io:format("~s, ~p%~n", [get_datetime(), Percent]);
            _ -> pass
        end,
        case call(35171) of
            {ok, <<2, H, L>>} ->
                io:format("~s, ~pW~n", [get_datetime(), H * 256 + L]);
            _ -> pass
        end,
        timer:sleep(60000),
        F()
    end)}.
