# Troubleshoot the deployment issues

This guide provides the steps to troubleshoot the unsuccessful Charmed Aether SD-Core deployments for different failure cases.

## A. Create a Bug Report

If you hit one of the following situations during the deployment, raise the issue by filling a [bug report][Bug Report].

### A. 1. Terraform failed to deploy the Charmed Aether SD-Core because of configuration mismatch

Terraform may fail to deploy the Charmed Aether SD-Core modules because of wrong configuration issues. These errors are generally caused by the mistakes in module designs or oversights during version changes.
When the `terraform apply -auto-approve` command is run, deployment fails with wrong integration endpoints or wrong object attributes etc. as following:

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

#### Recommended Actions

[Validate the Terraform modules][Validate Terraform Configuration] by running `terraform validate` to analyze the dependencies between resources in your infrastructure configuration to determine the order to perform your operations.

This command outputs the consistency result of the Terraform modules as success or error.

Fixing the module may require advanced knowledge. If you hit a case that described above, create a [bug report][Bug Report]

### A. 2. Charmed Aether SD-Core charms stuck at the Waiting/Error status

After deploying the Charmed Aether SD-Core, the applications are deployed to target Juju model. 

If any application hangs in Waiting or Error status, raise the issue as this situation can be caused by a bug in the charm or the workload.

| Charm Status | How much time passed                             | Reason                | Recommended Action                                                    |
|--------------|--------------------------------------------------|-----------------------|-----------------------------------------------------------------------|
| Waiting      | Time is exceeded according the followed tutorial |                       | File a bug report                                                     | 
| Error        |                                                  | Any reason            | File a bug report                                                     |

#### Recommended Actions

Get the application container's logs by running the below command:

```shell
$ microk8s.kubectl logs -f <pod_name> -c <container_name> -c <model_name>
```

File a [bug report][Bug Report] by attaching the logs and providing other required details.

## B. Fix the environment/configuration related problems

The issues which are described below can be fixed by performing the recommended actions.

### B. 1. Terraform failed to deploy the Charmed Aether SD-Core because of selecting an existing Juju model

Charmed Aether SD-Core creates a Juju model and deploys the resources in it. The Juju model has a default name, and it is allowed to be modified by configuration options. 
Terraform may fail to deploy the Charmed Aether SD-Core modules because of the provided model name already exists in the Juju controller.
When the `terraform apply -auto-approve` command is run, deployment fails with client error which express that Juju model could not be created as following:

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

Check all the existing Juju models by running the following command:

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

### B. 2. Juju failed to deploy Charmed Aether SD-Core as Juju controller is not reachable

Terraform Juju Provider uses the Juju to deploy the charms and set up the integrations indicated through the Terraform modules. 

While Juju is performing the deployment, an environmental issue such as a network problem may happen which makes the controller unreachable.

For the situation that the Juju controller is not available, the deployment fails with the error `timeout to Juju Terraform provider` as following.

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

#### Recommended Actions

Make sure that Juju controller is available. If the following command does not output desired Juju controller, follow the guide [manage Juju controllers][Manage Juju Controller] to create a Juju controller.

```shell
$ juju controllers
Use --refresh option with this command to see the latest information.

Controller           Model      User   Access     Cloud/Region        Models  Nodes  HA  Version
microk8s-localhost*  private5g  admin  superuser  microk8s/localhost       9      -   -  3.4.5  
```

### B. 3. Charmed Aether SD-Core charms stuck at the Waiting/Blocked status

After deploying the Charmed Aether SD-Core, the applications are deployed to target Juju model. 

If any application hangs in Waiting or Blocked status, check the below table. If any situation fits to your case then perform the recommended action by utilizing the 
[Charmed Aether SD-Core Documentation][Charmed Aether SD-Core Documentation].

| Charm Status | How much time passed | Reason                                                                | Recommended Actions                                                   |
|--------------|----------------------|-----------------------------------------------------------------------|-----------------------------------------------------------------------|
| Waiting      | For a short time     | Waiting for a relation data, configuration or service to be available | Wait more                                                             |
| Blocked      |                      | Multus is not installed or enabled                                    | Install and enable Multus                                             |
| Blocked      |                      | CPU is not compatible                                                 | Use CPU which is Intel 4ᵗʰ generation or newer, or AMD Ryzen or newer |
| Blocked      |                      | Not enough HugePages available                                        | Set at least two 1G HugePages in the host                             |
| Blocked      |                      | Waiting for a relation                                                | Find the missing interface and relate                                 |
| Blocked      |                      | Invalid configuration                                                 | Provide valid configuration options                                   |
| Blocked      |                      | MetalLB is not enabled                                                | Enable MetalLB                                                        |


[Bug Report]: https://github.com/canonical/charmed-aether-sd-core/issues/new?assignees=&labels=bug&projects=&template=bug_report.yml

[Validate Terraform Configuration]: https://developer.hashicorp.com/terraform/tutorials/configuration-language/troubleshooting-workflow#validate-your-configuration

[Deploy SD-Core K8s with Terraform]: https://github.com/canonical/terraform-juju-sdcore/blob/main/modules/sdcore-k8s/README.md#deploying-sdcore-k8s-with-terraform

[Manage Juju Controller]: https://juju.is/docs/juju/manage-controllers

[Traefik Pod Goes to Error State]: https://github.com/canonical/traefik-k8s-operator/issues/361

[Charmed Aether SD-Core Documentation]: https://github.com/canonical/charmed-aether-sd-core/tree/main/docs







