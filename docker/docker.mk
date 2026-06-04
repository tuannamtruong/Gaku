IMAGE_TAG     ?= latest
DOCKERHUB_REPO ?= $(DOCKERHUB_USERNAME)

_docker_build_args = \
    --build-arg GIT_COMMIT=$$(git rev-parse HEAD) \
    --build-arg BUILD_NUMBER=$(IMAGE_TAG) \
    --build-arg BUILD_TIMESTAMP=$$(date -u +%Y-%m-%dT%H:%M:%SZ)

docker_build_api:
	docker build $(_docker_build_args) \
	    --network=host \
	    -f docker/Dockerfile.Gaku.Api \
	    -t gaku-api:$(IMAGE_TAG) -t gaku-api:latest \
	    .

docker_build_web:
	docker build $(_docker_build_args) \
	    --network=host \
	    -f docker/Dockerfile.Gaku.Web \
	    -t gaku-web:$(IMAGE_TAG) -t gaku-web:latest \
	    .

docker_build_migrator:
	docker build $(_docker_build_args) \
	    --network=host \
	    -f docker/Dockerfile.Migrator \
	    -t gaku-migrator:$(IMAGE_TAG) -t gaku-migrator:latest \
	    .

docker_build: docker_build_api docker_build_web docker_build_migrator

docker_login:
	@echo "$(DOCKERHUB_TOKEN)" | docker login -u $(DOCKERHUB_USERNAME) --password-stdin

docker_push: docker_login
	docker tag gaku-api:$(IMAGE_TAG)      $(DOCKERHUB_REPO)/gaku-api:$(IMAGE_TAG)
	docker tag gaku-api:latest            $(DOCKERHUB_REPO)/gaku-api:latest
	docker tag gaku-web:$(IMAGE_TAG)      $(DOCKERHUB_REPO)/gaku-web:$(IMAGE_TAG)
	docker tag gaku-web:latest            $(DOCKERHUB_REPO)/gaku-web:latest
	docker tag gaku-migrator:$(IMAGE_TAG) $(DOCKERHUB_REPO)/gaku-migrator:$(IMAGE_TAG)
	docker tag gaku-migrator:latest       $(DOCKERHUB_REPO)/gaku-migrator:latest
	docker push $(DOCKERHUB_REPO)/gaku-api:$(IMAGE_TAG)
	docker push $(DOCKERHUB_REPO)/gaku-api:latest
	docker push $(DOCKERHUB_REPO)/gaku-web:$(IMAGE_TAG)
	docker push $(DOCKERHUB_REPO)/gaku-web:latest
	docker push $(DOCKERHUB_REPO)/gaku-migrator:$(IMAGE_TAG)
	docker push $(DOCKERHUB_REPO)/gaku-migrator:latest
