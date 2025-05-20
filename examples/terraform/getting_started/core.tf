# Copyright 2024 Canonical Ltd.
# See LICENSE file for licensing details.

resource "juju_model" "sdcore" {
  name = "sdcore"
}


module "sdcore" {
  source = "git::https://github.com/canonical/terraform-juju-sdcore//modules/sdcore-k8s"

  model      = juju_model.sdcore.name

  traefik_config = {
    routing_mode = "subdomain"
  }
}
