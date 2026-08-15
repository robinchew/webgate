-module(home_battery).
-behaviour(gen_server).

-export([
    subscribe/1,
    start_link/0,
    read/1
]).
-export([
    init/1,
    handle_cast/2,
    handle_call/3,
    handle_info/2
]).

-include_lib("kernel/include/logger.hrl").

get_datetime() ->
    {{Year, Month, Day}, {Hour, Min, _Sec}} = erlang:localtime(),
    %io_lib:format("~4..0w-~2..0w-~2..0w ~2..0w:~2..0w:~2..0w", 
    %  [Year, Month, Day, Hour, Min, Sec]).
    io_lib:format("~4..0w-~2..0w-~2..0wT~2..0w:~2..0w", 
      [Year, Month, Day, Hour, Min]).

subscribe(Pid) ->
    gen_server:cast(?MODULE, {subber, Pid}).

read(RegisterId) ->
    try
        gen_server:call(modbus_tcp_client, {pdu, 247, 3, <<RegisterId:16, 1:16>>})
    of
        {error, not_connected} ->
            io:format("Read register ~p. NOT CONNECTED, trigger a restart~n", [RegisterId]),
            modbus_tcp_client:restart();
        {ok, Val} -> {ok, Val};
        Unexpected ->
            io:format("Unexpected ~p~n", [Unexpected])
    catch
        exit:{timeout, ErrMsg} ->
            io:format("Timeout caught: ~p~n", [ErrMsg]),
            timer:sleep(10000),
            modbus_tcp_client:restart(),
            caught_timeout;
        Err:Reason ->
            io:format("read error, ~p:~p~n", [Err, Reason]),
            {unexpected_catch, Err, Reason}
    end.

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, #{}, []).

init(State) ->
    Pid = self(),
    spawn_link(fun F() ->
        Pid ! {
            log_reads,
            get_datetime(),
            case read(37007) of
                {ok, <<2, 0, Percent>>} -> Percent;
                _ -> -1
            end,
            case read(35171) of
                {ok, <<2, H, L>>} -> H * 256 + L;
                _ -> -1
            end
        },
        timer:sleep(60000),
        F()
    end),
    {ok, State#{
        reads => [],
        subscribers => []
    }}.

handle_cast({subber, Pid}, State = #{subscribers := Subbers, reads := Reads}) ->
    Pid ! {logged_reads, Reads},
    {noreply, State#{
        subscribers => Subbers ++ [Pid]
    }};

handle_cast(Request, State) ->
    ?LOG_WARNING('Unexpected home_battery cast: ~p', [Request]),
    {noreply, State}.


handle_call(Msg, _From, State) ->
    ?LOG_WARNING('Unexpected home_battery call: ~p', [Msg]),
    {reply, ok, State}.

read_is_charging([{Date, BatteryLevel, HouseholdLoad}|OtherReads], no_last_read) ->
    read_is_charging(OtherReads, {Date, BatteryLevel, HouseholdLoad});

read_is_charging([{Date, BatteryLevel, HouseholdLoad}|OtherReads], {_LD, LatestBatteryLevel, _LHL}) ->
    case BatteryLevel < LatestBatteryLevel of
        true -> charging;
        _ -> case BatteryLevel > LatestBatteryLevel of
            true -> discharging;
            _ -> read_is_charging(OtherReads, {Date, BatteryLevel, HouseholdLoad})
        end
    end;

read_is_charging(_Reads, _LatestRead) ->
    more_reads_needed.

read_is_charging(Reads) ->
    read_is_charging(Reads, no_last_read).

detect_charge_change(discharging, charging) ->
    % change from discharging to charging
    % this is when reads should be saved to file and memory emptied
    save_and_empty_reads;

detect_charge_change(_, _) ->
    no_change.

log_reads(NewRead, State = #{reads := []}) ->
    State#{reads => [NewRead]};

log_reads(NewRead, State = #{reads := PreviousReads = [PrevRead|_]}) ->
    Change = detect_charge_change(
        read_is_charging(PreviousReads),
        read_is_charging([NewRead, PrevRead])),

    State#{
        reads => case Change of
            save_and_empty_reads ->
                Filename = io_lib:format("reads_erl_terms_~p.txt", [get_datetime()]),
                case file:write_file(Filename, io_lib:format("~p~n", PreviousReads)) of
                    ok -> pass;
                    Unexpected ->
                        ?LOG_ERROR("Unexpected error when saving previous reads: ~p", [Unexpected])
                end,
                [NewRead];
            _ ->
                [NewRead|PreviousReads]
        end
    }.

handle_info({log_reads, Date, BatteryLevel, HouseholdLoad}, State = #{subscribers := Subs}) ->
    lists:foreach(fun(Subber) ->
        Subber ! {logged_reads, [{Date, BatteryLevel, HouseholdLoad}]}
    end, Subs),
    io:format("~s, ~p%, ~pW~n", [Date, BatteryLevel, HouseholdLoad]),
    {noreply, log_reads({Date, BatteryLevel, HouseholdLoad}, State)};

handle_info(Msg, State) ->
    ?LOG_WARNING('Unexpected home_battery info: ~p', [Msg]),
    {noreply, State}.
