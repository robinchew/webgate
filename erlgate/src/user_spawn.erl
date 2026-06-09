-module(user_spawn).
-behaviour(gen_server).
-export([
    start_link/1,
    register_ws_pid/2,
    login/1,
    merge_state/2,
    get_ws_pids/1,
    state/1,
    start_approver_loop/3,
    set_email/2,
    set_websocket_pid/2,
    add_ticket/2
]).
-export([
    init/1,
    handle_cast/2,
    handle_call/3,
    handle_info/2,
    terminate/2
]).

-include_lib("kernel/include/logger.hrl").

% Public API

start_link(User) when is_map(User) ->
    %gen_server:start_link({local, Id}, ?MODULE, User, []).
    gen_server:start_link(?MODULE, User, []).

login(Pid) ->
    gen_server:call(Pid, login).

register_ws_pid(UserPid, WsPid) ->
    gen_server:cast(UserPid, {register_ws_pid, WsPid}).

set_email(Pid, Email) ->
    gen_server:cast(Pid, {set_email, Email}).

set_websocket_pid(Pid, WsPid) ->
    gen_server:cast(Pid, {set_websocket_pid, WsPid}).

get_ws_pids(Pid) ->
    gen_server:call(Pid, get_ws_pids).

state(Pid) ->
    gen_server:call(Pid, state).

merge_state(Pid, NewState) ->
    gen_server:cast(Pid, {merge_state, NewState}).

start_approver_loop(Pid, UrlName, QnaMap) ->
    gen_server:cast(Pid, {start_approver_loop, UrlName, QnaMap}).

add_ticket(Pid, TicketName) when is_pid(Pid)->
    gen_server:cast(Pid, {add_ticket, TicketName}).

% Private API

init(State) when is_map(State) ->
    % Only with the process_flag below, would the terminate function
    % execute when supervisor:terminate_child is used to terminate
    % this instance.
    %
    % Do NOT trap_exit though, or else errors produced from
    % from approver_loop:start_link/3 will be silenced.
    % process_flag(trap_exit, true),
    {ok, State}.

handle_cast({register_ws_pid, WsPid}, State) ->
    {noreply, nested:update(
        [ws_pids],
        fun(WsPids) -> WsPids ++ [WsPid] end,
        State)};

handle_cast({set_email, Email}, State) ->
    {noreply, State#{
        email => Email
    }};

handle_cast({set_access_token, Pid}, State) ->
    {noreply, State#{
        access_token => Pid
    }};

handle_cast({set_websocket_pid, Pid}, State) ->
    {noreply, State#{
        websocket_pid => Pid
    }};

handle_cast({add_ticket, Ticket}, State) ->
    {
        noreply,
        maps:update_with(
            tickets,
            fun(Tickets) -> [Ticket|Tickets] end,
            [],
            State)
    };

handle_cast({merge_state, NewState}, State) ->
    {noreply, maps:merge(State, NewState)};

handle_cast({start_approver_loop, UrlName, QnaMap}, State) ->
    #{access_token := AccessToken} = State,
    {ok, Pid} = approver_loop:start_link(AccessToken, UrlName, QnaMap),
    {noreply, State#{
        approver_pid => Pid
    }}.

handle_call(login, _From, State) ->
    Cookie = 1234,
    {reply, no_response, State#{cookie => Cookie}};

handle_call(get_ws_pids, _From, State = #{ ws_pids := WsPids}) ->
    {reply, WsPids, State};

handle_call(_, _From, State) ->
    {reply, State, State}.

handle_info({new_message, Msg}, State = #{ws_pids := WsPids}) ->
    lists:foreach(
        fun(WsPid) ->
            WsPid ! {refresh, Msg}
        end,
        WsPids),
    {noreply, State};

handle_info({'EXIT', _NonSelfPid, shutdown}, State) ->
    % https://stackoverflow.com/questions/39430574/unsupervised-gen-server-doesnt-call-terminate-when-it-receives-exit-signal
    {stop, shutdown, State};

handle_info({'DOWN', Ref, process, Pid, Reason}, State) ->
    ?LOG_ERROR("erly user DOWN ref ~p, pid ~p, ~p", [Ref, Pid, Reason]),
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(Reason, #{ uuid := Uuid }) ->
    % exit(Pid, shutdown) should trigger this function
    Pid = self(),
    user_tracker:unsubscribe(Uuid, Pid),
    ?LOG_NOTICE(#{
        reason => Reason,
        uuid => Uuid,
        self => Pid,
        notice => user_terminated
    }),
    ok.
