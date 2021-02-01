default: help list

.NOTPARALLEL:
.SECONDEXPANSION:

sast_shellcheck:
	/bedrock/recipes/sast_shellcheck.sh

sast_json_lint:
	/bedrock/recipes/sast_json_lint.sh

sast_yaml_lint:
	/bedrock/recipes/sast_yaml_lint.sh

sast_neuvector_scan:
	@echo "Not Implemented Yet"

sast_blackduck_scan:
	@echo "Not Implemented Yet"

deploy_cluster:
	/bedrock/recipes/deploy_environment_cluster.sh "${BEDROCK_CLUSTER}"

purge_cluster:
	/bedrock/recipes/purge_environment_cluster.sh "${BEDROCK_CLUSTER}"

login_cluster_registry:
	/bedrock/recipes/login_cluster_registry.sh "${BEDROCK_CLUSTER}"

copy_upstream_to_cluster_k8s:
	/bedrock/recipes/promote_k8s_from_env_to_env.sh "${BEDROCK_UPSTREAM_CLUSTER}" "${BEDROCK_CLUSTER}"

publish_packaged_chart_for_cluster:
	/bedrock/recipes/publish_packaged_chart_to_env.sh "${BEDROCK_CLUSTER}"

deploy_umbrella_chart_to_cluster:
	/bedrock/recipes/deployment_helm_update.sh "${BEDROCK_CLUSTER}"

deploy_dashboard_to_cluster:
	/bedrock/paass/recipes/deploy_dashboard.sh "${BEDROCK_CLUSTER}"

deploy_datadog_to_cluster:
	/bedrock/paass/recipes/deploy_datadog.sh "${BEDROCK_CLUSTER}"

deploy_neuvector_to_cluster:
	/bedrock/paass/recipes/deploy_neuvector.sh "${BEDROCK_CLUSTER}"

init_service_tree:
	@echo "Not Implemented Yet"

install_service_pipelines:
	@echo "Not Implemented Yet"

init_app_tree:
	@echo "Not Implemented Yet"

install_app_pipelines:
	@echo "Not Implemented Yet"

trace_environment:
	@echo "Not Implemented Yet"

bless_artifacts:
	@echo "Not Implemented Yet"

check_keyvault_access:
	@echo "Not Implemented Yet"

seed_secrets:
	# copy secrets from external keyvaults
	@echo "Not Implemented Yet"

seed_artifacts:
	# copy helm charts and docker containers from external registries
	@echo "Not Implemented Yet"

get_k8s_credentials:
	@echo "Not Implemented Yet - retrieves credentials if you have access"

get_k8s_admin_credentials:
	@echo "Not Implemented Yet - retrieves admin credentials if you have access"

get_k8s_ssh_credentials:
	@echo "Not Implemented Yet - retrieves ssh credentials if you have access"

scale_create_nodepool:
	@echo "Not Implemented Yet - adds a nodepool to the cluster"

scale_delete_nodepool:
	@echo "Not Implemented Yet - delete a nodepool from the cluster"

scale_update_nodepool_add_node:
	@echo "Not Implemented Yet - adds a node to the nodepool in the cluster"

scale_update_nodepool_remove_node:
	@echo "Not Implemented Yet - delete a node from a nodepool in the cluster"

#
#####################################################################################

export MAKEFILE_TOPLEVEL:=$(lastword $(MAKEFILE_LIST))

settings:
	@$(foreach v, $(.VARIABLES), \
		(echo "export $(v) = $($(v))" | grep BEDROCK_ | grep -v ".VARIABLES"; true ); \
	)

help :
	@echo 'Configuration and installation of developer tools for particular runtime environments'
	@echo ''
	@echo 'Environment Variables that contribute to the build:'
	@echo 'DD_CLIENT_API_KEY:           datadog api key for observability during builds'
	@echo 'DD_CLIENT_APP_KEY:           datadog app key for observability during builds'
	@echo 'BEDROCK_DEPLOYMENT_CATALOG:  yaml file with catalog of cluster metadata'
	@echo 'BEDROCK_CLUSTER:             name of cluster to use in makefile target recipe'
	@echo 'BEDROCK_CLUSTER_DIR:         subdir, relative to $repo_root, to look for config files'
	@echo '* pipeline variables from your CI build provider'
	@echo '** Azure Pipelines: AGENT_* BUILD_* COMMON_* PIPELINE_* ENVIRONMENT_* SYSTEM_* ENDPOINT_* TF_BUILD'
	@echo ''
	@echo 'Variables may be set either as shell variables before the make command, or'
	@echo 'as make variables specified after the make command but before makefile targets'
	@echo ''
	@echo 'Examples:'
	@echo '	1) "BEDROCK_CLUSTER=cluster_name BEDROCK_DEPLOYMENT_CATALOG=catalog_name make deploy_datadog_to_cluster"'
	@echo '	2) "make BEDROCK_CLUSTER=cluster_name BEDROCK_DEPLOYMENT_CATALOG=catalog_name deploy_datadog_to_cluster"'
	@echo ''

printvars:
	$(foreach V, $(sort $(.VARIABLES)), $(if $(filter-out default automatic, $(origin $V)), $(warning $V=$($V) ($(value $V)))))

list :
	@echo '#######################'
	@echo '#### available top level make targets:'
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_TOPLEVEL)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | xargs -n1
	@echo '#######################'
