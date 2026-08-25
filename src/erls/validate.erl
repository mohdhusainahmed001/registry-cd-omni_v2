-module(validate).

-include("onex.hrl").

-export([validate_data_add/1, validate_fields/2, validate_data_get/1]).

-export([docker_present/1,type_present/1]).


validate_data_add(DataMap ) when is_map(DataMap ) ->
  Missing_Fields =  [Element || Element <- ?FIELDS_ADD, not maps:is_key(Element, DataMap)],
  case Missing_Fields of
    [] ->
      validate_fields(DataMap,"ADD");
    _  ->
      {400 , [<<"Some Fields are missing at ADD ">>, Missing_Fields,DataMap]}
  end;

validate_data_add(DataMap)->
  {400 ,[<<"DataMap is not a map at ADD">>, DataMap]}.


validate_data_get(DataMap) when is_map(DataMap) ->
  Missing_Fields =  [Element || Element <- ?FIELDS_GET, not maps:is_key(Element, DataMap)],
  case Missing_Fields of
    [] ->
      case validate_fields(DataMap, "GET" ) of
      [Type,Docker,Status] ->
        [Type,Docker,Status];
    _  ->
      {400, [<<"Data is not in correct format ">>,DataMap]}
      end;
     _   ->
      {400, [<<"Some Fields are missing in GET_REGISTRY REQUEST ">>,Missing_Fields,DataMap]}
  end;

validate_data_get(DataMap)->
  {400 ,[<<"DataMap  at GET_REGISRTY REQUEST is not a map">>,DataMap]}.


validate_fields(DataMap, RequestType) ->
  {FieldValidatorList ,FieldsList} =
    case RequestType of
      "ADD"   -> { ?FIELDS_VALIDATION_ADD, ?FIELDS_ADD };
      "GET"   -> { ?FIELDS_VALIDATION_GET, ?FIELDS_GET }
    end,
  Results = lists:map(
    fun({FieldName, ValidatingFunction}) ->
      case ValidatingFunction(maps:get(FieldName, DataMap)) of
        ok ->
          ok;
        _Error ->
          logger:error("~p : ~p , Received : ~p",[FieldName, _Error , maps:get(FieldName, DataMap)]),
          _Error
      end
    end,
    FieldValidatorList),
  InvalidResults = [Res || Res <- Results, Res /= ok],
  case InvalidResults of
    [] ->
      DataList =
        lists:map(
          fun(Field) ->
            case maps:find(Field, DataMap) of
              {ok, Value} ->
                Value;
              error  ->
                error
            end
          end,FieldsList ),
      DataList;
    _ ->
      {400, InvalidResults}
  end.


validate_ip(IpString) when is_binary(IpString) ->
  validate_ip(binary_to_list(IpString));

validate_ip(IpString) when is_list(IpString)   ->
  try
    case inet:parse_address(IpString) of
      {ok, {A, B, C, D}} when A >= 0, A =< 255, B >= 0, B =< 255, C >= 0, C =< 255, D >= 0, D =< 255  ->
        ok;
      _                                                                                               ->
        invalid_ip
    end
  catch
      _:_ ->
        invalid_ip  % Catch any other exceptions and return false
  end;

validate_ip(_) ->
  invalid_ip.


validate_port(Port) when is_integer(Port) ->
  try
      case Port of
        P when P >= 0, P =< 65535 ->
          ok;
        _                         ->
          invalid_port
      end
  catch
        _:_ ->
          invalid_port  % Not a valid integer representation
  end;

validate_port(_) ->
  invalid_port.


validate_dockerid(DockerId ) when is_list(DockerId ) ->
  case {length(DockerId ), re:run(DockerId, "^[0-9a-fA-F]+$", [anchored])} of
    {12, {match, _}} ->
      ok;   % Valid short ID (12 characters)
    {64, {match, _}} ->
      ok;   % Valid full ID (64 characters)
    _                ->
      invalid_dockerid
  end;

validate_dockerid(_) ->
  invalid_dockerid.


validate_time_to_refresh(TimeToRefresh) when is_integer(TimeToRefresh) ->
  try
    case TimeToRefresh of T
      when T > 0 ->
        ok;  % Valid positive integer
      _          ->
        invalid_ttr
    end
  catch
      _:_->  invalid_ttr  % Not a valid integer representation
  end;

validate_time_to_refresh(_) ->
  invalid_ttr.  % Not a valid input type


	 
validate_status(Status) when is_list(Status) ->
  case Status of
    "up"        -> ok;
    "down"      -> ok;
    "ready"     -> ok;
    "not_ready" -> ok;
    "pause"     -> ok;
    "move"      -> ok;
    _           -> invalid_status
  end;

validate_status(_) ->
  invalid_status.


validate_dockerid_get(<<"all">>) -> ok;
validate_dockerid_get("all")	 -> ok;

validate_dockerid_get(DockerId ) when is_list(DockerId ) ->
  case {length(DockerId ), re:run(DockerId, "^[0-9a-fA-F]+$", [anchored])} of
    {12, {match, _}} ->
      ok;   % Valid short ID (12 characters)
    {64, {match, _}} ->
      ok;   % Valid full ID (64 characters)
    _                ->
      invalid_dockerid
  end;

validate_dockerid_get(_) ->
  invalid_dockerid.

validate_status_get(<<"all">>) -> ok;
validate_status_get(Status) when is_list(Status) ->
  case Status of
    "up"        -> ok;
    "down"      -> ok;
    "ready"     -> ok;
    "not_ready" -> ok;
    "all"	-> ok;
    "move"	-> ok;
    "pause"	-> ok;
    _           ->
      invalid_status
  end;

validate_status_get(_) ->
  invalid_status.

validate_type(<<"all">>) -> ok;

validate_type(Type) when is_list(Type) ->
  ok;

validate_type(_) ->
  invalid_type.

docker_present(DataMap) ->
  DockerPresent =
  try maps:get(<<"dockerid">>, DataMap, undefined) of
   undefined ->
     dockerid_error;
   _ ->
    ok
  catch
    error:badmap ->
      dockerid_error;
    _ :_->
      dockerid_error
  end,
  DockerPresent .


type_present(DataMap) ->
  TypePresent =
    try maps:get(<<"type">>, DataMap, undefined) of
    undefined ->
      type_error;
    _ ->
      ok
  catch
    error:badmap ->
      type_error;
    _:_          ->
      type_error
    end,TypePresent.










