-module(ws_handler).
-behavior(cowboy_websocket).

-export([init/2]).
-export([websocket_init/1]).
-export([websocket_handle/2]).
-export([websocket_info/2]).

-include_lib("kernel/include/logger.hrl").

read_lines(FileName) ->
    {ok, Binary} = file:read_file(FileName),
    %% Split by newline character, filter out empty binaries (trailing newlines)
    [Line || Line <- binary:split(Binary, <<"\n">>, [global]), Line =/= <<>>].

init(Req = #{bindings := #{subscriber_uuid := SubscriberUuid}}, State) ->
    % TODO rename subscriber_uuid session_uuid
	{cowboy_websocket, Req, State#{
        subscriber_uuid => SubscriberUuid
    }};

init(Req, State) ->
	{cowboy_websocket, Req, State}.

websocket_init(State = #{ subscriber_uuid := UserUuid }) ->
    WsPid = self(),
    {ok, UserPid} = user_spawner:start_child(UserUuid),
    user_spawn:register_ws_pid(UserPid, WsPid),
    WsPid ! {gate_state, gate_state_server:get_state()},
    Authorisation = case lists:member(UserUuid, read_lines(env:get("ALLOWED_USERS_PATH"))) of
        true -> <<"AUTHORISED">>;
        _ -> <<"UNAUTHORISED">>
    end,
    WsPid ! {auth, Authorisation},
	{[], State#{
        websocket_pid => WsPid
    }}.

websocket_handle({text, Data}, State = #{websocket_pid := WsPid}) ->
    {Responses, NewState} = ws_handles:on(WsPid, string:split(Data, "|", all), State),
    {[{text, Text} || Text <- Responses], NewState};

websocket_handle({binary, Data}, State) ->
    % Not expecting this handle to be used
    io:format("bni~p~n", [Data]),
	{[{binary, Data}], State};

websocket_handle(Frame, State) ->
    ?LOG_DEBUG("Unexpected Frame ~p", Frame),
	{[], State}.

websocket_info({refresh, Text}, State) ->
	{[{text, Text}], State};

websocket_info({auth, UserState}, State) when is_binary(UserState)->
	{[{text, <<"auth:", UserState/binary>>}], State};

websocket_info({gate_state, GateState}, State) when is_binary(GateState)->
	{[{text, <<"state:", GateState/binary>>}], State};

websocket_info(Info, State) ->
    io:format("iNfo ~p~n", [Info]),
	{[], State}.
