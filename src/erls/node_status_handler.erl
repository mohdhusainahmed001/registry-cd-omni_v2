%% @doc
%% This module implements a `gen_server` behavior to manage Docker container statuses.
%% It handles setting and updating container status with specified time-to-refresh (TTR) intervals.
%%

-module(node_status_handler).

-behaviour(gen_server).

% API FUNCTIONS
-export([start_link/0, set_status/3]).

% CALLBACK FUNCTIONS
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-define(OFFSET_TIME, 5000).  % 5 seconds.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% API FUNCTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

set_status(DockerId, Type, TTR) ->
  case catch gen_server:cast(?MODULE, {set_status, DockerId, Type, TTR}) of
    {'EXIT', Reason} ->
       logger:error("Unable to set status ,Reason :~p",[Reason]),
       {error, Reason};
    ok               ->
      ok
  end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% CALLBACK FUNCTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

init([]) ->
  {ok, #{}}.

handle_call(_Request, _From, State) ->
  {reply, error, State}.

handle_cast({set_status, DockerId, Type , TTR}, State) ->
  set_status_helper(DockerId, Type, TTR, State);

handle_cast(_Msg, State) ->
  {noreply, State}.

handle_info({update_status, DockerId, Type, TTR}, State) ->
  update_status_helper(DockerId, Type, TTR, State);

handle_info(_Info, State) ->
  {noreply, State}.

terminate(_Reason, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% INTERNAL FUNCTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

set_status_helper(DockerId, Type, TTRNew, State) ->
  NewState =
    case maps:get(DockerId, State, undefined) of
      undefined              ->
        TimerRefNew = call_status_update(DockerId, Type, TTRNew, ?OFFSET_TIME),
        State#{DockerId => {TimerRefNew, TTRNew }};
      {_TimerRefOld, TTRNew} ->
          State;
      {TimerRefOld, _TTROld} ->
        erlang:cancel_timer(TimerRefOld),
        TimerRefNew = call_status_update(DockerId, Type, TTRNew, ?OFFSET_TIME),
        State#{DockerId => {TimerRefNew, TTRNew}}
    end,
  {noreply, NewState}.


update_status_helper(DockerId, Type, TTR, State) ->
  case maps:get(DockerId, State, undefined) of
    undefined           ->
      TimeRefNew = call_status_update(DockerId, Type, TTR, ?OFFSET_TIME),
      {noreply, State#{DockerId => {TimeRefNew , TTR}}};
    {_TimeRefOld, TTR } ->
      case register:get_last_update(DockerId, Type) of
        {error, Reason} ->
          logger:error("Error getting last update: ~p", [Reason]),
          {noreply, maps:remove(DockerId, State)};
        LastUpdated    ->
          % below case is to check if the last update is received within time to refresh
          case ((LastUpdated + TTR) > os:system_time(millisecond) - 30000)  of
            false ->
              % false is when the last update is not received within time , we will down the node
              case register:update_status_as(DockerId, Type, "down") of
                ok              -> logger:info("Updating status for Docker: ~p to down~n", [DockerId]), ok;
                {error, Reason} -> logger:error("Error updating status: ~p", [Reason])
              end,
              {noreply, maps:remove(DockerId, State)};
            true  ->
              TimeRefNewUpdate = call_status_update(DockerId, Type, TTR, 0),
              {noreply, State#{DockerId => {TimeRefNewUpdate , TTR } } }
          end
      end
  end.

call_status_update(DockerId, Type, TTRNew, Offset)->
   erlang:send_after(trunc(TTRNew+ Offset), self(), {update_status, DockerId, Type, TTRNew}).