# Copyright 2024 Canonical Ltd.
# See LICENSE file for licensing details.

resource "juju_model" "sdcore" {
  name = "sdcore"
}

module "sdcore-router" {
  source = "git::https://github.com/canonical/sdcore-router-k8s-operator//terraform?ref=v1.5"

  model      = juju_model.sdcore.name
  depends_on = [juju_model.sdcore]
}

module "sdcore" {
  source = "git::https://github.com/canonical/terraform-juju-sdcore//modules/sdcore-k8s?ref=v1.5"

  model      = juju_model.sdcore.name
  depends_on = [module.sdcore-router]

  traefik_config = {
    routing_mode = "subdomain"
  }
}
