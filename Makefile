VERSION := v0.1.0
REPOSITORY := getupcloud
IMAGE_NAME := azure-devops-agent
GIT_COMMIT := $(shell git log -n1 --oneline)
GIT_COMMIT_ID := $(shell git log -n 1 --pretty=format:%h)
BUILD_DATE := $(shell LC_ALL=C date -u)

.PHONY: default
default: image

.PHONY: release
release: DOCKER_NO_CACHE:=--no-cache
release: check-dirty image tag-latest push push-latest

.PHONY: image
image:
	docker build . -t $(REPOSITORY)/$(IMAGE_NAME):$(VERSION) $(DOCKER_NO_CACHE) \
        --build-arg VERSION="$(VERSION)" \
        --build-arg BUILD_DATE="$(BUILD_DATE)" \
        --build-arg GIT_COMMIT="$(GIT_COMMIT)" \
        --build-arg GIT_COMMIT_ID="$(GIT_COMMIT_ID)" \
        --build-arg COMPILE="$(COMPILE)"

check-dirty: DIFF_STATUS := $(shell git diff --stat)
check-dirty:
	@if [ -n "$(DIFF_STATUS)" ]; then \
	  echo "--> Refusing to build release on a dirty tree"; \
	  echo "--> Commit and try again."; \
	  exit 2; \
	fi

.PHONY: push
push:
	docker push $(REPOSITORY)/$(IMAGE_NAME):$(VERSION)

.PHONY: tag-latest
tag-latest:
	docker tag $(REPOSITORY)/$(IMAGE_NAME):$(VERSION) $(REPOSITORY)/$(IMAGE_NAME):latest

.PHONY: push-latest
push-latest:
	docker push $(REPOSITORY)/$(IMAGE_NAME):latest
