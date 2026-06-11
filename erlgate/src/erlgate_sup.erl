-module(erlgate_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
	supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
	Procs = [
        #{
            id => user_pool_id,
            start => {user_pool, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => dynamic
        },
        #{
            id => bt_gate_reader_id,
            start => {bt_gate_reader, start_link, []},
            restart => permanent,
            shutdown => 5000
            % type => worker,
            % modules => dynamic
        },
        #{
            id => gate_state_server_id,
            start => {gate_state_server, start_link, []},
            restart => permanent,
            shutdown => 5000
            % type => worker,
            % modules => dynamic
        }
    ],
	{ok, {{one_for_one, 1, 5}, Procs}}.
