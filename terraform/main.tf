terraform {
  required_providers {
    lxd = {
      source  = "terraform-lxd/lxd"
      version = "2.4.0"
    }
  }
}

provider "lxd" {
}

resource "lxd_storage_pool" "sdcore-pool" {
  name   = "sdcore-pool"
  driver = "dir"
}

resource "lxd_network" "sdcore-mgmt" {
  name = "sdcore-mgmt"
  type = "bridge"

  config = {
    "ipv4.address" = "10.201.0.1/24"
    "ipv4.nat"     = "true"
    "ipv6.address" = "none"
    "dns.mode" = "managed"
    "dns.domain" = "mgmt.local"
    "raw.dnsmasq" = <<-EOF
        host-record=amf.mgmt.local,10.201.0.52
        host-record=upf.mgmt.local,10.201.0.200
    EOF
  }
}

resource "lxd_network" "sdcore-access" {
  name = "sdcore-access"
  type = "bridge"

  config = {
    "ipv4.address" = "10.202.0.1/24"
    "ipv4.nat"     = "false"
    "ipv6.address" = "none"
    "dns.mode"     = "none"
  }
}

resource "lxd_network" "sdcore-core" {
  name = "sdcore-core"
  type = "bridge"

  config = {
    "ipv4.address" = "10.203.0.1/24"
    "ipv4.nat"     = "true"
    "ipv6.address" = "none"
    "dns.mode"     = "none"
  }
}

resource "lxd_network" "sdcore-ran" {
  name = "sdcore-ran"
  type = "bridge"

  config = {
    "ipv4.address" = "10.204.0.1/24"
    "ipv4.nat"     = "false"
    "ipv6.address" = "none"
    "dns.mode"     = "none"
  }
}

resource "tls_private_key" "juju-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "lxd_instance" "control-plane" {
  name  = "control-plane"
  image = "ubuntu:24.04"
  type  = "virtual-machine"

  config = {
    "boot.autostart" = true
  }

  limits = {
    cpu    = 4
    memory = "8GB"
  }

  device {
    type = "disk"
    name = "root"

    properties = {
      pool = "sdcore-pool"
      path = "/"
      size = "40GB"
    }
  }

  device {
    type = "nic"
    name = "eth0"

    properties = {
      network        = "sdcore-mgmt"
      "ipv4.address" = "10.201.0.101"
    }
  }

  file {
    source_path        = "files/k8s/bootstrap-config.yml"
    target_path        = "/home/ubuntu/bootstrap-config.yml"
    uid                = 1000
    gid                = 1000
    create_directories = true
  }

  execs = {
    "00-wait-for-boot" = {
      command = ["systemctl", "is-system-running", "--wait", "--quiet"]
      trigger = "on_start"
    }
    "01-install-k8s" = {
      command       = ["snap", "install", "k8s", "--channel=1.33-classic/stable", "--classic"]
      trigger       = "once"
      fail_on_error = true
    }
    "02-bootstrap-k8s" = {
      command       = ["k8s", "bootstrap", "--file", "/home/ubuntu/bootstrap-config.yml"]
      trigger       = "once"
      fail_on_error = true
    }
    "03-k8s-set-load-balancer-cidrs" = {
      command       = ["k8s", "set", "load-balancer.cidrs=10.201.0.52-10.201.0.53"]
      trigger       = "once"
    }
    "04-wait-for-k8s" = {
      command       = ["k8s", "status", "--wait-ready", "--timeout", "5m"]
      trigger       = "once"
      fail_on_error = true
    }
    "05-get-k8s-config" = {
      command       = ["k8s", "config"]
      trigger       = "once"
      fail_on_error = true
      record_output = true
    }
  }

  timeouts = {
    read   = "10m"
    create = "10m"
    update = "10m"
    delete = "10m"
  }

  depends_on = [
    lxd_storage_pool.sdcore-pool,
    lxd_network.sdcore-mgmt
  ]
}

resource "lxd_instance_file" "control-plane-pubkey" {
  instance    = lxd_instance.control-plane.name
  content     = tls_private_key.juju-key.public_key_openssh
  target_path = "/home/ubuntu/.ssh/authorized_keys"
  uid         = 1000
  gid         = 1000
  mode        = "0600"

  depends_on = [
    lxd_instance.control-plane,
    tls_private_key.juju-key
  ]
}

