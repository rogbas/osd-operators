# Project specific values
CATALOG_NAMESPACE?=openshift-operator-lifecycle-manager
DOCKERFILE?=./Dockerfile
CHANNEL?=$(git rev-parse --abbrev-ref HEAD)

TEMPLATE_CS=templates/template_osd-operators.CatalogSource.yaml
DEST_CS=manifests/00_osd-operators.CatalogSource.yaml

# Image specific values
IMAGE_REGISTRY?=quay.io
IMAGE_REPOSITORY?=$(USER)
IMAGE_NAME?=osd-operators-registry

# Version specific values
VERSION_MAJOR?=0
VERSION_MINOR?=1
