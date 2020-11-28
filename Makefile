.DEFAULT_GOAL := error

ifdef NO_SAM_BUILD_USE_CONTAINER
  SAM_CONTAINER_FLAG=
else
  SAM_CONTAINER_FLAG=--use-container
endif

ifdef NO_PIPENV
  PIPENV=exit 0 \# # don't judge me ...
  PIPENV_RUN=
else
  PIPENV=pipenv
  PIPENV_RUN=pipenv run
endif

ifeq "$(origin CONFIG-ENV)" "environment"
$(error "CONFIG-ENV is (somehow!) set as an environment variable; see the README for why this isn't allowed.")
endif

.PHONY: clean
clean:
	rm -rf \
	  .aws-sam/ \
	  requirements.txt \
	  lambda-layers/DependenciesLayer/requirements.txt \
	  lambda-deployment-api-gateway-url.txt \
	  sam-deploy-output.txt

.PHONY: test
test: sam-validate-template

.PHONY: sam-validate-template
sam-validate-template: export AWS_DEFAULT_REGION=eu-west-2
sam-validate-template:
	$(PIPENV_RUN) sam validate

.PHONY: smoke-test-lambda-deploy
smoke-test-lambda-deploy: lambda-deployment-api-gateway-url.txt
	@cat lambda-deployment-api-gateway-url.txt | xargs --max-args 1 --verbose curl --fail
lambda-deployment-api-gateway-url.txt: sam-deploy-output.txt
	@cat sam-deploy-output.txt | awk '$$1=="Value" && $$2 ~ "^https://"{print $$2}' >$@

.PHONY: local-server
local-server: check-config-env .aws-sam/build/local-server-template.yaml
	$(PIPENV_RUN) sam local start-api --config-env $(CONFIG-ENV) --config-file $(CURDIR)/samconfig.toml --template-file .aws-sam/build/local-server-template.yaml # --debug

.PHONY: build
build: requirements.txt lambda-layers/DependenciesLayer/requirements.txt
	$(PIPENV_RUN) sam build $(SAM_CONTAINER_FLAG)

.aws-sam/build/local-server-template.yaml: template.yaml lambda-layers/DependenciesLayer/requirements.txt
	$(PIPENV_RUN) sam build DependenciesLayer $(SAM_CONTAINER_FLAG)
	mv .aws-sam/build/template.yaml .aws-sam/build/local-server-template.yaml
lambda-layers/DependenciesLayer/requirements.txt: Pipfile Pipfile.lock
	$(PIPENV) lock -r | sed "s/^-e //" >$@
requirements.txt:
	@echo "# This file is intentionally left empty by Makefile:requirements.txt" >requirements.txt

.PHONY: check-config-env
check-config-env:
	@fgrep -q "[$(CONFIG-ENV)]" samconfig.toml || { echo "Config env '$(CONFIG-ENV)' not found in samconfig.toml"; exit 1; }

#SOURCE_FILES?=$(shell rsync --exclude-from="$(SAM_IGNORE_FILE)" --dry-run --ignore-times --checksum-choice=none --whole-file --recursive ./ --list-only | tr -s ' ' | grep -v ^d | cut -f5- -d' ')
#
#logs:
#	sam logs --stack-name Django-Test-App --name HelloWorldFunction
#tail:
#	sam logs --stack-name Django-Test-App --name HelloWorldFunction --tail
#
#$(SAM_INPUT_DIR)/AggregatorApi: $(SOURCE_FILES) $(SAM_IGNORE_FILE)
#	@mkdir -p $@
#	rsync $(RSYNC_EXTRA_FLAGS) \
#	  --info COPY,DEL,NAME,SYMSAFE,SKIP \
#	  --archive --delete --delete-excluded \
#	  --exclude="$(SAM_INPUT_DIR)" --exclude="$(SAM_OUTPUT_DIR)" \
#	  --exclude-from="$(SAM_IGNORE_FILE)" --exclude="$(SAM_IGNORE_FILE)" \
#	  ./ $@/
#	echo >$@/requirements.txt # this zeros out any existing requirements.txt
#	@touch $@
#
