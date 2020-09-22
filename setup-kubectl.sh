#!/bin/bash

function download()
{
    version=${1:-stable}
    if [ $version == stable ]; then
        version=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
    fi
    echo Downloading https://storage.googleapis.com/kubernetes-release/release/${version}/bin/linux/amd64/kubectl
    curl -s -L "https://storage.googleapis.com/kubernetes-release/release/${version}/bin/linux/amd64/kubectl" > /usr/bin/kubectl
    chmod +x /usr/bin/kubectl

    echo -n "Installed kubectl "
    /usr/bin/kubectl version --client --short
}

if ! ${DOWNLOAD_KUBECTL:-true}; then
    echo Ignoring kubectl download by user request
    exit
fi

if [ -n "$KUBERNETES_VERSION" ]; then
    download $KUBERNETES_VERSION
    exit
fi

if [ -z "$KUBERNETES_URL" ] && [ -n "$KUBERNETES_SERVICE_HOST" ] && [ -n "$KUBERNETES_SERVICE_PORT_HTTPS" ]; then
    KUBERNETES_URL=https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT
    echo Running from kubernetes: $KUBERNETES_URL
fi

if [ -n "$KUBERNETES_URL" ]; then
    if [ -z "$CA_CERT" ] && [ -e /var/run/secrets/kubernetes.io/serviceaccount/ca.crt ]; then
        CA_CERT="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
    fi

    if [ -z "$AUTH_TOKEN" ] && [ -e /var/run/secrets/kubernetes.io/serviceaccount/token ]; then
        AUTH_TOKEN="$(</var/run/secrets/kubernetes.io/serviceaccount/token)"
    fi

    if [ -n "$AUTH_BASIC_USERNAME" ] || [ -n "$AUTH_BASIC_PASSWORD" ]; then
        AUTH_BASIC="${AUTH_BASIC_USERNAME}:${AUTH_BASIC_PASSWORD}"
    fi

    KUBERNETES_VERSION=$(curl -Ls --connect-timeout 10 \
        ${NO_VERIFY:+-k} \
        ${CA_CERT:+--cacert $CA_CERT} \
        ${AUTH_TOKEN:+-H "Authorization: Bearer $TOKEN"} \
        ${AUTH_BASIC:+-u "$AUTH_BASIC"} \
        ${AUTH_CLIENT_CERT:+--cert $CLIENT_CERT} \
        ${AUTH_CLIENT_KEY:+--key $CLIENT_KEY} \
        $KUBERNETES_URL/version)

    if [ -z "$KUBERNETES_VERSION" ] || [ "$(echo $KUBERNETES_VERSION | jq -r .status)" == "Failure" ]; then
        echo Unable to retrieve kubernetes version from server $KUBERNETES_URL: $KUBERNETES_VERSION
        download stable
        exit
    fi

    KUBERNETES_VERSION_MAJOR="$(echo "$KUBERNETES_VERSION" | jq -r .major | sed -e 's/[^0-9]//g')"
    KUBERNETES_VERSION_MINOR="$(echo "$KUBERNETES_VERSION" | jq -r .minor | sed -e 's/[^0-9]//g')"
    KUBERNETES_VERSION_GIT="$(echo "$KUBERNETES_VERSION" | jq -r .gitVersion)"
    KUBERNETES_VERSION_CLEAN="$(echo "$KUBERNETES_VERSION_GIT" | sed -ne 's/\(^v[0-9]\+\.[0-9]\+\.[0-9\]\+\).*/\1/gp')" #tnx openshift

    echo Found kubernetes server version $KUBERNETES_VERSION_GIT

    KUBECTL_BIN=${KUBECTL_BIN:-$(which kubectl 2>/dev/null || true)}

    if [ -n "$KUBECTL_BIN" ] && [ -x "$KUBECTL_BIN" ]; then
        KUBECTL_VERSION=$($KUBECTL_BIN version --client -o json)
        KUBECTL_VERSION_MAJOR="$(echo "$KUBECTL_VERSION" | jq -r .clientVersion.major | sed -e 's/[^0-9]//g')"
        KUBECTL_VERSION_MINOR="$(echo "$KUBECTL_VERSION" | jq -r .clientVersion.minor | sed -e 's/[^0-9]//g')"
        KUBECTL_VERSION_GIT=$(echo "$KUBECTL_VERSION" | jq -r .clientVersion.gitVersion)

        echo Found kubectl version $KUBECTL_VERSION_GIT

        if [ "$KUBERNETES_VERSION_MAJOR" == "$KUBECTL_VERSION_MAJOR" ] && [ "$KUBERNETES_VERSION_MINOR" == "$KUBECTL_VERSION_MINOR" ]; then
            echo "Kubectl version $KUBECTL_VERSION_GIT already matches kubernetes server version $KUBERNETES_VERSION_GIT"
            exit
        fi
    fi

    KUBECTL_VERSION_DOWNLOAD=$KUBERNETES_VERSION_CLEAN
fi

download $KUBECTL_VERSION_DOWNLOAD
