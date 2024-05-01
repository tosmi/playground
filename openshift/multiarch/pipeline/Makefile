.PHONY: taskrun logs

.DEFAULT_GOAL := help

TASK_RUN := multiarch-manifest-create

###############
# Help Target #
###############
.PHONY: help
help: ## Show this help screen
	@echo 'Usage: make <OPTIONS> ... <TARGETS>'
	@echo ''
	@echo 'Available targets are:'
	@echo ''
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

taskrun: ## create the multiarch-manifest-create taskrun for testing
	-tkn tr delete -f $(TASK_RUN)
	oc apply -f taskrun-multiarch-manifest.yaml

logs: ## show logs of the multiarch-mannifest-create taskrun
	tkn tr logs $(TASKRUN)

registry-secret: ## create required registry secret for pushing the multiarch manifest
	oc create secret docker-registry registry-$(REGISTRY)\
 		--docker-username=$(REGISTRY_USERNAME) \
 		--docker-password=$(REGISTRY_PASSWORD) \
 		--docker-email=$(REGISTRY_EMAIL) \
 		--docker-server=$(REGISTRY)

	oc secret link pipeline registry-$(REGISTRY)