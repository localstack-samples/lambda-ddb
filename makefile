SHELL := /bin/bash

PROJECT_MODULE_NAME = ./src/lambda-hello-name/src/

-include .env-gdc-local
-include ./devops-tooling/envs.makefile
-include ./devops-tooling/nonenv.makefile
-include ./devops-tooling/sandboxenv.makefile
-include ./devops-tooling/awscdk.makefile

# Some defaults
export SBX_ACCOUNT_CONFIG?=devops-tooling/accounts/my-sb.json
export ENFORCE_IAM?=1
export PERSIST_ALL?=false

.PHONY: clean update-deps delete-zips iac-shared local-top-level local-awscdk-output reset-ls

PKG_SUB_DIRS := $(dir $(shell find . -type d -name node_modules -prune -o -type d -name "venv*" -prune -o -type f -name package.json -print))

update-deps: $(PKG_SUB_DIRS)
	for i in $(PKG_SUB_DIRS); do \
        pushd $$i && ncu -u && npm install && popd; \
    done

iac-shared:
	pushd iac/iac-shared && npm install && npm run build && popd

build:
	cd src/lambda-hello-name && rm -f lambda.zip
	cd src/lambda-hello-name && npm install
	cd src/lambda-hello-name && npm run build
	cd src/lambda-hello-name && npm prune --omit=dev
	mkdir -p src/lambda-hello-name/bundle
	cp -r src/lambda-hello-name/dist/* src/lambda-hello-name/bundle
	cp -r src/lambda-hello-name/node_modules src/lambda-hello-name/bundle
	cd src/lambda-hello-name/bundle &&  zip -r ../lambda.zip *
	#cd src/lambda-hello-name &&  zip -r ../lambda.zip node_modules/*

# Hot reloading watching to run build
watch-lambda:
	cd src/lambda-hello-name && npm run watch

# Run the tests
test: venv
	$(VENV_RUN) && cd auto_tests && AWS_PROFILE=localstack pytest $(ARGS);

reset-ls:
	curl -X POST -H "Content-Type: application/json" localhost.localstack.cloud:4566/_localstack/health -d '{"action":"restart"}'