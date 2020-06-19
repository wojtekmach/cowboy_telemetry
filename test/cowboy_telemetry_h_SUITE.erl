-module(cowboy_telemetry_h_SUITE).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

all() ->
    [successful_request, failed_request, early_error_request].

init_per_suite(Config) ->
    application:ensure_all_started(ranch),
    application:ensure_all_started(telemetry),
    Dispatch = cowboy_router:compile([{"localhost", [
                                      {"/success", test_h, success},
                                      {"/failure", test_h, failure}
                                     ]}]),
    {ok, _} = cowboy:start_clear(http, [{port, 8080}], #{
                  env => #{dispatch => Dispatch},
                  stream_handlers => [cowboy_telemetry_h, cowboy_stream_h]
              }
    ),
    Config.

end_per_suite(_Config) ->
    application:stop(ranch),
    application:stop(telemetry).

successful_request(_Config) ->
    Events = [
        [cowboy, request, start],
        [cowboy, request, stop],
        [cowboy, request, exception]
    ],
    telemetry:attach_many(successful_request, Events, fun ?MODULE:echo_event/4, self()),
    {ok, {{_Version, 200, _ReasonPhrase}, _Headers, _Body}} =
        httpc:request(get, {"http://localhost:8080/success", []}, [], []),
    receive
        {[cowboy, request, start], StartMeasurements, StartMetadata} ->
            ?assertEqual([system_time], maps:keys(StartMeasurements)),
            ?assertEqual([req, stream_id], maps:keys(StartMetadata))
    after
        1000 -> ct:fail(successful_request_start_event)
    end,
    receive
        {[cowboy, request, stop], StopMeasurements, StopMetadata} ->
            ?assertEqual([duration], maps:keys(StopMeasurements)),
            ?assertEqual([response, stream_id], maps:keys(StopMetadata))
    after
        1000 -> ct:fail(successful_request_stop_event)
    end,
    receive
        {[cowboy, request, exception], _, _} ->
            ct:fail(failed_request_unexpected_exception_event)
    after
        100 -> ok
    end.

failed_request(_Config) ->
    Events = [
        [cowboy, request, start],
        [cowboy, request, stop],
        [cowboy, request, exception]
    ],
    telemetry:attach_many(failed_request, Events, fun ?MODULE:echo_event/4, self()),
    {ok, {{_Version, 500, _ReasonPhrase}, _Headers, _Body}} =
        httpc:request(get, {"http://localhost:8080/failure", []}, [], []),
    receive
        {[cowboy, request, start], StartMeasurements, StartMetadata} ->
            ?assertEqual([system_time], maps:keys(StartMeasurements)),
            ?assertEqual([req, stream_id], maps:keys(StartMetadata))
    after
        1000 -> ct:fail(failed_request_start_event)
    end,
    receive
        {[cowboy, request, exception], ExceptionMeasurements, ExceptionMetadata} ->
            ?assertEqual([duration], maps:keys(ExceptionMeasurements)),
            ?assertEqual([error_response, kind, reason, stream_id], maps:keys(ExceptionMetadata))
    after
        1000 -> ct:fail(failed_request_exception_event)
    end,
    receive
        {[cowboy, request, stop], _, _} ->
            ct:fail(failed_request_unexpected_stop_event)
    after
        100 -> ok
    end.

early_error_request(_Config) ->
    Events = [
        [cowboy, request, early_error],
        [cowboy, request, start],
        [cowboy, request, stop],
        [cowboy, request, exception]
    ],
    telemetry:attach_many(early_error_request, Events, fun ?MODULE:echo_event/4, self()),
    {ok, {{_Version, 501, _ReasonPhrase}, _Headers, _Body}} =
        httpc:request(trace, {"http://localhost:8080/", []}, [], []),
    receive
        {[cowboy, request, early_error], EarlyErrorMeasurements, EarlyErrorMetadata} ->
            ?assertEqual([system_time], maps:keys(EarlyErrorMeasurements)),
            ?assertEqual([partial_req,reason,response,stream_id], maps:keys(EarlyErrorMetadata))
    after
        1000 -> ct:fail(early_error_request_start_event)
    end,
    receive
        {[cowboy, request, start], _, _} ->
            ct:fail(early_error_request_unexpected_start_event)
    after
        100 -> ok
    end,
    receive
        {[cowboy, request, stop], _, _} ->
            ct:fail(early_error_request_unexpected_stop_event)
    after
        100 -> ok
    end,
    receive
        {[cowboy, request, exception], _, _} ->
            ct:fail(early_error_request_unexpected_exception_event)
    after
        100 -> ok
    end.

echo_event(Event, Measurements, Metadata, Pid) ->
        Pid ! {Event, Measurements, Metadata}.
