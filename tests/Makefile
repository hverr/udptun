.PHONY: all container

all: container

container:
	cd .. && make
	cat ../udptun.native > udptun
	chmod 0755 udptun
	docker build -t udptun .
	rm udptun
