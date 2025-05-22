# Copyright 2024 Canonical Ltd.
# See LICENSE file for licensing details.

resource "juju_model" "ran-simulator" {
  name = "ran"
}

module "gnbsim" {
  source = "git::https://github.com/canonical/sdcore-gnbsim-k8s-operator//terraform"

  model      = juju_model.ran-simulator.name
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
  model = juju_model.ran-simulator.name

  application {
    name     = module.gnbsim.app_name
    endpoint = module.gnbsim.requires.fiveg_core_gnb
  }

  application {
    offer_url = module.sdcore.nms_fiveg_core_gnb_offer_url
  }
}
