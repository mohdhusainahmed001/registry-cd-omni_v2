%%%-------------------------------------------------------------------
%% @doc registry public API
%% @end
%%%-------------------------------------------------------------------

-module(registry_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
	Dispatch = cowboy_router:compile([
		{'_', [
      {"/publish", node_info_handler, []},
      {"/get_registry", node_info_handler, []},
      {"/get_data", node_info_handler, []},
      {"/yaml_conf", node_info_handler, []},
			{"/metrics", prometheus_handler, []}
      ]}
		]),

	{ok, _} = cowboy:start_clear(http, [{port, 16000}], #{
	env => #{dispatch => Dispatch}
	}),
	registry_sup:start_link().

stop(_State) ->
  ok.

%% internal functions
