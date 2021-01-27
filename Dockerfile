FROM alpine as base

COPY ./docker/recipes /recipes
RUN apk update && apk add bash && /recipes/install_tools_if_needed.sh

FROM base

COPY ./iaas /bedrock/iaas
COPY ./paas /bedrock/paas
COPY ./saas /bedrock/saas
COPY ./recipes /bedrock/recipes
COPY ./ci /bedrock/ci

ENTRYPOINT [ "/bin/bash", "-c" ]
