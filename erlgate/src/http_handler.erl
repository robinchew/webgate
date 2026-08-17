-module(http_handler).
-behaviour(cowboy_handler).

-export([init/2]).

list_dir_latest_first() ->
    {ok, List} = file:list_dir(env:get("READ_HISTORY_PATH")),
    lists:reverse(List).

file_before([], _FileName) ->
    no_file;

file_before([FileName, NextFile], FileName) ->
    NextFile;

file_before([_|List], FileName) ->
    file_before(List, FileName).

file_before(FileName) ->
    file_before(list_dir_latest_first(), FileName).

history_reads_from_file(FileName) ->
    case file:consult(filename:join(env:get("READ_HISTORY_PATH"), FileName)) of
        {ok, [List]} -> List;
        Error ->
            io:format("Error reading home battery read history ~p~n", [Error]),
            "[]"
    end.

init(#{ bindings := #{ path := <<"before-discharge/", Path/binary>> }, method := <<"GET">>} = Req, State) ->
    Req2 = cowboy_req:reply(
        200,
        #{<<"content-type">> => <<"application/json">>},
        encode:home_battery(lists:reverse(history_reads_from_file(file_before(Path)))),
        Req),
    {ok, Req2, State};

init(#{ bindings := #{ path := <<"last-discharge">> }, method := <<"GET">> } = Req, State) ->
    [LatestFile|_] = list_dir_latest_first(),
    io:format("latif ~p~n", [LatestFile]),
    Req2 = cowboy_req:reply(
        200,
        #{<<"content-type">> => <<"application/json">>},
        encode:home_battery(lists:reverse(history_reads_from_file(LatestFile))),
        Req),
    {ok, Req2, State};

init(Req, State) ->
    % Retrieve the HTTP method
    io:format("rerq ~p~n", [Req]),
    {ok, Req, State}.
