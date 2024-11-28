# Copyright 2024 Canonical Ltd.
# See LICENSE file for licensing details.

resource "juju_model" "ran-simulator" {
  name = "ran"
}

module "gnbsim" {
  source = "git::https://github.com/canonical/sdcore-gnbsim-k8s-operator//terraform?ref=v1.5"

  model      = juju_model.ran-simulator.name
  depends_on = [module.sdcore-router]
}

resource "juju_offer" "gnbsim-fiveg-gnb-identity" {
  model            = juju_model.ran-simulator.name
  application_name = module.gnbsim.app_name
  endpoint         = module.gnbsim.provides.fiveg_gnb_identity
}

resource "juju_integration" "gnbsim-amf" {
  model = juju_model.ran-simulator.name

  application {
    name     = module.gnbsim.app_name
    endpoint = module.gnbsim.requires.fiveg_n2
  }

  application {
    offer_url = module.sdcore.amf_fiveg_n2_offer_url
  }
}

resource "juju_integration" "gnbsim-nms" {
  model = juju_model.sdcore.name

  application {
    name     = module.sdcore.nms_app_name
    endpoint = module.sdcore.fiveg_gnb_identity_endpoint
  }

  application {
    offer_url = juju_offer.gnbsim-fiveg-gnb-identity.url
  }
}
