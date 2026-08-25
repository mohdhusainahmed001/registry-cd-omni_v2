-define(NODE_TABLES,
  #{
    "auth" => auth_registry, "mon" => mon_registry, "hub" => hub_registry, "api" => api_registry,
    "uihub" => uihub_registry, "echo" => echo_registry, "smsc" => smsc_registry,
    "recon" => recon_registry, "reaper" => reaper_registry, "dlr_sender" => dlr_sender_registry,
    "reports" => reports_registry, "otp_gw" => otp_gw, "trans_gw" => trans_gw, "promo_gw" => promo_gw,
    "campaign_gw" => campaign_gw, "authapi_warcs" => authapi_warcs, "billing" => billing, "url_shortener" => url_shortener,
    "warcs_campaign" => warcs_campaign
  }).

-define(PROMETHEUS_NODE_TABLES, ["hub", "api", "smsc"]).

-define(FIELDS_ADD,
  [<<"dockerid">>,<<"ip">>,<<"port">>,<<"status">>,<<"time_to_refresh">>,<<"type">>,<<"meta">>]).

-define(FIELDS_GET,[<<"type">>,<<"dockerid">>,<<"status">>]).

-define(FIELDS_VALIDATION_ADD,
  [
    {<<"dockerid">>,        fun validate_dockerid/1},
    {<<"ip">>,              fun validate_ip/1},
    {<<"port">>,            fun validate_port/1},
    {<<"status">>,          fun validate_status/1},
    {<<"time_to_refresh">>, fun validate_time_to_refresh/1}
  ]).

-define(FIELDS_VALIDATION_GET,
  [
    {<<"dockerid">>, fun validate_dockerid_get/1},
    {<<"status">>,   fun validate_status_get/1},
    {<<"type">>,     fun validate_type/1}
  ]).
