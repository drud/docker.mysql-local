
TAG = $(shell git rev-parse --abbrev-ref HEAD | tr -d '\n')
PREFIX = drud/mysql-local
DIRECTORY = $(shell pwd)


DIRS = 5.7
BASEDIR=./

.PHONY: $(MAKECMDGOALS) $(DIRS) all build test clean container push

all: $(DIRS)

$(MAKECMDGOALS): $(DIRS)

$(DIRS):
	$(MAKE) -C $(addprefix $(BASEDIR),$@) $(MAKECMDGOALS)

