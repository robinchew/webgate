-module(error_pusher).
-behaviour(gen_server).

%% API
-export([
    start_link/0,
    notify/2
]).

%% Callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(ONE_MINUTE, 60000).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

notify(Title, Content) ->
    gen_server:call(?MODULE, {notify, Title, Content}).

%% --- Server Callbacks ---

init([]) ->
    {ok, #{}}. %% Initial State is an empty Map

handle_call({notify, Title, Content}, _From, Map) ->
    NewMap = case Map of
        #{ {Title, Content} := _Pid } ->
            Map;
        _ ->
            Pid = spawn(fun() ->
                httpc:request(
                    post,
                    {
                        env:get("NTFY_TOPIC"),
                        [{"priority", "high"}, {"title", Title}],
                        "text/plain",
                        Content
                    },
                    [],
                    []),

                % Block for a minute before ending the process
                % To stop duplicate process with the same Title and Content
                % to be created
                receive
                after ?ONE_MINUTE ->
                    exit(normal) % This is not necessary, but just FYI
                end
            end),
            erlang:monitor(process, Pid),
            %% Store both directions for easy cleanup
            Map#{
                Pid => {Title, Content},
                {Title, Content} => Pid
            }
    end,
    {reply, ok, NewMap}.

handle_cast(_Msg, State) -> {noreply, State}.

handle_info({'DOWN', _Ref, process, Pid, _Reason}, Map) ->
    case maps:find(Pid, Map) of
        {ok, Id} ->
            NewMap = maps:remove(Pid, maps:remove(Id, Map)),
            {noreply, NewMap};
        error ->
            {noreply, Map}
    end.
