-module(bt_gate_reader).
-export([start_link/0]).

-include_lib("kernel/include/logger.hrl").

start_link() ->
    {ok, Port} = gen_tcp:connect({local, "/tmp/mydaemon.sock"}, 0, [
        binary,
        {active, false} % makes gen_tcp:recv blocking
    ]),

    % gen_tcp:send(Server, <<"trg\n">>),
    % link(Port),
    spawn_link(fun() ->
        wait_to_receive(Port)
    end),
    Pid = spawn_link(fun() -> wait_to_send(Port) end),
    register(?MODULE, Pid),
    {ok, Pid}.

wait_to_send(Port) ->
    receive
        trigger -> gen_tcp:send(Port, <<"trg\n">>);
        Other -> ?LOG_ERROR("Unexpected message supposedly for blugate ~p~n", [Other])
    end,
    wait_to_send(Port).

wait_to_receive(Port) ->
    ReturnAllBytes = 0,
    case gen_tcp:recv(Port, ReturnAllBytes) of
        {ok, <<"state:", GateState:6/binary, "\n">>} ->
            gate_state_server:update_state(GateState);
        {ok, Response} ->
            ?LOG_DEBUG("trl ~p~n", [user_tracker:lookup()]),
            ?LOG_ERROR("socket Response: ~p~n", [Response]);
        Other ->
            ?LOG_ERROR("socket Unhandled Response: ~p~n", [Other])
    end,
    wait_to_receive(Port).
