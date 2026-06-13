-module(bt_gate_reader).
-export([start_link/0]).

-include_lib("kernel/include/logger.hrl").

start_link() ->
    {ok, Port} = gen_tcp:connect({local, "/tmp/mydaemon.sock"}, 0, [
        binary,
        {active, false} % active false you use gen_tcp:recv which blocks
        % {active, true }% active true does NOT use gen_tcp:recv, and makes use of receive/end, and supports disconnection message
    ]),

    % gen_tcp:send(Server, <<"trg\n">>),

    Pid = spawn_link(fun() ->
        link(Port),
        gate_state_server:update_state(<<"CONNEC">>),
        wait_to_send(Port)
    end),
    spawn(fun() ->
        link(Pid),
        wait_to_receive(Port, Pid)
    end),
    register(?MODULE, Pid),
    {ok, Pid}.

wait_to_send(Port) ->
    receive
        trigger -> gen_tcp:send(Port, <<"trg\n">>);
        Other -> ?LOG_ERROR("Unexpected message supposedly for blugate ~p~n", [Other])
    end,
    wait_to_send(Port).

wait_to_receive(Port, Pid) ->
    ReturnAllBytes = 0,
    case gen_tcp:recv(Port, ReturnAllBytes) of
        {ok, <<"state:", GateState:6/binary>>} ->
            ?LOG_NOTICE("Update state to: ~p", [GateState]),
            gate_state_server:update_state(GateState);
        {ok, Response} ->
            ?LOG_DEBUG("tracked users ~p", [user_tracker:lookup()]),
            ?LOG_ERROR("socket Response: ~p", [Response]);
        {error,closed} ->
            ?LOG_ERROR("Close error from UDS server. Expecting {error,enotconn} next.");
        {error,enotconn} ->
            gate_state_server:update_state(<<"RECONN">>),
            ?LOG_ERROR("Disconnected from UDS server. Kill to make supervisor respawn this."),
            exit(Pid, kill);
        Other ->
            ?LOG_ERROR("socket Unhandled Response: ~p", [Other])
    end,
    wait_to_receive(Port, Pid).
