-module(node_info_handler).
-include("onex.hrl").
-export([init/2]).


init(Req0, Opts) ->
  Request     = cowboy_req:read_urlencoded_body(Req0),
  Response    =
    case process_request(Request) of
      ok                 ->
        cowboy_req:reply(200, Req0);
      {Code, ReplyBody}  ->
        cowboy_req:reply(Code, #{<<"content-type">> => <<"application/json">>},
          jiffy:encode(ReplyBody), Req0);
      RequestData        ->
        cowboy_req:reply(200, #{<<"content-type">> => <<"text/plain">>}, RequestData, Req0)
    end,
  {ok, Response, Opts}.

process_request({ok, ReqBody, ReqHeader}) ->
  ReqCall = maps:get(path, ReqHeader),
  Method  = maps:get(method, ReqHeader),
  process_request(Method, ReqCall, ReqBody, ReqHeader);

process_request(Request) ->
  logger:error("Unhandled request in /node_info or /get_source : ~p~n", [Request]).

process_request(<<"POST">>, <<"/publish">>, [{ReqBody, true}], _ReqHeader) ->
  try
    logger:info("Received publish request with body: ~p~n", [ReqBody]),
    Data     = jiffy:decode(ReqBody, [return_maps]),
    Response = register:add(Data),
    Response
  catch
    Error:_Reason ->
      {400, ["Error :", Error]}
  end;

process_request(<<"POST">>, <<"/get_registry">>, [{ReqBody, true}], _ReqHeader) ->
  try
    Data     = jiffy:decode(ReqBody, [return_maps]),
    Response = get_registry:get_data(Data),
    Response
  catch
    Error:_Reason ->
      {400, ["Error :", Error]}
  end;
process_request(<<"POST">>, <<"/get_data">>, [{ReqBody, true}], _ReqHeader) ->
  try
    Data      = jiffy:decode(ReqBody, [return_maps]),
    FormatReq = util:convert_map_values_to_list(Data),
    case get_registry:get_filtered_data(FormatReq) of
      {200, Response} ->
	{200, util:convert_map_values_to_binary(Response)};
      ErrResp         ->
        ErrResp
    end
  catch
    Error:_Reason ->
      {400, ["Error :", Error]}
  end;
process_request(<<"GET">>, <<"/yaml_conf">>, _ReqBody, _ReqHeader) ->
  try
    {200, get_registry:get_yaml_conf("all")}
  catch
    Error:_Reason ->
		  io:format("Reason ~p~n", [_Reason]),
      {400, ["Error :", Error]}
  end;


process_request(<<"PUT">>, Req, _ReqBody, _ReqHeader) ->
  logger:error("Unknown put request : ~p~n", [Req]),
  ok;

process_request(<<"POST">>, Req, _ReqBody, _ReqHeader) ->
  logger:error("Unknown post request : ~p~n", [Req]),
  ok;

process_request(<<"GET">>, _, _ReqBody, _ReqHeader) ->
  logger:error("No function found for GET request",[]).


