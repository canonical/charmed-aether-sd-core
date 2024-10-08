# Troubleshoot the deployment issues

This guide provides step-by-step troubleshooting actions to remediate deployment issues. We hope you don't need this guide. If you encounter an issue and aren't able to address it via this guide, please raise an issue [here][Bug Report].

## 1. Terraform failed to deploy the Charmed Aether SD-Core because of configuration mismatch

### Symptoms

Terraform may fail to deploy the Charmed Aether SD-Core modules. When the `terraform apply -auto-approve` command is run, the deployment fails with the wrong integration endpoints or the wrong object attributes etc. as following:

```console
$ terraform apply -auto-approve 
╷
│ Error: Unsupported attribute
│ 
│   on main.tf line 54, in resource "juju_integration" "cu-nms":
│   54:     endpoint = module.sdcore.fiveg_identity_endpoint
│     ├────────────────
│     │ module.sdcore is a object
│ 
│ This object does not have an attribute named "fiveg_identity_endpoint".
```

### Recommended Actions

[Validate the Terraform modules][Validate Terraform Configuration]:

```shell
$ terraform validate
Success! The configuration is valid.
```

The command should not fail. If it does, please open a [bug report][Bug Report].

## 2. Charmed Aether SD-Core charms stuck at the Waiting/Error status

### Symptoms

After deploying the Charmed Aether SD-Core, check the applications' status:

```shell
$ juju status
```

In the command output, all the charms except the `grana-agent` should be in the Active/Idle state. If any application's status is `Waiting` or `Error`, please apply the recommended actions.

### Recommended Actions

if any application hangs in `Waiting` or `Error` status, please open a [bug report][Bug Report].

| Charm Status | How much time passed                             | Reason                | Recommended Action                                                    |
|--------------|--------------------------------------------------|-----------------------|-----------------------------------------------------------------------|
| Waiting      | Time is exceeded according the followed tutorial |                       | File a bug report                                                     | 
| Error        |                                                  | Any reason            | File a bug report                                                     |

Get the application container's logs:

```shell
$ microk8s.kubectl logs -f <pod_name> -c <container_name> -c <model_name>
```

Attach the logs to the bug report by providing other required details.

## 3. Terraform failed to deploy the Charmed Aether SD-Core because of selecting an existing Juju model

### Symptoms

Terraform may fail to deploy the Charmed Aether SD-Core modules because of the provided model name already exists in the Juju controller. When the `terraform apply -auto-approve` command is run, the deployment fails with the client error which express that the Juju model could not be created as following:

```console
Plan: 72 to add, 0 to change, 0 to destroy.
juju_model.private5g: Creating...
╷
│ Error: Client Error
│ 
│   with juju_model.private5g,
│   on main.tf line 1, in resource "juju_model" "private5g":
│    1: resource "juju_model" "private5g" {
│ 
│ Unable to create model, got error: failed to open kubernetes client: annotations map[controller.juju.is/id:ced7016b-3a63-4133-8988-cf33068c3cdf
│ model.juju.is/id:2abfe7ab-9e40-4e0d-8158-53450c47b2db] for namespace "private5g" not valid must include map[controller.juju.is/id:ced7016b-3a63-4133-8988-cf33068c3cdf
│ model.juju.is/id:9755936b-8084-4397-8a67-28773b361dfa] (not valid)
```

### Recommended Actions

Check all the existing Juju models:

```shell
$ juju models
controller: microk8s-localhost

Model       Cloud/Region        Type        Status      Units  Access  Last connection
controller  microk8s/localhost  kubernetes  available   1       admin  just now
private5g*  microk8s/localhost  kubernetes  destroying  -       admin  6 minutes ago
private5g2  microk8s/localhost  kubernetes  destroying  -       admin  1 minute ago
sdcore      microk8s/localhost  kubernetes  available   19      admin  2024-10-04
```

