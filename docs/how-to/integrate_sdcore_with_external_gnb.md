# Integrate SD-Core with an Externally Managed Radio

For simplicity in managing deployments, the gNB Name and TAC can be supplied via a charm integration. This is the purpose of the sdcore-gnb-integrator charm.

## Pre-requisites

- A Kubernetes cluster capable of handling the load from a container per represented gNB
- [Charmed Aether SD-Core Terraform modules][Charmed Aether SD-Core Terraform modules] Git repository cloned onto the Juju host machine
- Charmed Aether SD-Core already deployed using Terraform

You need to have the following information ready:

- A name for the gNB
- The name of the juju model for the gNB integrator
- The TAC (represented in hex) that the gNB is serving
- The name of the control plane model

## Deploying gNB Integrator

Given the following:

- Model name: `gnb-integration`
- GNB Name: `gnb01`
- TAC: `B01F`
- Control Plane Model: `control-plane`

Either create a new `.tf` file, or add the following content to you existing `main.tf`.

```console
module "gnb01" {
  app_name   = "gnb01"
  source     = "git::https://github.com/canonical/sdcore-gnb-integrator//terraform?ref=v1.5"
  model_name = "gnb-integration"
  channel    = "1.5/stable"
  config     = {
    tac: B01F
  }
}

resource "juju_offer" "gnb01-fiveg-gnb-identity" {
  model            = "gnb-integration"
  application_name = module.gnb01.app_name
  endpoint         = module.gnb01.fiveg_gnb_identity_endpoint
}

resource "juju_integration" "nms-gnb01" {
  model = "control-plane"

  application {
    name     = module.sdcore-control-plane.nms_app_name
    endpoint = module.sdcore-control-plane.fiveg_gnb_identity_endpoint
  }

  application {
    offer_url = juju_offer.gnb01-fiveg-gnb-identity.url
  }
}
```

[Charmed Aether SD-Core Terraform modules]: https://github.com/canonical/terraform-juju-sdcore
