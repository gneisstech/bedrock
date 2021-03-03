FROM alpine as base
ENV BEDROCK_DOCKER="true" K8S_RELEASE="v1.20.2" YQ_RELEASE="v4.6.1" JQ_RELEASE="jq-1.6"

COPY docker/recipes /recipes
RUN apk update && apk add bash && /recipes/install_tools_if_needed.sh

FROM base
ENV BEDROCK_DOCKER="true"

COPY --from=golang:1.16-alpine /usr/local/go/ /usr/local/go/
ENV PATH="/usr/local/go/bin:${PATH}"

COPY iaas /bedrock/iaas
COPY paas /bedrock/paas
COPY saas /bedrock/saas
COPY recipes /bedrock/recipes
COPY Makefile /bedrock/Makefile
WORKDIR /src

ENTRYPOINT [ "/usr/bin/make", "-f", "/bedrock/Makefile" ]
