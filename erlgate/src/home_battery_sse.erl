-module(home_battery_sse).

-export([init/2]).
-export([info/3]).

-define(ONE_MINUTE, 60000).

-include_lib("kernel/include/logger.hrl").

init(Req0, Opts) ->
    % Stop disconnecting SSE connection if no activity for 60 seconds
    cowboy_req:cast({set_options, #{idle_timeout => infinity}}, Req0),

    home_battery:subscribe(self()),

	Req = cowboy_req:stream_reply(200, #{
		<<"content-type">> => <<"text/event-stream">>
	}, Req0),

	{cowboy_loop, Req, Opts}.

info(read, Req, State) ->
	{ok, Req, State};

info({logged_reads, Reads}, Req, State) ->
	cowboy_req:stream_events(#{
        id => id(),
        data => encode:home_battery(lists:reverse(Reads))
    }, nofin, Req),
    {ok, Req, State};

info(Msg, Req, State) ->
    ?LOG_WARNING("Unexpected home battery SSE message ~p", [Msg]),
    {ok, Req, State}.

id() -> integer_to_list(erlang:unique_integer([positive, monotonic]), 16).
