all:

sast_shellcheck:
	/bedrock/recipes/sast_shellcheck.sh

sast_json_lint:
	/bedrock/recipes/sast_json_lint.sh

sast_yaml_lint:
	/bedrock/recipes/sast_yaml_lint.sh

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


# /bedrock/recipes/clone_neuvector.sh" 'cf'
