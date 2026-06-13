-module(bt_gate_reader).
-export([start_link/0]).

start_link() ->
    {ok, Port} = gen_tcp:connect({local, "/tmp/mydaemon.sock"}, 0, [
        binary,
        {active, false} % makes gen_tcp:recv blocking
    ]),

    % gen_tcp:send(Server, <<"trg\n">>),
    % link(Port),
    Pid = spawn_link(fun() ->
        spawn_link(fun() -> wait_to_send(Port) end),
        wait_to_receive(Port)
    end),
    {ok, Pid}.

wait_to_send(Port) ->
    receive
        trigger -> gen_tcp:send(Port, <<"trg\n">>);
        Other -> io:format("Unexpected message supposedly for blugate ~p~n", [Other])
    end,
    wait_to_send(Port).

wait_to_receive(Port) ->
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
    wait_to_receive(Port).
