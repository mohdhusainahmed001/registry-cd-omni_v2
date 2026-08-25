-module(initialization).

-export([init/0,print_node_tables/0]).

-include("onex.hrl").

-define(CONFIG_PATH, "/config/registry.config").

init() ->
  {ok, Cwd} = file:get_cwd(),
  ConfigFilePath = lists:concat([Cwd, ?CONFIG_PATH]),
  case filelib:ensure_dir(ConfigFilePath) of
    ok                   ->  ok;
    {error, ErrorReason} -> io:format("Failed to create directory: ~p~n", [ErrorReason])
  end,
  case file:consult(ConfigFilePath) of
    {ok, [Config]} ->
      case lists:keyfind(registry, 1, Config) of
        {registry, ConfigList} ->
          case lists:keyfind(config_data, 1, ConfigList) of
            {config_data, TuplePropList} ->
              get_values_and_insert_into_ets(TuplePropList);
            _ ->
              logger:error("ConfigData not found in registry.config~n")
          end;
        _ ->
          logger:error("Registry section not found in registry.config~n")
      end;
    {error, Reason} ->
      logger:error("Failed to read registry.config: ~p~n", [Reason])
  end.

get_values_and_insert_into_ets(ConfigData) ->
  lists:foreach(fun({Type, PropList}) ->
    lists:foreach(fun(ValueMap) ->
      [DockerId, Ip, Port, Status, TimeToRefresh, Type, Meta] =
        lists:map(fun(Field) -> maps:get(Field, ValueMap, []) end, ?FIELDS_ADD),
      register:insert_into_table(DockerId, Ip, Port, Status, TimeToRefresh, Type, Meta)
    end, PropList)
  end, ConfigData).


print_node_tables() ->
  Result = lists:map(fun(TableName) ->  ets:tab2list(TableName) end, maps:values(?NODE_TABLES)),
  io:format("Node Tables Content:~n~p~n", [Result]).
