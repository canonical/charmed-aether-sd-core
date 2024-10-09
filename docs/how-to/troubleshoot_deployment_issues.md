# Troubleshoot deployment issues

This guide provides step-by-step troubleshooting actions to remediate deployment issues. We hope you don't need this guide. If you encounter an issue and aren't able to address it via this guide, please raise an issue [here][Bug Report].

## 1. Terraform failed to deploy the Charmed Aether SD-Core because of selecting an existing Juju model

### Symptoms

The `terraform apply -auto-approve` command fails with a client error which express that the Juju model could not be created:

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
controller: microk8s-localhost

Model       Cloud/Region        Type        Status      Units  Access  Last connection
controller  microk8s/localhost  kubernetes  available   1       admin  just now
private5g*  microk8s/localhost  kubernetes  destroying  -       admin  6 minutes ago
sdcore      microk8s/localhost  kubernetes  available   19      admin  2024-10-04
```

Choose a model name that does not already exist in the Juju controller. Read [this guide][Deploy SD-Core K8s with Terraform] for more information.

## 2. Juju failed to deploy Charmed Aether SD-Core as Juju controller is not reachable

### Symptoms

The `terraform apply -auto-approve` command fails with a dial tcp i/o timeout error:

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

Validate that the Juju controller is available:

```shell
$ juju controllers
Use --refresh option with this command to see the latest information.

Controller           Model      User   Access     Cloud/Region        Models  Nodes  HA  Version
microk8s-localhost*  private5g  admin  superuser  microk8s/localhost       9      -   -  3.4.5  
```

If it does not output the controller details, please follow [this guide][Manage Juju Controller] to create an accessible Juju controller.

## 3. Charmed Aether SD-Core charms stuck at the Waiting/Blocked status

### Symptoms

After deploying Charmed Aether SD-Core, charms hang in `Waiting` or `Blocked` status.

### Recommended Actions

If any situation in the table below fits to your case, then perform the recommended actions by utilizing [this guide][Charmed Aether SD-Core Documentation].

| Charm Status | How much time passed                           | Reason                                                                | Recommended Actions                                                   |
|--------------|------------------------------------------------|-----------------------------------------------------------------------|-----------------------------------------------------------------------|
| Waiting      | Within the time specified in the documentation | Waiting for a relation data, configuration or service to be available | Wait more                                                             |
| Blocked      |                                                | Multus is not installed or enabled                                    | Install and enable Multus                                             |
| Blocked      |                                                | CPU is not compatible                                                 | Use CPU which is Intel 4ᵗʰ generation or newer, or AMD Ryzen or newer |
| Blocked      |                                                | Not enough HugePages available                                        | Make sure at least two 1G HugePages are available in the host         |
| Blocked      |                                                | Invalid configuration                                                 | Provide valid configuration options                                   |
| Blocked      |                                                | MetalLB is not enabled                                                | Enable MetalLB                                                        |


[Bug Report]: https://github.com/canonical/charmed-aether-sd-core/issues/new?assignees=&labels=bug&projects=&template=bug_report.yml

[Deploy SD-Core K8s with Terraform]: https://github.com/canonical/terraform-juju-sdcore/blob/main/modules/sdcore-k8s/README.md#deploying-sdcore-k8s-with-terraform

[Manage Juju Controller]: https://juju.is/docs/juju/manage-controllers

[Charmed Aether SD-Core Documentation]: https://github.com/canonical/charmed-aether-sd-core/tree/main/docs