resource "lxd_instance_file" "control-plane-privkey" {
  instance    = lxd_instance.control-plane.name
  content     = tls_private_key.juju-key.private_key_openssh
  target_path = "/home/ubuntu/.ssh/id_rsa"
  uid         = 1000
  gid         = 1000
  mode        = "0600"

  depends_on = [
    lxd_instance.control-plane,
    tls_private_key.juju-key
  ]
}

resource "lxd_instance" "user-plane" {
  name  = "user-plane"
  image = "ubuntu:24.04"
  type  = "virtual-machine"

  config = {
    "boot.autostart"            = true
    "cloud-init.network-config" = file("user-plane-network-config.yml")
  }

  limits = {
    cpu    = 4
    memory = "12GB"
  }

  device {
    type = "disk"
    name = "root"

    properties = {
      pool = "sdcore-pool"
      path = "/"
      size = "20GB"
    }
  }

  device {
    type = "nic"
    name = "eth0"

    properties = {
      network        = "sdcore-mgmt"
      "ipv4.address" = "10.201.0.102"
    }
  }

  device {
    type = "nic"
    name = "eth1"

    properties = {
      network        = "sdcore-core"
      "ipv4.address" = "10.203.0.100"
    }
  }

  device {
    type = "nic"
    name = "eth2"

    properties = {
      network        = "sdcore-access"
      "ipv4.address" = "10.202.0.100"
      #"ipv4.routes" = "10.204.0.0/24"
    }
  }

  file {
    source_path = "files/user-plane/rc.local"
    target_path = "/etc/rc.local"
  }

  file {
    source_path = "files/user-plane/sriovdp-config.yml"
    target_path = "/home/ubuntu/sriovdp-config.yml"
    uid                = 1000
    gid                = 1000
    create_directories = true
  }

  file {
    source_path        = "files/k8s/bootstrap-config.yml"
    target_path        = "/home/ubuntu/bootstrap-config.yml"
    uid                = 1000
    gid                = 1000
    create_directories = true
  }

  execs = {
    "00-wait-for-boot" = {
      command = ["systemctl", "is-system-running", "--wait", "--quiet"]
      trigger = "on_change"
    }
    "01-update-apt-cache" = {
      command       = ["apt", "update"]
      trigger       = "on_start"
      fail_on_error = true
    }
    "02-install-driverctl" = {
      command       = ["apt", "install", "-y", "driverctl"]
      trigger       = "once"
      fail_on_error = true
    }
    "03-configure-hugepages" = {
      command       = ["/bin/sh", "-c", "sed -i \"s/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX='default_hugepagesz=1G hugepages=2'/\" /etc/default/grub"]
      trigger       = "once"
      fail_on_error = true
    }
    "04-update-grub" = {
      command       = ["update-grub"]
      trigger       = "once"
      fail_on_error = true
    }
    "05-get-core-mac-address" = {
      command       = ["cat", "/sys/class/net/enp6s0/address"]
      trigger       = "once"
      fail_on_error = true
      record_output = true
    }
    "06-get-access-mac-address" = {
      command       = ["cat", "/sys/class/net/enp7s0/address"]
      trigger       = "once"
      fail_on_error = true
      record_output = true
    }
    "07-run-rc.local" = {
      command       = ["/etc/rc.local"]
      trigger       = "on_start"
      fail_on_error = true
    }
    "08-install-k8s" = {
      command       = ["snap", "install", "k8s", "--channel=1.33-classic/stable", "--classic"]
      trigger       = "once"
      fail_on_error = true
    }
    "09-bootstrap-k8s" = {
      command       = ["k8s", "bootstrap", "--file", "/home/ubuntu/bootstrap-config.yml"]
      trigger       = "once"
      fail_on_error = true
    }
    "10-k8s-add-multus" = {
      command       = ["k8s", "kubectl", "apply", "-f", "https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml"]
      trigger       = "once"
      fail_on_error = true
    }
    "11-k8s-set-sriov-config" = {
      command       = ["k8s", "kubectl", "apply", "-f", "/home/ubuntu/sriovdp-config.yml"]
      trigger       = "once"
      fail_on_error = true
    }
    "12-k8s-add-sriov-device-plugin" = {
      command       = ["k8s", "kubectl", "apply", "-f", "https://raw.githubusercontent.com/k8snetworkplumbingwg/sriov-network-device-plugin/master/deployments/sriovdp-daemonset.yaml"]
      trigger       = "once"
    }
    "13-copy-vfioveth-cni-binary" = {
      command       = ["wget", "-O", "/opt/cni/bin/vfioveth", "https://raw.githubusercontent.com/opencord/omec-cni/master/vfioveth"]
      trigger       = "once"
    }
    "14-chmod-vfioveth-cni-binary" = {
      command       = ["chmod", "+x", "/opt/cni/bin/vfioveth"]
      trigger       = "once"
    }
    "15-k8s-set-load-balancer-cidrs" = {
      command       = ["k8s", "set", "load-balancer.cidrs=10.201.0.200/32"]
      trigger       = "once"
    }
    "16-wait-for-k8s" = {
      command       = ["k8s", "status", "--wait-ready", "--timeout", "5m"]
      trigger       = "once"
      fail_on_error = true
    }
    "17-get-k8s-config" = {
      command       = ["k8s", "config"]
      trigger       = "once"
      fail_on_error = true
      record_output = true
    }
    "18-reboot" = {
      command       = ["reboot"]
      trigger       = "once"
      fail_on_error = true
    }
  }

  timeouts = {
    read   = "10m"
    create = "10m"
    update = "10m"
    delete = "10m"
  }

  depends_on = [
    lxd_storage_pool.sdcore-pool,
    lxd_network.sdcore-mgmt,
    lxd_network.sdcore-core,
    lxd_network.sdcore-access,
    tls_private_key.juju-key,
    lxd_instance.control-plane
  ]
}

