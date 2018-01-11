PROJECT = emqx_management
PROJECT_DESCRIPTION = EMQ X Management API and CLI
PROJECT_VERSION = 2.4.1
PROJECT_MOD = emqx_mgmt_app

DEPS = minirest clique
dep_minirest = git https://github.com/emqx/minirest master
dep_clique   = git https://github.com/emqtt/clique

LOCAL_DEPS = mnesia

BUILD_DEPS = emqx cuttlefish
dep_emqx = git git@github.com:emqx/emqx-enterprise chinatelecom
dep_cuttlefish = git https://github.com/emqtt/cuttlefish

NO_AUTOPATCH = cuttlefish

ERLC_OPTS += +debug_info
ERLC_OPTS += +'{parse_transform, lager_transform}'

COVER = true

include erlang.mk

app:: rebar.config

app.config::
	./deps/cuttlefish/cuttlefish -l info -e etc/ -c etc/emqx_management.conf -i priv/emqx_management.schema -d data
