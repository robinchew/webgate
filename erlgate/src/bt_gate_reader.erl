-module(bt_gate_reader).
-export([start_link/0]).

start_link() ->
    {ok, Port} = gen_tcp:connect({local, "/tmp/mydaemon.sock"}, 0, [
        binary,
        {active, false} % makes gen_tcp:recv blocking
    ]),

    % gen_tcp:send(Server, <<"trg\n">>),
    % link(Port),
    Pid = spawn_link(fun() -> loop(Port) end),
    {ok, Pid}.

loop(Port) ->
    ReturnAllBytes = 0,
    case gen_tcp:recv(Port, ReturnAllBytes) of
        {ok, <<"state:", GateState:6/binary, "\n">>} ->
            gate_state_server:update_state(GateState);
        {ok, Response} ->
            io:format("trl ~p~n", [user_tracker:lookup()]),
            io:format("socket Response: ~p~n", [Response]);
        Other ->
            io:format("socket Unhandled Response: ~p~n", [Other])
    end,
    loop(Port).
