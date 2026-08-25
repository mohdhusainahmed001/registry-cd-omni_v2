-module(register).

-include("onex.hrl").

-export([add/1, get_last_update/2, update_status_as/3]).

-export([insert_into_table/7]).

-export([get_tablename/1]).

add(DataMap) when is_map(DataMap) ->
  case util:get_data_from_map(DataMap) of
    {error, Reason} ->
      logger:error("Unable to find 'data' or 'data_gw' in DataMap: ~p", [Reason]),
      {400, ["Invalid DataMap", DataMap]};

    {ok, Data} ->
      case validate:validate_data_add(Data) of
        {400, Response} ->
          logger:error("Error in Data Format: ~p", [Response]),
          {400, Response};

        [DockerId, Ip, Port, Status, TimeToRefresh, Type, Meta] ->
          insert_into_table(DockerId, Ip, Port, Status, TimeToRefresh, Type, Meta),
          node_status_handler:set_status(DockerId, Type, TimeToRefresh),
          {200, <<"Inserted Successfully">>}
      end
  end;
add(DataMap) ->
  logger:error("Data is not a Map:~p",[DataMap]),
  {400,{<<"Check Data Format">>, DataMap}}.

get_tablename(Type) ->
  case maps:get(Type,?NODE_TABLES, undefined) of
    undefined -> others_registry;
    Name      -> Name
  end.

insert_into_table(Docker ,Ip, Port, Status, TimeToRefresh, Type, Meta)->
  insert_into_table(get_tablename(Type), Docker ,Ip, Port, Status, TimeToRefresh, Type, Meta).

insert_into_table(TableName, Docker ,Ip, Port, Status, TimeToRefresh, Type, Meta)->
  LastUpdated = os:system_time(millisecond),
  ets:insert(TableName, {Docker, Ip, Port, Status, TimeToRefresh, Type, Meta, LastUpdated}),
  logger:info("Inserted/Updated entry in ~p for Docker: ~p with IP: ~p, Port: ~p, Status: ~p, TimeToRefresh: ~p, Meta: ~p~n",
    [TableName, Docker, Ip, Port, Status, TimeToRefresh, Meta]),
  update_prometheus_data(Docker, Ip, Port, Status, Type, Meta).

get_last_update(DockerIdRequest, TypeRequest) ->
  TableName = get_tablename(TypeRequest),
  case ets:lookup(TableName, DockerIdRequest) of
    [{_, _, _, _, _, _, _, LastUpdated}] ->
      LastUpdated;
    _ErrorReason   ->
      {error, "DockerId not found"}
  end.

update_status_as(DockerId, Type, NewStatus) ->
  TableName = get_tablename(Type),
  case ets:lookup(TableName, DockerId) of
    [{Docker, Ip, Port, _, TimeToRefresh, Type, Meta, _}] ->
      insert_into_table(TableName, Docker, Ip, Port, NewStatus, TimeToRefresh, Type, Meta),
      ok;
    _ErrorReason ->
      {error, "DockerId not found"}
  end.

update_prometheus_data(Docker, Ip, Port, Status, Type, Meta) ->
  StatusValue = case Status of
    "ready" -> 1.0;
    "pause" -> 0.0;
    _       -> -1.0
  end,
  prometheus_handler:set_service_status(Type, Docker, Ip, Port, StatusValue),
  case Meta of
    [] -> ok;
    _  -> 
      MetaKeys = maps:keys(Meta),
      lists:foreach(fun(MetaKey) ->
        MetaValue = maps:get(MetaKey, Meta),
        prometheus_handler:set_service_meta_info(Type, Docker, Ip, Port, MetaKey, MetaValue, StatusValue)
      end, MetaKeys)
  end.