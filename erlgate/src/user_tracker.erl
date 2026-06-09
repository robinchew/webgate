-module(user_tracker).
-behaviour(gen_server).
-export([
    start_link/0,
    get_pid/1,
    authenticate/2,
    subscribe/2,
    unsubscribe/2
]).
-export([lookup/0]).

-export([init/1]).
-export([handle_cast/2]).
-export([handle_call/3]).

% Public API

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, #{
        users => #{}
    }, []).

get_pid(Uuid) ->
    gen_server:call(?MODULE, {get_pid, Uuid}).

subscribe(Uuid, Pid) when is_pid(Pid) ->
    gen_server:cast(?MODULE, {subscribe, Uuid, Pid}).

unsubscribe(Uuid, Pid) when is_pid(Pid) ->
    gen_server:cast(?MODULE, {unsubscribe, Uuid, Pid}).

lookup() ->
    gen_server:call(?MODULE, lookup).

authenticate(Email, Password) ->
    gen_server:call(?MODULE, {authenticate, Email, Password}).

% Server API

init(State) ->
    {ok, State}.

handle_cast({subscribe, Uuid, Pid}, State) ->
    #{users := Users} = State,
    {noreply, State#{
        users => Users#{
            Uuid => Pid
        }
    }};

handle_cast({unsubscribe, Uuid, Pid}, State) ->
    #{users := Users} = State,
    {OldPid, NewUsers} = maps:take(Uuid, Users),
    OldPid = Pid,
    {noreply, State#{
        users => NewUsers
    }}.

handle_call({get_pid, Uuid}, _From, State) ->
    #{ users := Users } = State,
    {ok, Pid} = maps:find(Uuid, Users),
    {reply, Pid, State};

handle_call({authenticate, Email, PlainTextPassword}, _From, State) ->
    #{rows := Rows} = query:query("
        SELECT uuid, password
        FROM db_person
        WHERE email=$1",
        [Email]),

    Found = case Rows of
        [#{<<"uuid">> := Uuid, <<"password">> := Hash}] ->
            case erlpass:match(PlainTextPassword, Hash) of
                true -> {match, Uuid};
                false -> {error, no_password_match}
            end;
        _ -> {error, no_user}
    end,
    Result = case Found of
        {match, UserUuid} -> {ok, UserUuid};
        {error, Error} -> {error, Error}
    end,
    {reply, Result, State};

handle_call(lookup, _From, State) ->
    #{ users := Users } = State,
    {reply, Users, State}.
