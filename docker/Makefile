IMAGE := baikal-m/spi_builder
TAG := 1.1
SRCROOT := /home/ndz/gitlab
NAME := builder11

all: Dockerfile
	docker image build --build-arg uid=1000 -t $(IMAGE):$(TAG) .
run:
	docker run -it -d -v $(SRCROOT):/home/builder/workspace --name $(NAME) $(IMAGE):$(TAG) /bin/bash
	#docker exec -it $(NAME) /bin/bash
push:
	docker image tag $(IMAGE):$(TAG) gitlab.elpitech.ru:5050/$(IMAGE):$(TAG) 
	docker image push gitlab.elpitech.ru:5050/$(IMAGE):$(TAG) 
