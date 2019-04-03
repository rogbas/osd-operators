FROM quay.io/openshift/origin-operator-registry:latest

COPY operators manifests
RUN initializer

CMD ["registry-server", "-t", "/tmp/terminate.log"]
