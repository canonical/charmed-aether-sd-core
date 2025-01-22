# Deploy SD-Core with Control Plane and User Plane Separation

This guide covers how to install a SD-Core 5G core network with Control Plane and User Plane Separation (CUPS).

## Requirements

- Juju >= 3.6
- A Juju controller has been bootstrapped, and is externally reachable
- A Control Plane Kubernetes cluster (version >= 1.25) configured with
  - 1 available IP address for the Access and Mobility Management Function (AMF)
  - 1 available IP address for Traefik
- A User Plane Kubernetes cluster (version >= 1.25) configured with
  - 1 available IP address for the User Plane Function (UPF)
  - Multus
  - MACVLAN interfaces for Access and Core networks
- 1 Juju cloud per Kubernetes cluster named `control-plane-cloud` and `user-plane-cloud` respectively
- Terraform
- Git

## Deploy SD-Core Control Plane

Create a Juju model to represent the Control Plane.

```console
juju add-model control-plane control-plane-cloud
```

Get Charmed Aether SD-Core Terraform modules by cloning the [Charmed Aether SD-Core Terraform modules][Charmed Aether SD-Core Terraform modules] Git repository.
Inside the `modules/sdcore-control-plane-k8s` directory, create a `control-plane.tfvars` file to set the name of Juju model for the deployment:

```console
git clone https://github.com/canonical/terraform-juju-sdcore.git
cd terraform-juju-sdcore/modules/sdcore-control-plane-k8s
cat << EOF > control-plane.tfvars
model_name = "control-plane"
create_model = false
amf_config = {
  external-amf-ip       = "10.201.0.201"
  external-amf-hostname = "amf.core"
}

EOF
```

Initialize Juju Terraform provider:

```console
terraform init
```

Deploy SD-Core Control Plane

```console
terraform apply -var-file="control-plane.tfvars" -auto-approve
```

### Integration with the AMF N2 interface

The AMF charm allows establishing the N2-plane connectivity through the `fiveg_n2` charm interface.

``````{tab-set}

`````{tab-item} Option 1: Integration within the same Juju model

It is assumed that the `fiveg-n2` requirer application is already deployed in the Juju model.
To create a `fiveg_n2` integration between the AMF and another application within the same Juju model, add the following section to the `main.tf` file in the `terraform-juju-sdcore/modules/sdcore-control-plane-k8s` directory:

```console
resource "juju_integration" "fiveg-n2" {
  model = "control-plane"

  application {
    name     = module.amf.app_name
    endpoint = module.amf.fiveg_n2_endpoint
  }

  application {
    name     = <THE `fiveg-n2` REQUIRER APP>
    endpoint = <THE `fiveg-n2` REQUIRER APP'S INTEGRATION ENDPOINT>
  }
}
```

Apply the changes:

```console
terraform apply -var-file="control-plane.tfvars" -auto-approve
```

`````

`````{tab-item} Option 2: Cross-model integration

In this option, it is assumed that the `sdcore-control-plane-k8s` has been deployed as part (a sub-module) of a bigger system.
The `sdcore-control-plane-k8s` Terraform module exposes the AMF application name and the `fiveg-n2` endpoint through the `output.tf` file.
To create a cross-model `fiveg_n2` integration in the root module of your deployment, add the following section to the `main.tf` file:

```console
resource "juju_offer" "amf-fiveg-n2" {
  model            = "control-plane"
  application_name = module.<CONTROL PLANE MODULE NAME>.amf_app_name
  endpoint         = module.<CONTROL PLANE MODULE NAME>.fiveg_n2_endpoint
}

resource "juju_integration" "fiveg-n2" {
  model = "control-plane"

  application {
    name     = <THE `fiveg-n2` REQUIRER APP>
    endpoint = <THE `fiveg-n2` REQUIRER APP'S INTEGRATION ENDPOINT>
  }

  application {
    offer_url = juju_offer.amf-fiveg-n2.url
  }
}
```

Apply the changes:

```console
terraform apply -auto-approve
```

`````

``````

## Deploy SD-Core User Plane

Create a Juju model.

```console
juju add-model user-plane user-plane-cloud
```

Get Charmed Aether SD-Core Terraform modules by cloning the [Charmed Aether SD-Core Terraform modules][Charmed Aether SD-Core Terraform modules] Git repository.
Inside the `modules/sdcore-user-plane-k8s` directory, create a `user-plane.tfvars` file to set the name of Juju model for the deployment:

```console
git clone https://github.com/canonical/terraform-juju-sdcore.git
cd terraform-juju-sdcore/modules/sdcore-user-plane-k8s
cat << EOF > user-plane.tfvars
model_name = "user-plane"
create_model = false
upf_config = {
  cni-type          = "macvlan"
  access-gateway-ip = "10.202.0.1"
  access-interface  = "access"
  access-ip         = "10.202.0.10/24"
  core-gateway-ip   = "10.203.0.1"
  core-interface    = "core"
  core-ip           = "10.203.0.10/24"
  gnb-subnet        = "10.204.0.0/24"
}

EOF
```

Initialize Juju Terraform provider:

```console
terraform init
```

Deploy SD-Core User Plane

```console
terraform apply -var-file="user-plane.tfvars" -auto-approve
```

### Integration with the UPF N4 interface

The UPF charm allows establishing the N4-plane connectivity through the `fiveg_n4` charm interface.

``````{tab-set}

`````{tab-item} Option 1: Integration within the same Juju model

It is assumed that the `fiveg_n4` requirer application is already deployed in the Juju model.
To create a `fiveg_n4` integration between the UPF and another application within the same Juju model, add the following section to the `main.tf` file in the `terraform-juju-sdcore/modules/sdcore-user-plane-k8s` directory:

```console
resource "juju_integration" "fiveg-n4" {
  model = "user-plane"

  application {
    name     = module.upf.app_name
    endpoint = module.upf.fiveg_n4_endpoint
  }

  application {
    name     = <THE `fiveg_n4` REQUIRER APP>
    endpoint = <THE `fiveg_n4` REQUIRER APP'S INTEGRATION ENDPOINT>
  }
}
```

Apply the changes:

```console
terraform apply -var-file="user-plane.tfvars" -auto-approve
```

`````

`````{tab-item} Option 2: Cross-model integration

In this option, it is assumed that the `sdcore-user-plane-k8s` has been deployed as part (a sub-module) of a bigger system.
The `sdcore-user-plane-k8s` Terraform module exposes the UPF application name and the `fiveg_n4` endpoint through the `output.tf` file.
To create a cross-model `fiveg_n4` integration in the root module of your deployment, add the following section to the `main.tf` file:

```console
resource "juju_offer" "upf-fiveg-n4" {
  model            = "user-plane"
  application_name = module.<USER PLANE MODULE NAME>.upf_app_name
  endpoint         = module.<USER PLANE MODULE NAME>.fiveg_n4_endpoint
}

resource "juju_integration" "fiveg-n4" {
  model = "control-plane"

  application {
    name     = <THE `fiveg_n4` REQUIRER APP>
    endpoint = <THE `fiveg_n4` REQUIRER APP'S INTEGRATION ENDPOINT>
  }

  application {
    offer_url = juju_offer.upf-fiveg-n4.url
  }
}
```

Apply the changes:

```console
terraform apply -auto-approve
```

`````

``````

[Charmed Aether SD-Core Terraform modules]: https://github.com/canonical/terraform-juju-sdcore
