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
	rm -rf manifests/

.PHONY: catalogSource
catalogSource:
	# create CatalogSource yaml
	mkdir -p manifests/
	cp ${TEMPLATE_CS} ${DEST_CS}
	sed -i "s/#IMAGE_REGISTRY#/${IMAGE_REGISTRY}/g" ${DEST_CS}
	sed -i "s/#IMAGE_REPOSITORY#/${IMAGE_REPOSITORY}/g" ${DEST_CS}
	sed -i "s/#IMAGE_NAME#/${IMAGE_NAME}/g" ${DEST_CS}
	sed -i "s/#CATALOG_NAMESPACE#/${CATALOG_NAMESPACE}/g" ${DEST_CS}
	sed -i "s/#CHANNEL#/${CHANNEL}/g" ${DEST_CS}
	sed -i "s/#GIT_SHA#/${GIT_SHA}/g" ${DEST_CS}

.PHONY: operatorManifests
operatorManifests:
	# create Subscription yaml (many)
	mkdir -p manifests/
	PSN=0; while true; do \
		OPERATOR=`cat operators.json | jq -r .[$${PSN}]`; \
		if [ "$${OPERATOR}" == "null" ]; then \
			break; \
		fi; \
		OPERATOR_NAME=`echo "$$OPERATOR" | jq -r .name`; \
		OPERATOR_NAMESPACE=`echo "$$OPERATOR" | jq -r .namespace`; \
		DEST_NS=manifests/01_$${OPERATOR_NAME}.Namespace.yaml; \
		DEST_GRP=manifests/02_$${OPERATOR_NAME}.OperatorGroup.yaml; \
		DEST_SUB=manifests/03_$${OPERATOR_NAME}.Subscription.yaml; \
		cp templates/template_operator.Namespace.yaml $$DEST_NS; \
		cp templates/template_operator.OperatorGroup.yaml $$DEST_GRP; \
		cp templates/template_operator.Subscription.yaml $$DEST_SUB; \
		sed -i "s/#IMAGE_REGISTRY#/${IMAGE_REGISTRY}/g" $$DEST_SUB $$DEST_GRP $$DEST_NS; \
		sed -i "s/#IMAGE_REPOSITORY#/${IMAGE_REPOSITORY}/g" $$DEST_SUB $$DEST_GRP $$DEST_NS; \
		sed -i "s/#IMAGE_NAME#/${IMAGE_NAME}/g" $$DEST_SUB $$DEST_GRP $$DEST_NS; \
		sed -i "s/#CATALOG_NAMESPACE#/${CATALOG_NAMESPACE}/g" $$DEST_SUB $$DEST_GRP $$DEST_NS; \
		sed -i "s/#CHANNEL#/${CHANNEL}/g" $$DEST_SUB $$DEST_GRP $$DEST_NS; \
		sed -i "s/#GIT_SHA#/${GIT_SHA}/g" $$DEST_SUB $$DEST_GRP $$DEST_NS; \
		sed -i "s/#OPERATOR_NAME#/$${OPERATOR_NAME}/g" $$DEST_SUB $$DEST_GRP $$DEST_NS; \
		sed -i "s/#OPERATOR_NAMESPACE#/$${OPERATOR_NAMESPACE}/g" $$DEST_SUB $$DEST_GRP $$DEST_NS; \
		((PSN+=1)); \
	done

.PHONY: build
build: clean catalogSource operatorManifests
	docker build -f ${DOCKERFILE} --tag "${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}/${IMAGE_NAME}:${CHANNEL}-${GIT_SHA}" .

.PHONY: push
push:
	docker push "${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}/${IMAGE_NAME}:${CHANNEL}-${GIT_SHA}"


