-module(prometheus_handler).
 
-export([init/2]).

-export([
    create_gauge/0,
    set_service_status/5,
    set_service_meta_info/7
  ]).
 
%%------------------------------------------------------------------------%%
init(Req, State) ->
  Req2 = cowboy_req:reply(200, #{
    <<"content-type">> => <<"text/plain">>
  }, prometheus_text_format:format(), Req),
  {ok, Req2, State}.

create_gauge() ->
  prometheus_gauge:declare([
    {name,   service_status},
    {help,   "service_status"},
    {labels, [category, instance, ip, port]}]),
    
  prometheus_gauge:declare([
    {name,   service_meta_info},
    {help,   "Metadata attributes of services"},
    {labels, [category, instance, ip,  meta_key, meta_value, port]}]).
    
set_service_meta_info(Category, InstanceId, Ip, Port, MetaKey, MetaValue, StatusValue) ->
  prometheus_gauge:set(service_meta_info,  [Category, InstanceId, Ip, MetaKey, MetaValue, Port], StatusValue).

set_service_status(Category, InstanceId, Ip, Port, StatusValue) ->
  prometheus_gauge:set(service_status, [Category, InstanceId, Ip, Port], StatusValue).
 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% END %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%