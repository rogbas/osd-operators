SHELL := /usr/bin/env bash

# build the registry image
IMAGE_REGISTRY?=quay.io
IMAGE_REPOSITORY?=openshift-sre
IMAGE_NAME?=osd-operators
CATALOG_NAMESPACE?=openshift-operator-lifecycle-manager
DOCKERFILE?=./Dockerfile
CHANNEL?=production
GIT_SHA=$(shell git rev-parse HEAD | cut -c1-8)

TEMPLATE_CS=templates/template_osd-operators.CatalogSource.yaml
DEST_CS=manifests/00_osd-operators.CatalogSource.yaml

SUBSCRIPTIONS=$(shell cat subscriptions.json)

.PHONY: default
default: build

.PHONY: clean
clean:
	# clean generated osd-operators manifests
	rm -rf manifests/
	# clean submodules checkouts
	rm -rf operators/**/

.PHONY: manifests
manifests:
	mkdir -p manifests/
	# create CatalogSource yaml
	for TYPE in CatalogSource; do \
		TEMPLATE=templates/template_osd-operators.$$TYPE.yaml; \
		DEST=manifests/osd-operators.$$TYPE.yaml; \
		sed -e "s/#IMAGE_REGISTRY#/${IMAGE_REGISTRY}/g" \
			-e "s/#IMAGE_REPOSITORY#/${IMAGE_REPOSITORY}/g" \
			-e "s/#IMAGE_NAME#/${IMAGE_NAME}/g" \
			-e "s/#CATALOG_NAMESPACE#/${CATALOG_NAMESPACE}/g" \
			-e "s/#CHANNEL#/${CHANNEL}/g" \
			-e "s/#GIT_SHA#/${GIT_SHA}/g" \
			-e "s/#OPERATOR_NAME#/$${OPERATOR_NAME}/g" \
			-e "s/#OPERATOR_NAMESPACE#/$${OPERATOR_NAMESPACE}/g" \
			$$TEMPLATE > $$DEST; \
	done

	# create Subscription yaml (many)
	PSN=0; while true; do \
		OPERATOR=$$(cat operators/metadata.json | jq -r .[$${PSN}]); \
		if [ "$${OPERATOR}" == "null" ]; then \
			break; \
		fi; \
		OPERATOR_NAME=$$(echo "$$OPERATOR" | jq -r .name); \
		OPERATOR_NAMESPACE=$$(echo "$$OPERATOR" | jq -r .namespace); \
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
		((PSN+=1)); \
	done

.PHONY: submodules
submodules:
	git submodule init
	git submodule update

.PHONY: bundles
bundles: submodules
	for DIR in operators/**/; do \
		eval $$($(MAKE) -C $$DIR env | grep -v ^make); \
		./scripts/gen_operator_csv.py $$DIR $$OPERATOR_NAME $$OPERATOR_NAMESPACE $$OPERATOR_VERSION $(IMAGE_REGISTRY)/$(IMAGE_REPOSITORY)/$$OPERATOR_NAME:v$$OPERATOR_VERSION; \
	done

.PHONY: build
build: submodules manifests bundles
	docker build -f ${DOCKERFILE} --tag "${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}/${IMAGE_NAME}:${CHANNEL}-${GIT_SHA}" .

.PHONY: push
push:
	docker push "${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}/${IMAGE_NAME}:${CHANNEL}-${GIT_SHA}"


