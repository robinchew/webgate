-module(encode).
-export([
    home_battery/1
]).

home_battery_item(Date, BatteryLevel, HouseholdLoad) ->
    io_lib:format("{\"datetime\": \"~s\", \"battery_level\": ~p, \"household_load\": ~p}", [Date, BatteryLevel, HouseholdLoad]).

home_battery(List) ->
    "[" ++ lists:join(", ", [
        home_battery_item(Date, BatteryLevel, HouseholdLoad)
        || {Date, BatteryLevel, HouseholdLoad} <- List
    ]) ++ "]".
