# Backup SD-Core

Backups of SD-Core are managed through the `mongodb-k8s` charm. This guide
highlights the steps required by referencing that charm's documentation.

## Integrate Mongo with S3

`mongodb-k8s` saves backup to S3 compatible storage. The first step is to
[configure S3 storage](https://charmhub.io/mongodb-k8s/docs/h-configure-s3?channel=6/beta).

## Save the cluster password

The restore procedure currently only works with a full redeployment. For this
reason, the Mongo cluster password will be required.

```bash
juju run mongodb-k8s/leader get-password
```

Save the password in a safe place.

## Create and list backups

`mongodb-k8s` is now ready to
[create and list backups](https://charmhub.io/mongodb-k8s/docs/h-create-backup?channel=6/beta).
