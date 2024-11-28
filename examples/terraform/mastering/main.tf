data "juju_model" "control-plane" {
  name = "control-plane"
}

module "sdcore-control-plane" {
  source = "git::https://github.com/canonical/terraform-juju-sdcore//modules/sdcore-control-plane-k8s?ref=v1.5"

  model = data.juju_model.control-plane.name

  amf_config = {
    external-amf-ip       = "10.201.0.52"
    external-amf-hostname = "amf.mgmt"
  }
  traefik_config = {
    routing_mode      = "subdomain"
    external_hostname = "10.201.0.53.nip.io"
  }
}

data "juju_model" "user-plane" {
  name = "user-plane"
}

module "sdcore-user-plane" {
  source = "git::https://github.com/canonical/terraform-juju-sdcore//modules/sdcore-user-plane-k8s?ref=v1.5"

  model = data.juju_model.user-plane.name

  upf_config = {
    cni-type              = "macvlan"
    access-gateway-ip     = "10.202.0.1"
    access-interface      = "access"
    access-ip             = "10.202.0.10/24"
    core-gateway-ip       = "10.203.0.1"
    core-interface        = "core"
    core-ip               = "10.203.0.10/24"
    external-upf-hostname = "upf.mgmt"
    gnb-subnet            = "10.204.0.0/24"
  }
}

data "juju_model" "gnbsim" {
  name = "gnbsim"
}

module "gnbsim" {
  source = "git::https://github.com/canonical/sdcore-gnbsim-k8s-operator//terraform?ref=v1.5"

  model = data.juju_model.gnbsim.name

  config = {
    gnb-interface           = "ran"
    gnb-ip-address          = "10.204.0.10/24"
    icmp-packet-destination = "8.8.8.8"
    upf-gateway             = "10.204.0.1"
    upf-subnet              = "10.202.0.0/24"
  }
}

resource "juju_integration" "gnbsim-amf" {
  model = data.juju_model.gnbsim.name

  application {
    name     = module.gnbsim.app_name
    endpoint = module.gnbsim.requires.fiveg_n2
  }

  application {
    offer_url = module.sdcore-control-plane.amf_fiveg_n2_offer_url
  }
}

resource "juju_offer" "gnbsim-fiveg-gnb-identity" {
  model            = data.juju_model.gnbsim.name
  application_name = module.gnbsim.app_name
  endpoint         = module.gnbsim.provides.fiveg_gnb_identity
}

resource "juju_integration" "nms-gnbsim" {
  model = data.juju_model.control-plane.name

  application {
    name     = module.sdcore-control-plane.nms_app_name
    endpoint = module.sdcore-control-plane.fiveg_gnb_identity_endpoint
  }

  application {
    offer_url = juju_offer.gnbsim-fiveg-gnb-identity.url
  }
}

resource "juju_integration" "nms-upf" {
  model = data.juju_model.control-plane.name

  application {
    name     = module.sdcore-control-plane.nms_app_name
    endpoint = module.sdcore-control-plane.fiveg_n4_endpoint
  }

  application {
    offer_url = module.sdcore-user-plane.upf_fiveg_n4_offer_url
  }
}

module "cos-lite" {
  source = "git::https://github.com/canonical/terraform-juju-sdcore//modules/external/cos-lite?ref=v1.5"

  model_name               = "cos-lite"
  deploy_cos_configuration = true
  cos_configuration_config = {
    git_repo                 = "https://github.com/canonical/sdcore-cos-configuration"
    git_branch               = "main"
    grafana_dashboards_path  = "grafana_dashboards/sdcore/"
  }
}

resource "juju_integration" "control-plane-prometheus" {
  model = data.juju_model.control-plane.name

  application {
    name     = module.sdcore-control-plane.grafana_agent_app_name
    endpoint = module.sdcore-control-plane.send_remote_write_endpoint
  }

  application {
    offer_url = module.cos-lite.prometheus_remote_write_offer_url
  }
}

resource "juju_integration" "control-plane-loki" {
  model = data.juju_model.control-plane.name

  application {
    name     = module.sdcore-control-plane.grafana_agent_app_name
    endpoint = module.sdcore-control-plane.logging_consumer_endpoint
  }

  application {
    offer_url = module.cos-lite.loki_logging_offer_url
  }
}

resource "juju_integration" "user-plane-prometheus" {
  model = data.juju_model.user-plane.name

  application {
    name     = module.sdcore-user-plane.grafana_agent_app_name
    endpoint = module.sdcore-user-plane.send_remote_write_endpoint
  }

  application {
    offer_url = module.cos-lite.prometheus_remote_write_offer_url
  }
}

resource "juju_integration" "user-plane-loki" {
  model = data.juju_model.user-plane.name

  application {
    name     = module.sdcore-user-plane.grafana_agent_app_name
    endpoint = module.sdcore-user-plane.logging_consumer_endpoint
  }

  application {
    offer_url = module.cos-lite.loki_logging_offer_url
  }
}
