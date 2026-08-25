-module(util).

-export([convert_map_values_to_binary/1, convert_map_values_to_list/1, format_data/2, get_data_from_map/1]).

%% Convert only string values to binary (keys remain unchanged).
convert_map_values_to_list(BinaryMap) when is_map(BinaryMap) ->
    maps:from_list([
        {K, convert_value(V)} || {K, V} <- maps:to_list(BinaryMap)
    ]).

convert_value(V) when is_binary(V) -> binary_to_list(V);
convert_value(V) when is_map(V) -> convert_map_values_to_list(V);
convert_value(V) -> V.  % Leave numbers, lists, and other types unchanged.

%% Convert only string values to binary (keys remain unchanged).
convert_map_values_to_binary(StringMap) when is_map(StringMap) ->
    maps:from_list([
        {K, convert_value_to_binary(V)} || {K, V} <- maps:to_list(StringMap)
    ]).

convert_value_to_binary(V) when is_list(V) -> list_to_binary(V);
convert_value_to_binary(V) when is_map(V) -> convert_map_values_to_binary(V);
convert_value_to_binary(V) -> V.  % Leave numbers, lists, binaries, and other types unchanged.

format_data(<<"hub">>, HubData) ->
  maps:fold(fun(_Key, Value, Acc) ->
    IP          = maps:get(<<"ip">>, Value, ""),
    Port        = maps:get(<<"port">>, Value, 0),
    Status      = maps:get(<<"status">>, Value, ""),
    Meta        = maps:get(<<"meta">>, Value, #{}),
    BindStatus  = maps:get(<<"bind_status">>, Meta, undefined),
    GWID        = maps:get(<<"gateway_id">>, Meta, 0),
    SmppcID     = maps:get(<<"smppc_id">>, Meta, 0),
    ResponseMap = #{
      <<"targets">> => [list_to_binary(lists:concat([IP , ":" , Port]))],
      <<"labels">>  => #{
        <<"job_name">>    => list_to_binary(lists:concat(["hub_", SmppcID])),
        <<"status">>      => list_to_binary(Status),
        <<"type">>        => <<"hub">>,
        <<"bind_status">> => atom_to_binary(BindStatus),
        <<"gateway_id">>  => integer_to_binary(GWID),
        <<"smppc_id">>    => integer_to_binary(SmppcID),
        <<"docker_port">> => integer_to_binary(Port)
      }
    },
    [ResponseMap | Acc]
  end, [], HubData);
format_data(<<"smsc">>, NodeData)     ->
  maps:fold(fun(Key, Value, Acc) ->
    IP          = maps:get(<<"ip">>, Value, ""),
    DockerPort  = maps:get(<<"docker_port">>, Value, 0),
    Meta        = maps:get(<<"meta">>, Value, #{}),
    Port        = maps:get(<<"cowboy_port">>, Meta, 0),
    Status      = maps:get(<<"status">>, Value, ""),
    ResponseMap = #{
      <<"targets">> => [list_to_binary(lists:concat([IP , ":" , Port]))],
      <<"labels">>  => #{
        <<"job_name">> => list_to_binary([<<"smsc_">>, Key]),
        <<"status">>   => list_to_binary(Status),
        <<"type">>     => <<"smsc">>,
        <<"docker_port">>  => integer_to_binary(DockerPort)
      }
    },
    [ResponseMap | Acc]
  end, [], NodeData);
format_data(Node, NodeData)     ->
  maps:fold(fun(Key, Value, Acc) ->
    IP          = maps:get(<<"ip">>, Value, ""),
    Port        = maps:get(<<"port">>, Value, 0),
    Status      = maps:get(<<"status">>, Value, ""),
    ResponseMap = #{
      <<"targets">> => [list_to_binary(lists:concat([IP , ":" , Port]))],
      <<"labels">>  => #{
        <<"job_name">> => list_to_binary([Node, <<"_">>, Key]),
        <<"status">>   => list_to_binary(Status),
        <<"type">>     => Node,
        <<"docker_port">>  => integer_to_binary(Port)
      }
    },
    [ResponseMap | Acc]
  end, [], NodeData).

get_data_from_map(DataMap) ->
  case maps:find(<<"data">>, DataMap) of
    {ok, Data} when is_map(Data) ->
      {ok, Data};
    error ->
      case maps:find(<<"data_warcs">>, DataMap) of
        {ok, RawData} when is_map(RawData) ->
          {ok, util:convert_map_values_to_list(RawData)};
        _ ->
          {error, no_data_found}
      end
  end.