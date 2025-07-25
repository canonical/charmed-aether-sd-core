# Troubleshoot deployment issues

This guide provides step-by-step troubleshooting actions to remediate deployment issues. We hope you don't need this guide. If you encounter an issue and aren't able to address it via this guide, please raise an issue [here][Bug Report].

## 1. Terraform failed to deploy the Charmed Aether SD-Core with `Unable to create model` error

### Symptoms

The `terraform apply -auto-approve` command fails with an error indicating that the Juju model could not be created:

```console
Plan: 72 to add, 0 to change, 0 to destroy.
juju_model.private5g: Creating...
│ Error: Client Error
│   with juju_model.private5g,
│   on main.tf line 1, in resource "juju_model" "private5g":
│    1: resource "juju_model" "private5g" {
│ Unable to create model, got error: failed to open kubernetes client: annotations map[controller.juju.is/id:ced7016b-3a63-4133-8988-cf33068c3cdf
│ model.juju.is/id:2abfe7ab-9e40-4e0d-8158-53450c47b2db] for namespace "private5g" not valid must include map[controller.juju.is/id:ced7016b-3a63-4133-8988-cf33068c3cdf
│ model.juju.is/id:9755936b-8084-4397-8a67-28773b361dfa] (not valid)
```

### Recommended Actions

Validate whether a Juju model already exists with the same name:

```shell
$ juju models
controller: k8s

Model       Cloud/Region  Type        Status      Units  Access  Last connection
controller  k8s           kubernetes  available   1       admin  just now
private5g*  k8s           kubernetes  destroying  -       admin  6 minutes ago
sdcore      k8s           kubernetes  available   19      admin  2024-10-04
```

Choose a model name that does not exist in the Juju controller. Read [this guide][Configure SD-Core K8s Deployment] for more information.

## 2. Terraform failed to deploy Charmed Aether SD-Core with `Connection error, please check the controller_addresses property set on the provider` error

### Symptoms

The `terraform apply -auto-approve` command fails with an error indicating that the Juju controller couldn't be connected to:

```console
$ terraform apply --auto-approve
│ Error: Invalid provider configuration
│ Provider "registry.terraform.io/juju/juju" requires explicit configuration. Add a provider block to the root module and configure the provider's required arguments as described in
│ the provider documentation.
│ Error: dial tcp 10.152.183.251:17070: i/o timeout
│   with provider["registry.terraform.io/juju/juju"],
│   on <empty> line 0:
│   (source code not available)
│ Connection error, please check the controller_addresses property set on the provider
```

### Recommended Actions

Validate that the Juju controller exists.

First, list the available Juju controllers:

```console
$ juju controllers
Use --refresh option with this command to see the latest information.

Controller  Model      User   Access     Cloud/Region  Models  Nodes  HA  Version
k8s*        private5g  admin  superuser  k8s                9      -   -  3.6.0  
```

If your controller does not show up in the list, please follow [this guide][Bootstrap Juju Controller] to create a Juju controller.

Otherwise, follow [this guide][Remove Juju Controller] to remove your broken Juju controller.

Once the controller is removed, please make sure that the controller namespace is not found in your K8s cluster:

```shell
$ kubectl get ns controller-<your-controller-name>
NAME                            STATUS   AGE
controller-<your-controller-name>   Active   20d
```

If your controller namespace appears as `Active` in the command output, remove the namespace manually:

```shell
$ kubectl delete ns controller-<your-controller-name>
namespace "controller-<your-controller-name>" deleted
```

After successful removal of the controller namespace, please follow [this guide][Bootstrap Juju Controller] to create a new Juju controller.

[Bug Report]: https://github.com/login?return_to=https%3A%2F%2Fgithub.com%2Fcanonical%2Fcharmed-aether-sd-core%2Fissues%2Fnew%3Fassignees%3D%26amp%3Blabels%3Dbug%26amp%3Bprojects%3D%26amp%3Btemplate%3Dbug_report.yml
[Configure SD-Core K8s Deployment]: https://canonical-charmed-aether-sd-core.readthedocs-hosted.com/en/latest/how-to/deploy_sdcore_standalone/#deploy
[Remove Juju Controller]: https://documentation.ubuntu.com/juju/latest/howto/manage-controllers/index.html#remove-a-controller
[Bootstrap Juju Controller]: https://canonical-charmed-aether-sd-core.readthedocs-hosted.com/en/latest/tutorials/getting_started/#bootstrap-a-juju-controller
