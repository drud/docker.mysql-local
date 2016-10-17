
TAG = $(shell git rev-parse --abbrev-ref HEAD | tr -d '\n')
PREFIX = drud/mysql-docker-local
DIRECTORY = $(shell pwd)

dev55:
	docker build -t $(PREFIX):5.5-$(TAG) $(DIRECTORY)/5.5
	docker push $(PREFIX):5.5-$(TAG)

dev56:
	docker build -t $(PREFIX):5.6-$(TAG) $(DIRECTORY)/5.6
	docker push $(PREFIX):5.6-$(TAG)

dev57:
	docker build -t $(PREFIX):5.7-$(TAG) $(DIRECTORY)/5.7
	docker push $(PREFIX):5.7-$(TAG)

latest55:
	docker build -t $(PREFIX):5.5 $(DIRECTORY)/5.5
	docker push $(PREFIX):5.5

latest56:
	docker build -t $(PREFIX):5.6 $(DIRECTORY)/5.6
	docker push $(PREFIX):5.6

latest57:
	docker build -t $(PREFIX):5.7 $(DIRECTORY)/5.7
	docker push $(PREFIX):5.7

dev: dev55 dev56 dev57

latest: latest55 latest56 latest57
