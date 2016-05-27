export GO15VENDOREXPERIMENT:=1
export CGO_ENABLED:=0
export GOARCH:=amd64

GOFILES:=$(shell find . -name '*.go' | grep -v -E '(./vendor|internal/templates.go)')
GOPATH_BIN:=$(shell echo ${GOPATH} | awk 'BEGIN { FS = ":" }; { print $1 }')/bin

all: bin/linux/bootkube bin/darwin/bootkube

check: pkg/asset/internal/templates.go
	@find . -name vendor -prune -o -name '*.go' -exec gofmt -s -d {} +
	@go vet $(shell go list ./... | grep -v '/vendor/')
	@go test -v $(shell go list ./... | grep -v '/vendor/')

bin/%/bootkube: $(GOFILES) pkg/asset/internal/templates.go
	mkdir -p $(dir $@)
	GOOS=$* go build -o bin/$*/bootkube github.com/coreos/bootkube/cmd/bootkube

install: bin/$(shell uname | tr A-Z a-z)/bootkube
	cp $< $(GOPATH_BIN)

pkg/asset/internal/templates.go: $(GOFILES)
	mkdir -p $(dir $@)
	go generate pkg/asset/templates_gen.go

#TODO(aaron): Prompt because this is destructive
conformance-%: clean all
	@cd hack/$*-node && vagrant destroy -f
	@cd hack/$*-node && rm -rf cluster
	@cd hack/$*-node && ./bootkube-up
	@sleep 30 # Give addons a little time to start
	@cd hack/$*-node && ./conformance-test.sh

# This will naively try and create a vendor dir from a k8s release
# USE: make vendor VENDOR_VERSION=vX.Y.Z
VENDOR_VERSION = v1.2.1
vendor: vendor-$(VENDOR_VERSION)

vendor-$(VENDOR_VERSION):
	@echo "Creating k8s vendor dir: $@"
	@mkdir -p $@/k8s.io/kubernetes
	@git clone --branch=$(VENDOR_VERSION) --depth=1 https://github.com/kubernetes/kubernetes $@/k8s.io/kubernetes > /dev/null 2>&1
	@cd $@/k8s.io/kubernetes && git checkout $(VENDOR_VERSION) > /dev/null 2>&1
	@cd $@/k8s.io/kubernetes && rm -rf docs examples hack cluster
	@cd $@/k8s.io/kubernetes/Godeps/_workspace/src && mv k8s.io/heapster $(abspath $@/k8s.io) && rmdir k8s.io
	@mv $@/k8s.io/kubernetes/Godeps/_workspace/src/* $(abspath $@)
	@rm -rf $@/k8s.io/kubernetes/Godeps $@/k8s.io/kubernetes/.git

clean:
	rm -rf bin/
	rm -rf pkg/asset/internal

.PHONY: all check clean install vendor pkg/asset/internal/templates.go

