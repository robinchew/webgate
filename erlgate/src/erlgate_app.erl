-module(erlgate_app).
-behaviour(application).

-export([start/2]).
-export([stop/1]).

start(_Type, _Args) ->
    ok = inets:start(),
    Dispatch = cowboy_router:compile([
        {'_', [
            {"/", cowboy_static, {priv_file, erlgate, "index.html"}},
            {"/:subscriber_uuid", ws_handler, #{}}
        ]}
    ]),
    {ok, _} = cowboy:start_clear(
        server_listener,
        [{port, list_to_integer(env:get("SERVER_PORT"))}],
        #{env => #{dispatch => Dispatch}}),

	erlgate_sup:start_link().

stop(_State) ->
	ok.
