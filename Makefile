SHELL := /bin/bash

IMAGE     ?= devenv:latest
NET_IMAGE ?= devenv-netguard:latest
export IMAGE NET_IMAGE MODEL NET COND MIRROR OFF_PROTOCOL PROMPT_FILE

.PHONY: build probe run collect audit

build:
	scripts/build.sh

probe:
	scripts/probe.sh

run:
	scripts/run.sh

# RUN=runs/run-NN (default: latest run)
collect:
	scripts/collect.sh $(RUN)

audit:
	scripts/audit.sh $(RUN)
