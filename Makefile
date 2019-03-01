.PHONY: all
all: get lint test

.PHONY: get
get:
	dep ensure

.PHONY: test
test:
	go test -v ./tests

.PHONY: lint
lint:
	go list ./... | grep -v vendor | xargs go vet
	go list ./... | grep -v vendor | xargs golint

.PHONY: install
install:
	go get github.com/golang/dep/cmd/dep
	go get golang.org/x/lint/golint

.PHONY: clean
clean:
	rm -rf vendor/