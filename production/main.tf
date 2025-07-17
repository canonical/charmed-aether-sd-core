module "cos-lite" {
  source = "git::https://github.com/canonical/terraform-juju-sdcore//modules/external/cos-lite"

  model_name               = "cos-lite"
  deploy_cos_configuration = true
  cos_configuration_config = {
    git_repo                = "https://github.com/canonical/sdcore-cos-configuration"
    git_branch              = "main"
    grafana_dashboards_path = "grafana_dashboards/sdcore/"
  }
}

resource "juju_model" "control-plane" {
  name = "control-plane"

  depends_on = [module.cos-lite]
}

module "sdcore-control-plane" {
  source = "git::https://github.com/canonical/terraform-juju-sdcore//modules/sdcore-control-plane-k8s"

  model = juju_model.control-plane.name

  amf_config = {
    external-amf-ip       = "${var.amf_ip}"
    external-amf-hostname = "${var.amf_hostname}"
  }
  traefik_config = {
    routing_mode      = "subdomain"
    external_hostname = "${var.nms_domainname}"
  }

  depends_on = [juju_model.control-plane]
}

resource "juju_model" "user-plane" {
  name = "user-plane"

  depends_on = [module.sdcore-control-plane]
}

module "sdcore-user-plane" {
  source = "git::https://github.com/canonical/terraform-juju-sdcore//modules/sdcore-user-plane-k8s"

  model = juju_model.user-plane.name

  upf_config = {
    cni-type              = "vfioveth"
    upf-mode              = "dpdk"
    access-gateway-ip     = "${var.upf_access_gateway_ip}"
    access-ip             = "${var.upf_access_gateway_ip}"
    core-gateway-ip       = "${var.upf_access_gateway_ip}"
    core-ip               = "${var.upf_access_gateway_ip}"
    external-upf-hostname = "${var.upf_hostname}"
    enable-hw-checksum    = "${var.upf_enable_hw_checksum}"
    access-interface-mac-address = "${var.upf_access_mac}"
    core-interface-mac-address = "${var.upf_core_mac}"
    gnb-subnet            = "${var.gnb_subnet}"
    core-ip-masquerade    = "${var.upf_enable_nat}"
  }

  depends_on = [juju_model.user-plane]
}

resource "juju_integration" "nms-upf" {
  model = juju_model.control-plane.name

  application {
    name     = module.sdcore-control-plane.nms_app_name
    endpoint = module.sdcore-control-plane.fiveg_n4_endpoint
  }

  application {
    offer_url = module.sdcore-user-plane.upf_fiveg_n4_offer_url
  }
}

resource "juju_integration" "control-plane-prometheus" {
  model = juju_model.control-plane.name

  application {
    name     = module.sdcore-control-plane.grafana_agent_app_name
    endpoint = module.sdcore-control-plane.send_remote_write_endpoint
  }

  application {
    offer_url = module.cos-lite.prometheus_remote_write_offer_url
  }
}

resource "juju_integration" "control-plane-loki" {
  model = juju_model.control-plane.name

  application {
    name     = module.sdcore-control-plane.grafana_agent_app_name
    endpoint = module.sdcore-control-plane.logging_consumer_endpoint
  }

  application {
    offer_url = module.cos-lite.loki_logging_offer_url
  }
}

resource "juju_integration" "user-plane-prometheus" {
  model = juju_model.user-plane.name

  application {
    name     = module.sdcore-user-plane.grafana_agent_app_name
    endpoint = module.sdcore-user-plane.send_remote_write_endpoint
  }

  application {
    offer_url = module.cos-lite.prometheus_remote_write_offer_url
  }
}

resource "juju_integration" "user-plane-loki" {
  model = juju_model.user-plane.name

  application {
    name     = module.sdcore-user-plane.grafana_agent_app_name
    endpoint = module.sdcore-user-plane.logging_consumer_endpoint
  }

  application {
    offer_url = module.cos-lite.loki_logging_offer_url
  }
}
