IMAGE := bullseye-builder
TAG := 1.0
SRCROOT := /home/ndz/gitlab
NAME := builder11

all: Dockerfile
	docker image build --build-arg uid=1000 -t $(IMAGE):$(TAG) .
run:
	docker run -it -d -v $(SRCROOT):/home/builder/workspace --name $(NAME) $(IMAGE):$(TAG) /bin/bash
	#docker exec -it $(NAME) /bin/bash
push:
	docker image tag $(IMAGE):$(TAG) xxor/$(IMAGE):$(TAG) 
	docker image push xxor/$(IMAGE):$(TAG) 
