FROM alpine as base
ENV BEDROCK_DOCKER="true" K8S_RELEASE="v1.20.2" YQ_RELEASE="2.4.0" JQ_RELEASE="jq-1.6"

COPY ./docker/recipes /recipes
RUN apk update && apk add bash && /recipes/install_tools_if_needed.sh

FROM base
ENV BEDROCK_DOCKER="true"

COPY ./iaas /bedrock/iaas
COPY ./paas /bedrock/paas
COPY ./saas /bedrock/saas
COPY ./recipes /bedrock/recipes
COPY ./ci /bedrock/ci

ENTRYPOINT [ "/bin/bash", "-c" ]