resource "lxd_instance_file" "user-plane-pubkey" {
  instance    = lxd_instance.user-plane.name
  content     = tls_private_key.juju-key.public_key_openssh
  target_path = "/home/ubuntu/.ssh/authorized_keys"
  uid         = 1000
  gid         = 1000
  mode        = "0600"

  depends_on = [
    lxd_instance.user-plane,
    tls_private_key.juju-key
  ]
}

resource "lxd_instance_file" "user-plane-privkey" {
  instance    = lxd_instance.user-plane.name
  content     = tls_private_key.juju-key.private_key_openssh
  target_path = "/home/ubuntu/.ssh/id_rsa"
  uid         = 1000
  gid         = 1000
  mode        = "0600"

  depends_on = [
    lxd_instance.user-plane,
    tls_private_key.juju-key
  ]
}

resource "lxd_instance" "gnbsim" {
  name  = "gnbsim"
  image = "ubuntu:24.04"
  type  = "virtual-machine"

  config = {
    "boot.autostart"            = true
    "cloud-init.network-config" = file("gnbsim-network-config.yml")
  }

  limits = {
    cpu    = 2
    memory = "3GB"
  }

  device {
    type = "disk"
    name = "root"

    properties = {
      pool = "sdcore-pool"
      path = "/"
      size = "20GB"
    }
  }

  device {
    type = "nic"
    name = "eth0"

    properties = {
      network        = "sdcore-mgmt"
      "ipv4.address" = "10.201.0.103"
    }
  }

  device {
    type = "nic"
    name = "eth1"

    properties = {
      network        = "sdcore-ran"
      "ipv4.address" = "10.204.0.100"
    }
  }

  file {
    source_path = "files/gnbsim/rc.local"
    target_path = "/etc/rc.local"
  }

  file {
    source_path        = "files/k8s/bootstrap-config.yml"
    target_path        = "/home/ubuntu/bootstrap-config.yml"
    uid                = 1000
    gid                = 1000
    create_directories = true
  }

  execs = {
    "00-wait-for-boot" = {
      command = ["systemctl", "is-system-running", "--wait", "--quiet"]
      trigger = "on_start"
    }
    "01-install-k8s" = {
      command       = ["snap", "install", "k8s", "--channel=1.33-classic/stable", "--classic"]
      trigger       = "once"
      fail_on_error = true
    }
    "02-boostrap-k8s" = {
      command       = ["k8s", "bootstrap", "--file", "/home/ubuntu/bootstrap-config.yml"]
      trigger       = "once"
      fail_on_error = true
    }
    "03-k8s-add-multus" = {
      command       = ["k8s", "kubectl", "apply", "-f", "https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml"]
      trigger       = "once"
      fail_on_error = true
    }
    "04-wait-for-k8s" = {
      command       = ["k8s", "status", "--wait-ready", "--timeout", "5m"]
      trigger       = "once"
      fail_on_error = true
    }
    "05-get-k8s-config" = {
      command       = ["k8s", "config"]
      trigger       = "once"
      fail_on_error = true
      record_output = true
    }
    "06-run-rc.local" = {
      command       = ["/etc/rc.local"]
      trigger       = "on_start"
      fail_on_error = true
    }
  }

  timeouts = {
    read   = "10m"
    create = "10m"
    update = "10m"
    delete = "10m"
  }

  depends_on = [
    lxd_storage_pool.sdcore-pool,
    lxd_network.sdcore-mgmt,
    lxd_network.sdcore-ran,
    tls_private_key.juju-key,
    lxd_instance.control-plane,
    lxd_instance.user-plane
  ]
}

