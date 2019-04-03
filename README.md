# To generate/deploy a catalog image
Make sure you have local changes committed.

```console
make build push
oc apply -f manifests/
```

Note there are some env vars you can override.  For example, to push to a personal quay.io repository:
```console
IMAGE_REPOSITORY=nmalik make build push
```