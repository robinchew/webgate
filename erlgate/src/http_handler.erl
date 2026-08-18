-module(http_handler).
-behaviour(cowboy_handler).

-export([init/2]).

wrap_encoded_home_battery(FileName, JsonString) ->
    "{\"filename\": \"" ++ FileName ++ "\", \"reads\": " ++ JsonString ++ "}".

list_dir_latest_first() ->
    {ok, List} = file:list_dir(env:get("READ_HISTORY_PATH")),
    lists:reverse(lists:sort(List)).

file_before([], _FileName) ->
    no_file;

file_before([FileName, NextFile|_OtherFiles], FileName) ->
    NextFile;

file_before([_First|OtherList], FileName) ->
    file_before(OtherList, FileName).

file_before(FileName) ->
    file_before(list_dir_latest_first(), FileName).

history_reads_from_file(FileName) ->
    case file:consult(filename:join(env:get("READ_HISTORY_PATH"), FileName)) of
        {ok, [List]} -> List;
        Error ->
            io:format("Error reading home battery read history ~p~n", [Error]),
            "[]"
    end.

reply_home_battery_read(no_file, Req) ->
    cowboy_req:reply(
        404,
        #{<<"content-type">> => <<"application/json">>},
        "null",
        Req);

reply_home_battery_read(FileName, Req) ->
    cowboy_req:reply(
        200,
        #{<<"content-type">> => <<"application/json">>},
        wrap_encoded_home_battery(FileName, encode:home_battery(lists:reverse(history_reads_from_file(FileName)))),
        Req).

init(#{ path := <<"/api/before-discharge/", Path/binary>>, method := <<"GET">>} = Req, State) ->
    FileName = file_before(binary_to_list(Path)),
    {ok, reply_home_battery_read(FileName, Req), State};

init(#{ path := <<"/api/last-discharge">>, method := <<"GET">> } = Req, State) ->
    [LatestFile|_] = list_dir_latest_first(),
    {ok, reply_home_battery_read(LatestFile, Req), State};

init(Req, State) ->
    % Retrieve the HTTP method
    io:format("rerq ~p~n", [Req]),
    {ok, Req, State}.
