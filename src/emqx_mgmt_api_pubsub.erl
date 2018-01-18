%%--------------------------------------------------------------------
%% Copyright (c) 2015-2017 EMQ Enterprise, Inc. (http://emqtt.io).
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

-module(emqx_mgmt_api_pubsub).

-author("Feng Lee <feng@emqtt.io>").

-include_lib("emqx/include/emqx.hrl").

-include_lib("emqx/include/emqx_mqtt.hrl").

-import(proplists, [get_value/2, get_value/3]).

-rest_api(#{name   => mqtt_subscribe,
            method => 'POST',
            path   => "/mqtt/subscribe",
            func   => subscribe,
            descr  => "Subscribe a topic"}).

-rest_api(#{name   => mqtt_publish,
            method => 'POST',
            path   => "/mqtt/publish",
            func   => publish,
            descr  => "Publish a MQTT message"}).

-rest_api(#{name   => mqtt_unsubscribe,
            method => 'POST',
            path   => "/mqtt/unsubscribe",
            func   => unsubscribe,
            descr  => "Unsubscribe a topic"}).

-rest_api(#{name   => mqtt_rule_notice,
            method => 'POST',
            path   => "/mqtt/rulenotice",
            func   => rule_notice,
            descr  => "Notice CTQ-MQ birdge subscribe topic"}).

-rest_api(#{name   => dm_publish,
            method => 'POST',
            path   => "/dm/publish",
            func   => dm_publish,
            descr  => "DM Publish a MQTT message for Device"}).

-export([subscribe/2, publish/2, unsubscribe/2, rule_notice/2, dm_publish/2]).

subscribe(_Bindings, Params) ->
    ClientId = get_value(<<"client_id">>, Params),
    Topic    = get_value(<<"topic">>, Params),
    QoS      = get_value(<<"qos">>, Params, 0),
    emqx_mgmt:subscribe(ClientId, Topic, QoS).

publish(_Bindings, Params) ->
    Topics   = topics(Params),
    ClientId = get_value(<<"client_id">>, Params),
    Payload  = get_value(<<"payload">>, Params, <<>>),
    Qos      = get_value(<<"qos">>, Params, 0),
    Retain   = get_value(<<"retain">>, Params, false),
    lists:foreach(fun(Topic) ->
        Msg = emqx_message:make(ClientId, Qos, Topic, Payload),
        emqx_mgmt:publish(Msg#mqtt_message{retain = Retain})
    end, Topics).

dm_publish(_Bindings, Params) ->
    case check_required_params(Params) of
    ok ->
        Payload  = jsx:decode(get_value(<<"payload">>, Params)),
        make_publish(Params, Payload),
        {ok, [{code, 0}, {message, <<>>}]};
    {error, Error} ->
        {ok, [{code, 1}, {message, list_to_binary(Error)}]}
    end.

make_publish(Params, Payload) ->
    Topic = list_to_binary(mount(Params)),
    ClientId = get_value(<<"client_id">>, Params, <<"DM">>),
    Qos      = get_value(<<"qos">>, Params, 1),
    Ttl      = get_value(<<"ttl">>, Params),
    AppId    = get_value(<<"appId ">>, Params, <<"DM">>),
    Payload1 = jsx:encode([{ttl, Ttl}, {appId, AppId} | Payload]),
    Msg      = emqx_message:make(ClientId, Qos, Topic, Payload1),
    emqx_mgmt:publish(Msg).

unsubscribe(_Bindings, Params) ->
    ClientId = get_value(<<"client_id">>, Params),
    Topic    = get_value(<<"topic">>, Params),
    emqx_mgmt:unsubscribe(ClientId, Topic).

topics(Params) ->
    Topics = [get_value(<<"topic">>, Params, <<"">>) | binary:split(get_value(<<"topics">>, Params, <<"">>), <<",">>, [global])],
    [Topic || Topic <- Topics, Topic =/= <<"">>].

rule_notice(_Bindings, Params) ->
    Topic = get_value(<<"topic">>, Params),
    Flag  = get_value(<<"flag">>, Params),
    Payload = jsx:encode([{topic, Topic}, {flag, Flag}]),
    Msg = emqx_message:make(broker, 0, <<"$SYS/rulenotice">>, Payload),
    emqx_mgmt:publish(Msg).

%%TODO:
%%validate(qos, Qos) ->
%%    (Qos >= ?QOS_0) and (Qos =< ?QOS_2);

%%validate(topic, Topic) ->
%%    emqx_topic:validate({name, Topic}).

%% Internal function
check_required_params(Params) ->
    check_required_params(Params, required_params()).

check_required_params(_, []) -> ok;
check_required_params(Params, [Key | Rest]) ->
    case lists:keytake(Key, 1, Params) of
      {value, _, NewParams} -> check_required_params(NewParams, Rest);
      false                 -> {error, binary_to_list(Key) ++ " must be specified"}
    end.

required_params() ->
  [
    <<"tenantId">>,
    <<"productId">>,
    <<"deviceId">>,
    <<"topic">>,
    <<"payload">>,
    <<"ttl">>
  ].

mount(Params) ->
    Topic = to_list(get_value(<<"topic">>, Params)),
    lists:foldr(fun(Key, AccIn) ->
                lists:concat([to_list(get_value(Key, Params)), "/", AccIn])
                end, Topic, [<<"tenantId">>, <<"productId">>, <<"deviceId">>]).

to_list(I) when is_integer(I) ->
    integer_to_list(I);
to_list(L) when is_binary(L) ->
    binary_to_list(L).
