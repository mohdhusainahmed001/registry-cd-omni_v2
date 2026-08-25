%%%-------------------------------------------------------------------
%% @doc registry top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(registry_sup).

-behaviour(supervisor).

-include("onex.hrl").

-export([start_link/0]).

-export([init/1]).

-define(SERVER, ?MODULE).

start_link() ->
  supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
  prometheus_handler:create_gauge(),
  lists:map(
    fun(TableName) ->
      ets:new(TableName, [named_table, set, public, {write_concurrency, true}, {read_concurrency, true}])
    end,
    maps:values(?NODE_TABLES)++[others_registry]
  ),
  SupFlags = #{strategy => one_for_all,
                intensity => 0,
                period => 1},
  ChildSpecs = [
  #{
      id => node_status_handler,
      start => {node_status_handler, start_link, []},
      type => worker
    }
  ],
  {ok, {SupFlags, ChildSpecs}}.

%% internal functions
