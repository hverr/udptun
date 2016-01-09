.PHONY: all container

CONTAINER_NAME=udptun_deb
VERSION=0.1-beta

ARCH=$(shell uname -m)

all: container
	docker run \
		--rm \
		--env VERSION=$(VERSION) \
		$(CONTAINER_NAME) > udptun_$(VERSION)_$(ARCH).deb

container:
	cd .. && make
	cat ../udptun.native > udptun
	chmod 0755 udptun
	docker build -t $(CONTAINER_NAME) .
	rm udptun
