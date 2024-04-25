# Deploy SD-Core Standalone

This guide covers how to install a standalone SD-Core 5G core network, suitable for lab or proof of concept purposes.

## Requirements

You will need a Kubernetes cluster installed and configured with Multus.

- Juju >= 3.4
- Kubernetes >= 1.25
- A `LoadBalancer` Service for Kubernetes with at least 3 addresses available
- Multus
- Terraform
- Git

## Deploy

Get Charmed Aether SD-Core Terraform modules by cloning the [Charmed Aether SD-Core Terraform modules][Charmed Aether SD-Core Terraform modules] Git repository.
Inside the `modules/sdcore-k8s` directory, create a `terraform.tfvars` file to set the name of Juju model for the deployment:

```console
git clone https://github.com/canonical/terraform-juju-sdcore-k8s.git
cd terraform-juju-sdcore-k8s/modules/sdcore-k8s
cat << EOF > terraform.tfvars
model_name = "<YOUR_JUJU_MODEL_NAME>"
EOF
```

Initialize Juju Terraform provider:

```console
terraform init
```

Deploy 5G network.

```console
terraform apply -var-file="terraform.tfvars" -auto-approve
```

The deployment process should take approximately 15-20 minutes.

You can monitor the status of the deployment:

```console
juju switch <YOUR_JUJU_MODEL_NAME>
watch -n 1 -c juju status --color --relations
```

The deployment is ready when all the charms are in the `Active/Idle` state. 
It is normal for `grafana-agent` to remain in waiting state.

## Configure

Configuration of the Charmed Aether SD-Core deployment should be done **only** through the `.tfvars` file. 

To view all the available configuration options, please inspect the `variables.tf` file available inside the Terraform module directory.

To be effective, every configuration change needs to be applied using the following command:

```console
terraform apply -var-file="terraform.tfvars" -auto-approve
```

[Charmed Aether SD-Core Terraform modules]: https://github.com/canonical/terraform-juju-sdcore-k8s