resource "lxd_instance_file" "gnbsim-pubkey" {
  instance    = lxd_instance.gnbsim.name
  content     = tls_private_key.juju-key.public_key_openssh
  target_path = "/home/ubuntu/.ssh/authorized_keys"
  uid         = 1000
  gid         = 1000
  mode        = "0600"

  depends_on = [
    lxd_instance.gnbsim,
    tls_private_key.juju-key
  ]
}

resource "lxd_instance_file" "gnbsim-privkey" {
  instance    = lxd_instance.gnbsim.name
  content     = tls_private_key.juju-key.private_key_openssh
  target_path = "/home/ubuntu/.ssh/id_rsa"
  uid         = 1000
  gid         = 1000
  mode        = "0600"

  depends_on = [
    lxd_instance.gnbsim,
    tls_private_key.juju-key
  ]
}

resource "lxd_instance" "juju-controller" {
  name  = "juju-controller"
  image = "ubuntu:24.04"
  type  = "virtual-machine"

  config = {
    "boot.autostart" = true
  }

  limits = {
    cpu    = 4
    memory = "6GB"
  }

  device {
    type = "disk"
    name = "root"

    properties = {
      pool = "sdcore-pool"
      path = "/"
      size = "40GB"
    }
  }

  device {
    type = "nic"
    name = "eth0"

    properties = {
      network        = "sdcore-mgmt"
      "ipv4.address" = "10.201.0.104"
    }
  }

  file {
    content            = lxd_instance.control-plane.execs["05-get-k8s-config"].stdout
    target_path        = "/home/ubuntu/control-plane-cluster.yaml"
    uid                = 1000
    gid                = 1000
    create_directories = true
  }

  file {
    content            = lxd_instance.user-plane.execs["17-get-k8s-config"].stdout
    target_path        = "/home/ubuntu/user-plane-cluster.yaml"
    uid                = 1000
    gid                = 1000
    create_directories = true
  }

  file {
    content            = lxd_instance.gnbsim.execs["05-get-k8s-config"].stdout
    target_path        = "/home/ubuntu/gnb-cluster.yaml"
    uid                = 1000
    gid                = 1000
    create_directories = true
  }

  file {
    source_path        = "files/k8s/bootstrap-config.yml"
    target_path        = "/home/ubuntu/bootstrap-config.yml"
    uid                = 1000
    gid                = 1000
    create_directories = true
  }

  execs = {
    "00-wait-for-boot" = {
      command = ["systemctl", "is-system-running", "--wait", "--quiet"]
      trigger = "on_start"
    }
    "01-install-k8s" = {
      command       = ["snap", "install", "k8s", "--channel=1.33-classic/stable", "--classic"]
      trigger       = "once"
      fail_on_error = true
    }
    "02-bootstrap-k8s" = {
      command       = ["k8s", "bootstrap", "--file", "/home/ubuntu/bootstrap-config.yml"]
      trigger       = "once"
      fail_on_error = true
    }
    "03-k8s-set-load-balancer" = {
      command       = ["k8s", "set", "load-balancer.cidrs=10.201.0.50-10.201.0.51"]
      trigger       = "once"
    }
    "04-wait-for-k8s" = {
      command       = ["k8s", "status", "--wait-ready", "--timeout", "5m"]
      trigger       = "once"
      fail_on_error = true
    }
    "05-create-k8s-config-folder" = {
      command       = ["mkdir", "-p", "/home/ubuntu/.kube"]
      uid           = 1000
      gid           = 1000
      trigger       = "once"
      fail_on_error = true
    }
    "06-save-k8s-config" = {
      command       = ["/bin/sh", "-c", "su ubuntu -c \"sudo k8s config > /home/ubuntu/.kube/config\""]
      trigger       = "once"
      fail_on_error = true
    }
    "07-install-juju" = {
      command       = ["snap", "install", "juju", "--channel=3.6/stable"]
      trigger       = "once"
    }
    "08-create-juju-shared-folder" = {
      command       = ["mkdir", "-p", "/home/ubuntu/.local/share/juju"]
      uid           = 1000
      gid           = 1000
      trigger       = "once"
    }
    "09-save-k8s-credentials" = {
      command       = ["/bin/sh", "-c", "su ubuntu -c \"sudo k8s config > /home/ubuntu/.local/share/juju/credentials.yaml\""]
      trigger       = "once"
      fail_on_error = true
    }
    "10-bootstrap-juju" = {
      command       = ["/bin/sh", "-c", "su ubuntu -c \"juju bootstrap k8s --config controller-service-type=loadbalancer sdcore\""]
      trigger       = "once"
      fail_on_error = true
    }
    "11-add-control-plane-cluster" = {
      command       = ["/bin/sh", "-c", "su ubuntu -c \"juju add-k8s control-plane-cluster --controller sdcore\""]
      trigger       = "once"
      fail_on_error = true
      environment   = {
        "KUBECONFIG" = "/home/ubuntu/control-plane-cluster.yaml"
      }
    }
    "12-add-control-plane-model" = {
      command       = ["/bin/sh", "-c", "juju add-model control-plane control-plane-cluster"]
      uid           = 1000
      gid           = 1000
      trigger       = "once"
      fail_on_error = true
    }
    "13-add-user-plane-cluster" = {
      command       = ["/bin/sh", "-c", "su ubuntu -c \"juju add-k8s user-plane-cluster --controller sdcore\""]
      trigger       = "once"
      fail_on_error = true
      environment   = {
        "KUBECONFIG" = "/home/ubuntu/user-plane-cluster.yaml"
      }
    }
    "14-add-user-plane-model" = {
      command       = ["/bin/sh", "-c", "juju add-model user-plane user-plane-cluster"]
      uid           = 1000
      gid           = 1000
      trigger       = "once"
      fail_on_error = true
    }
    "15-add-gnb-cluster" = {
      command       = ["/bin/sh", "-c", "su ubuntu -c \"juju add-k8s gnb-cluster --controller sdcore\""]
      trigger       = "once"
      fail_on_error = true
      environment   = {
        "KUBECONFIG" = "/home/ubuntu/gnb-cluster.yaml"
      }
    }
    "16-add-gnbsim-model" = {
      command       = ["/bin/sh", "-c", "juju add-model gnbsim gnb-cluster"]
      uid           = 1000
      gid           = 1000
      trigger       = "once"
      fail_on_error = true
    }
    "17-install-terraform" = {
      command       = ["snap", "install", "terraform", "--classic"]
      trigger       = "once"
      fail_on_error = true
    }
  }

  timeouts = {
    read   = "15m"
    create = "15m"
    update = "15m"
    delete = "15m"
  }

  depends_on = [
    lxd_storage_pool.sdcore-pool,
    lxd_network.sdcore-mgmt,
    lxd_instance.control-plane,
    lxd_instance.user-plane,
    lxd_instance.gnbsim,
    tls_private_key.juju-key
  ]
}

resource "lxd_instance_file" "juju-controller-pubkey" {
  instance    = lxd_instance.juju-controller.name
  content     = tls_private_key.juju-key.public_key_openssh
  target_path = "/home/ubuntu/.ssh/authorized_keys"
  uid         = 1000
  gid         = 1000
  mode        = "0600"

  depends_on = [
    lxd_instance.juju-controller,
    tls_private_key.juju-key
  ]
}

resource "lxd_instance_file" "juju-controller-privkey" {
  instance    = lxd_instance.juju-controller.name
  content     = tls_private_key.juju-key.private_key_openssh
  target_path = "/home/ubuntu/.ssh/id_rsa"
  uid         = 1000
  gid         = 1000
  mode        = "0600"

  depends_on = [
    lxd_instance.juju-controller,
    tls_private_key.juju-key
  ]
}
