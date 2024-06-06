# Deploy SD-Core User Plane Machine

This guide covers how to deploy the User Plane Function (UPF) as a machine charm.

## Requirements

- A host with a CPU supporting AVX2 and RDRAND instructions (Intel Haswell, AMD Excavator or equivalent)
- [Juju][Juju] controller bootstrapped to a LXD cluster
- A Juju machine manually representing the host added to the controller
-  [Terraform][Terraform] installed
- Git

## Deploy

Get Charmed Aether SD-Core Terraform UPF Machine module by cloning the [Charmed Aether SD-Core UPF module][Charmed Aether SD-Core UPF modules] Git repository. Inside the `terraform` directory, create a `terraform.tfvars` file to set the name of Juju model and machine number for the deployment:

```console
git clone https://github.com/canonical/sdcore-upf-operator.git
cd terraform

cat << EOF > terraform.tfvars
machine_number = 0
model_name = "user-plane"
EOF
```

Initialize Juju Terraform provider:

```console
terraform init
```

Deploy the machine charm to the machine number specified in the `terraform.tfvars` file.

```console
terraform apply -var-file="terraform.tfvars" -auto-approve
```

[Terraform]: https://www.terraform.io/
[Juju]: https://juju.is
