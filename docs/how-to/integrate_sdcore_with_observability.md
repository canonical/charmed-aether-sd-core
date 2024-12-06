# Integrate SD-Core with Canonical Observability Stack

One of the key aspects considered while developing Charmed Aether SD-Core was making it easily observable.
To achieve this, each [Charmed Aether SD-Core Terraform module][Charmed Aether SD-Core Terraform modules] includes Grafana Agent application, which allows for integration with the Canonical Observability Stack (COS).

This how-to guide outlines the process of integrating Charmed Aether SD-Core with COS.

Steps described in this guide can be performed as both Day 1 and Day 2 operations.

```{note}
Deploying Canonical Observability Stack will increase the resources consumption on the K8s cluster. 
Make sure your Kubernetes cluster is capable of handling the load from both Charmed Aether SD-Core and COS before proceeding.  
```

## 1. Add COS to the solution Terraform module

Update your solution Terraform module (here it's named `main.tf`):

```console
cat << EOF > main.tf
module "cos" {
  source                   = "git::https://github.com/canonical/terraform-juju-sdcore//modules/external/cos-lite?ref=v1.5"
  model_name               = "cos-lite"
  deploy_cos_configuration = true
  cos_configuration_config = {
    git_repo                = "https://github.com/canonical/sdcore-cos-configuration"
    git_branch              = "main"
    grafana_dashboards_path = "grafana_dashboards/sdcore/"
  }
}

resource "juju_integration" "prometheus-remote-write" {
  model = "YOUR_CHARMED_AETHER_SD_CORE_MODEL_NAME"

  application {
    name     = module.sdcore.grafana_agent_app_name
    endpoint = module.sdcore.send_remote_write_endpoint
  }

  application {
    offer_url = module.cos.prometheus_remote_write_offer_url
  }
}

resource "juju_integration" "loki-logging" {
  model = "YOUR_CHARMED_AETHER_SD_CORE_MODEL_NAME"

  application {
    name     = module.sdcore.grafana_agent_app_name
    endpoint = module.sdcore.logging_consumer_endpoint
  }

  application {
    offer_url = module.cos.loki_logging_offer_url
  }
}

EOF
```

```{note}
In this guide it is assumed, that the Terraform module responsible for deploying Charmed Aether SD-Core is named `sdcore`.
If you use different name, please make sure it's reflected in COS integrations.
```

## 2. Apply the changes

Fetch COS module:

```console
terraform init
```

Apply new configuration:

```console
terraform apply -auto-approve
```

## 3. Example of a complete solution Terraform module including Charmed Aether SD-Core integrated with COS

```console
resource "juju_model" "sdcore" {
  name  = "sdcore"
}

module "sdcore" {
  source                   = "git::https://github.com/canonical/terraform-juju-sdcore-k8s//modules/sdcore-k8s?ref=v1.5"
  model_name               = juju_model.sdcore.name
  create_model             = false
}

module "cos" {
  source                   = "git::https://github.com/canonical/terraform-juju-sdcore//modules/external/cos-lite?ref=v1.5"
  model_name               = "cos-lite"
  deploy_cos_configuration = true
  cos_configuration_config = {
    git_repo                = "https://github.com/canonical/sdcore-cos-configuration"
    git_branch              = "main"
    grafana_dashboards_path = "grafana_dashboards/sdcore/"
  }
}

resource "juju_integration" "prometheus-remote-write" {
  model = juju_model.sdcore.name

  application {
    name     = module.sdcore.grafana_agent_app_name
    endpoint = module.sdcore.send_remote_write_endpoint
  }

  application {
    offer_url = module.cos.prometheus_remote_write_offer_url
  }
}

resource "juju_integration" "loki-logging" {
  model = juju_model.sdcore.name

  application {
    name     = module.sdcore.grafana_agent_app_name
    endpoint = module.sdcore.logging_consumer_endpoint
  }

  application {
    offer_url = module.cos.loki_logging_offer_url
  }
}
```

[Charmed Aether SD-Core Terraform modules]: https://github.com/canonical/terraform-juju-sdcore
