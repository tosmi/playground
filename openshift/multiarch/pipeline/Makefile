.PHONY: taskrun logs

.DEFAULT_GOAL := taskrun

taskrun:
	-tkn tr delete -f multiarch-manifest-create
	oc apply -f taskrun-multiarch-manifest.yaml

logs:
	tkn tr logs multiarch-manifest-create







