# Restore SD-Core

Restoring SD-Core from a backup currently requires a full redeployment of the
control plane. This guide lays out the steps required to successfully restore
from a backup.

## Destroy previous control plane model

If the control plane was deployed to a model named `core`, it will need to
first be completely removed:

```bash
juju destroy-model --destroy-storage --force --no-wait core
```

## Recreate the model

```bash
juju add-model core
```

## Deploy `mongodb-k8s`

```bash
juju deploy mongodb-k8s --channel 6/stable
```

## Follow the restore procedure

Use this [procedure](https://charmhub.io/mongodb-k8s/docs/h-restore-backup?channel=6/stable)
to restore the backup.

## Redeploy the bundle

Use the same steps you used for the initial deployment to redeploy the bundle.
For example, if you deployed the complete SD-Core bundle, you would use the
following command:

```bash
juju deploy sdcore-k8s --trust --channel=beta
```
