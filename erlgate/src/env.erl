-module(env).
-export([
    get/1,
    get/2
]).

get(Key) when is_list(Key) ->
    Value = os:getenv(Key),
    case Value of
        false ->
            error("No environment variable named '" ++ Key ++ "'");
        Value -> Value
    end.

get(Key, Default) when is_list(Key) ->
    Value = os:getenv(Key),
    case Value of
        false -> Default;
        Value -> Value
    end.
