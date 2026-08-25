-module(get_registry).
-include("onex.hrl").
-export([get_data/1, get_all_nodes/1]).
-export([get_by_node_type/2, list_of_records/2, get_by_dockerid/3, get_filtered_data/1,get_yaml_conf/1]).

get_data(DataBody) when is_map(DataBody) ->
  case util:get_data_from_map(DataBody) of
    {error, Reason} ->
      logger:error("Unable to find 'data' or 'data_warcs' in DataMap: ~p", [Reason]),
      {400, [<<"Invalid DataMap">>, DataBody]};

    {ok, DataMap} ->
      case validate:validate_data_get(DataMap) of
        {400, Reply} ->
          logger:error("Error in Data Format: ~p", [Reply]),
          {400, Reply};

        [BinType, BinDocker, BinReqStatus] ->
          Type = convert_binary(BinType),
          Docker = convert_binary(BinDocker),
          ReqStatus = convert_binary(BinReqStatus),
          case {Type, Docker} of
            {"all", _} ->
              case get_all_nodes(ReqStatus) of
                {400, Reason} -> {400, Reason};
                NodeDataMap  -> {200, NodeDataMap}
              end;
            {Type, "all"} ->
              case get_by_node_type(Type, ReqStatus) of
                {400, Reason} -> {400, Reason};
                DataMap       -> {200, DataMap}
              end;
            {Type, DockerId} ->
              case get_by_dockerid(Type, DockerId, ReqStatus) of
                {400, Reason} -> {400, Reason};
                DataMap       -> {200, DataMap}
              end
          end
      end
  end;
get_data(DataMap)->
   logger:error("Data is not a Map:~p", [DataMap]),
   {400, [<<"Check Data Format">>, DataMap]}.

get_all_nodes(ReqStatus) ->
  NodesList = maps:keys(?NODE_TABLES) ++ ["other"],
  lists:foldl(
    fun(Type, AccNodeMap) ->
      NodeDataMap = get_by_node_type(Type, ReqStatus),
      AccNodeMap#{list_to_binary(Type) => NodeDataMap}
    end,
    #{},
    NodesList).

get_yaml_conf(ReqStatus) ->
  NodesData = lists:foldl(
    fun(Type, AccNodeMap) ->
      NodeDataMap = get_by_node_type(Type, ReqStatus),
      AccNodeMap#{list_to_binary(Type) => NodeDataMap}
    end,
    #{},
    ?PROMETHEUS_NODE_TABLES),
  maps:fold(fun(Key, Value, Acc) ->
    lists:concat([util:format_data(Key, Value), Acc])
  end, [], NodesData).

get_by_node_type(Type, "all")->
  TableName = register:get_tablename(Type),
  try
    ets:tab2list(TableName) of
      RecordsList ->
        NodeDataMap =  list_of_records(RecordsList, "all"),
        NodeDataMap
  catch
    Error:_->
      {400, [Error]}
  end;

get_by_node_type(Type, ReqStatus)->
  TableName = register:get_tablename(Type),
  MatchSpec = [{{'_', '_', '_', ReqStatus, '_', '_', '_','_'}, [], ['$_']}],
  try
    ets:select(TableName, MatchSpec) of
      RecordsList ->
        NodeDataMap =  list_of_records(RecordsList, ReqStatus),
        NodeDataMap
  catch
    Error:_ ->
      {400, [Error]}
  end.

list_of_records(RecordsList, ReqStatus)->
  DockerInnerMapList =  lists:map(fun(Record)-> record_to_keyvalue(Record, ReqStatus) end , RecordsList),
  lists:foldl(
  fun({Docker, InnerMap}, AccMap) ->
      AccMap#{Docker => InnerMap}
  end,
#{}, DockerInnerMapList).

get_by_dockerid(Type, DockerId, <<"all">>) ->get_by_dockerid(Type, DockerId, "all");
get_by_dockerid(Type, DockerId, "all") ->
  TableName = register:get_tablename(Type),
  try
    ets:lookup(TableName, DockerId) of
      [Result] ->
        {DockerRecord, InnerMap} =record_to_keyvalue(Result, "all"),
        #{DockerRecord => InnerMap};
      [] ->
        {400, [<<"DockerId is not a key of the table">>]}
  catch
    Error:_Reason ->
      {400, [Error]}
  end;


get_by_dockerid(Type ,DockerId, ReqStatus) ->
  TableName = register:get_tablename(Type),
  try
    ets:lookup(TableName, DockerId) of
      [Result] ->
        {DockerRecord, InnerMap} =record_to_keyvalue(Result, ReqStatus),
        #{DockerRecord => InnerMap};
      [] ->
        {400, [<<"DockerId is not a key of the table">>]}
  catch
    Error:Reason ->
      {400, [Error, Reason]}
  end.

record_to_keyvalue({Docker, Ip, Port, Status, _TimeToRefresh, _Type, Meta,_LastUpdated}, "all") ->
  InnerMap =
    #{
      <<"ip">> => Ip,
      <<"port">> => Port,
      <<"meta">> => Meta,
      <<"status">> => Status
    },
    {list_to_binary(Docker),InnerMap};

record_to_keyvalue({Docker ,Ip, Port, _Status, _TimeToRefresh, _Type, Meta,_LastUpdated}, _ReqStatus) ->
  InnerMap =
    #{
      <<"ip">> => Ip,
      <<"port">> => Port,
      <<"meta">> => Meta
    },
    {list_to_binary(Docker),InnerMap}.


convert_binary(Bin) when is_binary(Bin)-> erlang:binary_to_list(Bin);
convert_binary(String) -> String.

get_filtered_data(DataBody) ->
  case maps:find(<<"data">>, DataBody) of
    error             ->
      logger:error("Unable to find 'data' in DataMap : ~p~n ", [DataBody]),
      {400, [<<"Invalid DataMap">>, DataBody]};
    {ok, DataMap}     ->
      case validate:validate_data_get(DataMap) of
        {400, Reply}             ->
          logger:error("Error in Data Format  %p", [Reply]),
          {400, Reply};
        [Type, Docker, ReqStatus] ->
          {200, fetch_filtered_data(Type, Docker, ReqStatus)}
      end
  end.

fetch_filtered_data(Type, Docker, ReqStatus) ->
  Tables = get_matching_tables(Type),
  lists:foldl(fun(Table, Acc) ->
    maps:put(list_to_binary(Table), fetch_from_table(Table, Docker, ReqStatus), Acc)
  end, #{}, Tables).

fetch_from_table(Table, Docker, ReqStatus) ->
  TableName = register:get_tablename(Table),
  MatchSpec = create_matchspec(Docker, ReqStatus),
  try ets:select(TableName, MatchSpec) of
    RecordsList ->
      list_of_records(RecordsList, ReqStatus)
  catch
    Error:_ ->
      {400, [Error]}
  end.

get_matching_tables("all") ->
  maps:keys(?NODE_TABLES) ++ ["other"];
get_matching_tables(Type)      ->
  [Type].

create_matchspec("all", "all") ->
  [{{'_', '_', '_', '_', '_', '_', '_','_'}, [], ['$_']}];
create_matchspec(Docker, "all")    ->
  [{{Docker, '_', '_', '_', '_', '_', '_','_'}, [], ['$_']}];
create_matchspec("all", ReqStatus) ->
  [{{'_', '_', '_', ReqStatus, '_', '_', '_','_'}, [], ['$_']}];
create_matchspec(Docker, ReqStatus)    ->
  [{{Docker, '_', '_', ReqStatus, '_', '_', '_','_'}, [], ['$_']}].


