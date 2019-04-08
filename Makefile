SHELL := /usr/bin/env bash

# Include project specific values file
# Requires the following variables:
# - CATALOG_NAMESPACE
# - DOCKERFILE
# - CHANNEL
# - IMAGE_REGISTRY
# - IMAGE_REPOSITORY
# - IMAGE_NAME
# - VERSION_MAJOR
# - VERSION_MINOR
include project.mk

# Validate variables in project.mk exist
ifndef CATALOG_NAMESPACE
$(error CATALOG_NAMESPACE is not set; check project.mk file)
endif
ifndef DOCKERFILE
$(error DOCKERFILE is not set; check project.mk file)
endif
ifndef CHANNEL
$(error CHANNEL is not set; check project.mk file)
endif
ifndef IMAGE_REGISTRY
$(error IMAGE_REGISTRY is not set; check project.mk file)
endif
ifndef IMAGE_REPOSITORY
$(error IMAGE_REPOSITORY is not set; check project.mk file)
endif
ifndef IMAGE_NAME
$(error IMAGE_NAME is not set; check project.mk file)
endif
ifndef VERSION_MAJOR
$(error VERSION_MAJOR is not set; check project.mk file)
endif
ifndef VERSION_MINOR
$(error VERSION_MINOR is not set; check project.mk file)
endif

TEMPLATE_CS=templates/template_osd-operators.CatalogSource.yaml
DEST_CS=manifests/00_osd-operators.CatalogSource.yaml

GIT_SHA=$(shell git rev-parse HEAD | cut -c1-8)
SUBSCRIPTIONS=$(shell cat subscriptions.json)
TEMP_DIR:=$(shell mktemp -d)

ALLOW_DIRTY_CHECKOUT?=false

.PHONY: default
default: build

.PHONY: clean
clean:
	# clean generated osd-operators manifests
	rm -rf manifests/
	# clean generated catalog
	git clean -df catalog-manifests/
	# revert packages
	git checkout catalog-manifests/**/*.package.yaml

.PHONY: cleantemp
cleantemp:
	rm -rf $(TEMP_DIR)

.PHONY: isclean
.SILENT: isclean
isclean:
	(test "$(ALLOW_DIRTY_CHECKOUT)" != "false" || test 0 -eq $$(git status --porcelain | wc -l)) || (echo "Local git checkout is not clean, commit changes and try again." && exit 1)

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
		./scripts/gen_operator_csv.py $$DIR $$OPERATOR_NAME $$OPERATOR_NAMESPACE $$OPERATOR_VERSION $(IMAGE_REGISTRY)/$(IMAGE_REPOSITORY)/$$OPERATOR_NAME:v$$OPERATOR_VERSION $(CHANNEL); \
	done

.PHONY: build
build: isclean get-operator-source manifests bundles
	docker build -f ${DOCKERFILE} --tag "${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}/${IMAGE_NAME}:${CHANNEL}-${GIT_SHA}" .

.PHONY: push
push:
	docker push "${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}/${IMAGE_NAME}:${CHANNEL}-${GIT_SHA}"

.PHONY: git-commit
git-commit: build cleantemp
	git add catalog-manifests/
	git commit -m "New catalog: $(CHANNEL)-$(GIT_SHA)" --author="OpenShift SRE <aos-sre@redhat.com>"

.PHONY: git-push
git-push:
	git push