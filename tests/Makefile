.PHONY: all container

CONTAINER_NAME=udptun

all: container

container:
	cd .. && make
	cat ../udptun.native > udptun
	chmod 0755 udptun
	docker build -t $(CONTAINER_NAME) .
	rm udptun
