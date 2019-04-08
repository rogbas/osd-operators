SHELL := /usr/bin/env bash

GIT_SHA=$(shell git rev-parse HEAD | cut -c1-8)
SUBSCRIPTIONS=$(shell cat subscriptions.json)
TEMP_DIR:=$(shell mktemp -d)

.PHONY: default
default: build

.PHONY: clean
clean:
	# clean generated osd-operators manifests
	rm -rf manifests/

.PHONY: manifests-osd-operators
manifests-osd-operators:
	mkdir -p manifests/
	# create CatalogSource yaml
	TEMPLATE=templates/template_osd-operators.CatalogSource.yaml; \
	DEST=manifests/osd-operators.CatalogSource.yaml; \
	sed -e "s/#IMAGE_REGISTRY#/${IMAGE_REGISTRY}/g" \
		-e "s/#IMAGE_REPOSITORY#/${IMAGE_REPOSITORY}/g" \
		-e "s/#IMAGE_NAME#/${IMAGE_NAME}/g" \
		-e "s/#CATALOG_NAMESPACE#/${CATALOG_NAMESPACE}/g" \
		-e "s/#CHANNEL#/${CHANNEL}/g" \
		-e "s/#GIT_SHA#/${GIT_SHA}/g" \
		-e "s/#OPERATOR_NAME#/$${OPERATOR_NAME}/g" \
		-e "s/#OPERATOR_NAMESPACE#/$${OPERATOR_NAMESPACE}/g" \
		$$TEMPLATE > $$DEST

.PHONY: manifests-operators
manifests-operators: get-operator-source
	# create Subscription yaml (many)
	for DIR in $(TEMP_DIR)/**/; do \
		pushd $$DIR; \
		$(MAKE) -C $$DIR env --no-print-directory; \
		eval $$($(MAKE) -C $$DIR env --no-print-directory); \
		popd; \
		for TYPE in Namespace OperatorGroup Subscription; do \
			TEMPLATE=templates/template_operator.$$TYPE.yaml; \
			DEST=manifests/$${OPERATOR_NAME}.$$TYPE.yaml; \
			sed -e "s/#IMAGE_REGISTRY#/${IMAGE_REGISTRY}/g" \
				-e "s/#IMAGE_REPOSITORY#/${IMAGE_REPOSITORY}/g" \
				-e "s/#IMAGE_NAME#/${IMAGE_NAME}/g" \
				-e "s/#CATALOG_NAMESPACE#/${CATALOG_NAMESPACE}/g" \
				-e "s/#CHANNEL#/${CHANNEL}/g" \
				-e "s/#GIT_SHA#/${GIT_SHA}/g" \
				-e "s/#OPERATOR_NAME#/$${OPERATOR_NAME}/g" \
				-e "s/#OPERATOR_NAMESPACE#/$${OPERATOR_NAMESPACE}/g" \
				$$TEMPLATE > $$DEST; \
		done; \
	done

.PHONY: manifests
manifests: manifests-osd-operators manifests-operators

.PHONY: get-operator-source
get-operator-source:
	pushd $(TEMP_DIR); \
	if [ ! -e "dedicated-admin-operator" ]; then \
		git clone -b master https://github.com/openshift/dedicated-admin-operator.git; \
	else \
		pushd dedicated-admin-operator; \
		git pull; \
		popd; \
	fi; \
	popd

.PHONY: bundles
bundles: get-operator-source
	for DIR in $(TEMP_DIR)/**/; do \
		eval $$($(MAKE) -C $$DIR env --no-print-directory); \
		./scripts/gen_operator_csv.py $$DIR $$OPERATOR_NAME $$OPERATOR_NAMESPACE $$OPERATOR_VERSION $(IMAGE_REGISTRY)/$(IMAGE_REPOSITORY)/$$OPERATOR_NAME:v$$OPERATOR_VERSION; \
	done

.PHONY: build
build: get-operator-source manifests bundles
	docker build -f ${DOCKERFILE} --tag "${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}/${IMAGE_NAME}:${CHANNEL}-${GIT_SHA}" .

.PHONY: push
push:
	docker push "${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}/${IMAGE_NAME}:${CHANNEL}-${GIT_SHA}"