According to [Customize the model name using variables][Deploy SD-Core K8s with Terraform], provide a model name which does not exist in Juju controller:

Create a `terraform.tfvars` file to specify the name of the Juju model to deploy to.

```shell
cat << EOF | tee terraform.tfvars
model_name = "put your model-name here"
EOF
```

Deploy the applications by customizing the model name attribute:

```shell
terraform apply -var-file="terraform.tfvars" -auto-approve 
```

## 4. Juju failed to deploy Charmed Aether SD-Core as Juju controller is not reachable

### Symptoms

While Juju is performing the deployment, the Juju controller may be unavailable which fails the deployment with the error `timeout to Juju Terraform provider` as following.

```console
$ terraform apply --auto-approve
╷
│ Error: Invalid provider configuration
│ 
│ Provider "registry.terraform.io/juju/juju" requires explicit configuration. Add a provider block to the root module and configure the provider's required arguments as described in
│ the provider documentation.
│ 
│ Error: dial tcp 10.152.183.251:17070: i/o timeout
│ 
│   with provider["registry.terraform.io/juju/juju"],
│   on <empty> line 0:
│   (source code not available)
│ 
│ Connection error, please check the controller_addresses property set on the provider
```

### Recommended Actions

Make sure that the Juju controller is available:

```shell
$ juju controllers
Use --refresh option with this command to see the latest information.

Controller           Model      User   Access     Cloud/Region        Models  Nodes  HA  Version
microk8s-localhost*  private5g  admin  superuser  microk8s/localhost       9      -   -  3.4.5  
```

If it does not output the controller details, please follow the guide [manage Juju controllers][Manage Juju Controller] to create a Juju controller.

## 5. Charmed Aether SD-Core charms stuck at the Waiting/Blocked status

### Symptoms

After deploying the Charmed Aether SD-Core, check the applications' status:

```shell
$ juju status
```

All the charms except the `grana-agent` should be in the Active/Idle state.

If any application hangs in `Waiting` or `Blocked` status, check the table below to see the recommended actions.

### Recommended Actions

If any situation fits to your case in the table below, then perform the recommended actions by utilizing the [Charmed Aether SD-Core Documentation][Charmed Aether SD-Core Documentation].

| Charm Status | How much time passed | Reason                                                                | Recommended Actions                                                   |
|--------------|----------------------|-----------------------------------------------------------------------|-----------------------------------------------------------------------|
| Waiting      | For a short time     | Waiting for a relation data, configuration or service to be available | Wait more                                                             |
| Blocked      |                      | Multus is not installed or enabled                                    | Install and enable Multus                                             |
| Blocked      |                      | CPU is not compatible                                                 | Use CPU which is Intel 4ᵗʰ generation or newer, or AMD Ryzen or newer |
| Blocked      |                      | Not enough HugePages available                                        | Set at least two 1G HugePages in the host                             |
| Blocked      |                      | Waiting for a relation                                                | Find the missing interface and set up the relation                    |
| Blocked      |                      | Invalid configuration                                                 | Provide valid configuration options                                   |
| Blocked      |                      | MetalLB is not enabled                                                | Enable MetalLB                                                        |


[Bug Report]: https://github.com/canonical/charmed-aether-sd-core/issues/new?assignees=&labels=bug&projects=&template=bug_report.yml

[Validate Terraform Configuration]: https://developer.hashicorp.com/terraform/tutorials/configuration-language/troubleshooting-workflow#validate-your-configuration

[Deploy SD-Core K8s with Terraform]: https://github.com/canonical/terraform-juju-sdcore/blob/main/modules/sdcore-k8s/README.md#deploying-sdcore-k8s-with-terraform

[Manage Juju Controller]: https://juju.is/docs/juju/manage-controllers

[Traefik Pod Goes to Error State]: https://github.com/canonical/traefik-k8s-operator/issues/361

[Charmed Aether SD-Core Documentation]: https://github.com/canonical/charmed-aether-sd-core/tree/main/docs







