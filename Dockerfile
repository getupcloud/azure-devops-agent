# https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/docker?view=azure-devops

FROM ubuntu:18.04

# To make it easier for build and release pipelines to run apt-get,
# configure apt to not require confirmation (assume the -y argument by default)
ENV DEBIAN_FRONTEND=noninteractive
RUN echo "APT::Get::Assume-Yes \"true\";" > /etc/apt/apt.conf.d/90assumeyes

RUN apt-get update \
&& apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        jq \
        git \
        iputils-ping \
        libcurl4 \
        libicu60 \
        libunwind8 \
        netcat

ARG BUILD_DATE
ARG GIT_COMMIT
ARG GIT_COMMIT_ID
ARG VERSION

ENV BUILD_DATE=${BUILD_DATE} \
    GIT_COMMIT=${GIT_COMMIT} \
    GIT_COMMIT_ID=${GIT_COMMIT_ID} \
    VERSION=${VERSION}

WORKDIR /azp

COPY ./start.sh ./setup-kubectl.sh ./
RUN chmod +x start.sh setup-kubectl.sh

CMD ["./start.sh"]
