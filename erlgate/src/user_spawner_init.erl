-module(user_spawner_init).
-export([start_children/0]).

start([User|Users]) ->
    #{
        <<"uuid">> := Uuid,
        <<"email">> := Email,
        <<"meetup_refresh_token">> := RefreshToken
    } = User,
    {ok, _Pid} = user_spawner:start_child(#{
        uuid => Uuid,
        email => Email,
        refresh_token => RefreshToken
    }),
    start(Users);
start([]) ->
    complete.

start_children() ->
    Pid = spawn_link(fun() -> nothing end),
    Users = query:get_rows([<<"paid_users">>, #{}]),
    start(Users),
    {ok, Pid}.
