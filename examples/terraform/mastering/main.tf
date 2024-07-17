module "sdcore-control-plane" {
  source = "git::https://github.com/canonical/terraform-juju-sdcore//modules/sdcore-control-plane-k8s"

  model_name = "control-plane"
  create_model = false

  amf_config = {
    external-amf-ip       = "10.201.0.52"
    external-amf-hostname = "amf.mgmt"
  }
  traefik_config = {
    routing_mode = "subdomain"
    external_hostname = "10.201.0.53.nip.io"
  }
}

module "sdcore-user-plane" {
  source = "git::https://github.com/canonical/terraform-juju-sdcore//modules/sdcore-user-plane-k8s"

  model_name   = "user-plane"
  create_model = false

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

module "gnbsim" {
  source = "git::https://github.com/canonical/sdcore-gnbsim-k8s-operator//terraform"

  model_name = "gnbsim"

  config = {
    gnb-interface           = "ran"
    gnb-ip-address          = "10.204.0.10/24"
    icmp-packet-destination = "8.8.8.8"
    upf-gateway             = "10.204.0.1"
    upf-subnet              = "10.202.0.0/24"
  }
}

module "cos-lite" {
  source = "git::https://github.com/canonical/terraform-juju-sdcore//modules/external/cos-lite"

  model_name               = "cos-lite"
  deploy_cos_configuration = true
  cos_configuration_config = {
    git_repo                 = "https://github.com/canonical/sdcore-cos-configuration"
    git_branch               = "main"
    grafana_dashboards_path  = "grafana_dashboards/sdcore/"
  }
}

resource "juju_offer" "amf-fiveg-n2" {
  model            = "control-plane"
  application_name = module.sdcore-control-plane.amf_app_name
  endpoint         = module.sdcore-control-plane.fiveg_n2_endpoint
}

resource "juju_offer" "upf-fiveg-n4" {
  model            = "user-plane"
  application_name = module.sdcore-user-plane.upf_app_name
  endpoint         = module.sdcore-user-plane.fiveg_n4_endpoint
}

resource "juju_offer" "gnbsim-fiveg-gnb-identity" {
  model            = "gnbsim"
  application_name = module.gnbsim.app_name
  endpoint         = module.gnbsim.fiveg_gnb_identity_endpoint
}

resource "juju_offer" "prometheus-remote-write" {
  model            = module.cos-lite.model_name
  application_name = module.cos-lite.prometheus_app_name
  endpoint         = "receive-remote-write"
}

resource "juju_offer" "loki-logging" {
  model            = module.cos-lite.model_name
  application_name = module.cos-lite.loki_app_name
  endpoint         = "logging"
}

resource "juju_integration" "gnbsim-amf" {
  model = "gnbsim"

  application {
    name     = module.gnbsim.app_name
    endpoint = module.gnbsim.fiveg_n2_endpoint
  }

  application {
    offer_url = juju_offer.amf-fiveg-n2.url
  }
}

resource "juju_integration" "nms-gnbsim" {
  model = "control-plane"

  application {
    name     = module.sdcore-control-plane.nms_app_name
    endpoint = module.sdcore-control-plane.fiveg_gnb_identity_endpoint
  }

  application {
    offer_url = juju_offer.gnbsim-fiveg-gnb-identity.url
  }
}

resource "juju_integration" "nms-upf" {
  model = "control-plane"

  application {
    name     = module.sdcore-control-plane.nms_app_name
    endpoint = module.sdcore-control-plane.fiveg_n4_endpoint
  }

  application {
    offer_url = juju_offer.upf-fiveg-n4.url
  }
}

resource "juju_integration" "control-plane-prometheus" {
  model = "control-plane"

  application {
    name     = module.sdcore-control-plane.grafana_agent_app_name
    endpoint = module.sdcore-control-plane.send_remote_write_endpoint
  }

  application {
    offer_url = juju_offer.prometheus-remote-write.url
  }
}

resource "juju_integration" "control-plane-loki" {
  model = "control-plane"

  application {
    name     = module.sdcore-control-plane.grafana_agent_app_name
    endpoint = module.sdcore-control-plane.logging_consumer_endpoint
  }

  application {
    offer_url = juju_offer.loki-logging.url
  }
}

resource "juju_integration" "user-plane-prometheus" {
  model = "user-plane"

  application {
    name     = module.sdcore-user-plane.grafana_agent_app_name
    endpoint = module.sdcore-user-plane.send_remote_write_endpoint
  }

  application {
    offer_url = juju_offer.prometheus-remote-write.url
  }
}

resource "juju_integration" "user-plane-loki" {
  model = "user-plane"

  application {
    name     = module.sdcore-user-plane.grafana_agent_app_name
    endpoint = module.sdcore-user-plane.logging_consumer_endpoint
  }

  application {
    offer_url = juju_offer.loki-logging.url
  }
}
