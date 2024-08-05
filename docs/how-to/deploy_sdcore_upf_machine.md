# Deploy SD-Core User Plane Machine

This guide covers how to deploy the User Plane Function (UPF) as a machine charm.

## Requirements

- [Juju][Juju] controller bootstrapped on a separate machine
- A machine added to the Juju controller, with the following requirements:
  - A host with a CPU supporting AVX2 and RDRAND instructions (Intel Haswell, AMD Excavator or equivalent)
- [Terraform][Terraform] installed
- Git

## Deploy

Get the Charmed Aether SD-Core Terraform UPF Machine module by cloning the [Charmed Aether SD-Core UPF module][Charmed Aether SD-Core UPF module] Git repository. Inside the `terraform` directory, create a `terraform.tfvars` file to set the name of Juju model and machine number for the deployment. You will also need to provide the appropriate network configuration.

```console
git clone https://github.com/canonical/sdcore-upf-operator.git
cd sdcore-upf-operator/terraform/

cat << EOF > terraform.tfvars
machine_number = 0
model_name = "user-plane"
config = {
  upf-mode = "af_packet"
  dnn = "internet"
  enable-hw-checksum = true
  access-interface-name = "enp6s0"
  access-ip = "192.168.252.3/24"
  access-gateway-ip = "192.168.252.1"
  access-interface-mtu-size = 1500
  core-interface-name = "enp7s0"
  core-ip = "192.168.250.3/24"
  core-gateway-ip = "192.168.250.1"
  core-interface-mtu-size = 1500
  gnb-subnet = "192.168.251.0/24"
}
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

[Charmed Aether SD-Core UPF module]: https://github.com/canonical/sdcore-upf-operator/
[Juju]: https://juju.is
[Terraform]: https://www.terraform.io/
