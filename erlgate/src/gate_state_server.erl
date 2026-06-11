-module(gate_state_server).
-behaviour(gen_server).
-export([
    start_link/0,
    get_state/0,
    update_state/1
]).

-export([init/1]).
-export([handle_cast/2]).
-export([handle_call/3]).

% Public API

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, no_state, []).

get_state() ->
    gen_server:call(?MODULE, get_state).

update_state(NewState) ->
    {_, WsPids} = lists:mapfoldl(
        fun(UserPid, AllWsPids) ->
            WsPids = user_spawn:get_ws_pids(UserPid), {WsPids, AllWsPids ++ WsPids} end,
        [],
        maps:values(user_tracker:lookup())),
    lists:map(
        fun(WsPid) ->
            WsPid ! {gate_state, NewState}
        end,
        WsPids),
    gen_server:call(?MODULE, {update_state, NewState}).

% Server API

init(State) ->
    {ok, State}.

handle_cast({update_state, NewState}, _State) ->
    {noreply, NewState};

handle_cast(_, State) ->
    {noreply, State}.

handle_call(get_state, _From, State) ->
    {reply, State, State};

handle_call(_, _From, State) ->
    {reply, nil, State}.
