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

  execs = {
    "00-wait-for-boot" = {
      command = ["systemctl", "is-system-running", "--wait", "--quiet"]
      trigger = "on_start"
    }
    "01-install-microk8s" = {
      command       = ["snap", "install", "microk8s", "--channel=1.31-strict/stable"]
      trigger       = "once"
      fail_on_error = true
    }
    "02-wait-for-microk8s" = {
      command       = ["microk8s", "status", "--wait"]
      trigger       = "once"
      fail_on_error = true
    }
    "03-microk8s-disable-default-dns" = {
      command       = ["microk8s", "disable", "dns"]
      trigger       = "once"
    }
    "04-microk8s-enable-custom-dns" = {
      command       = ["microk8s", "enable", "dns:10.201.0.1"]
      trigger       = "once"
    }
    "05-microk8s-enable-hostpath-storage" = {
      command       = ["microk8s", "enable", "hostpath-storage"]
      trigger       = "once"
    }
    "06-microk8s-enable-metallb" = {
      command       = ["microk8s", "enable", "metallb:10.201.0.52-10.201.0.53"]
      trigger       = "once"
    }
    "07-add-ubuntu-user-to-snap_microk8s-group" = {
      command       = ["usermod", "-a", "-G", "snap_microk8s", "ubuntu"]
      trigger       = "once"
      fail_on_error = true
    }
    "08-get-microk8s-config" = {
      command       = ["microk8s.config"]
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
    source_path = "files/user-plane/sriov_resources.json"
    target_path = "/root/sriov_resources.json"
  }

  file {
    source_path = "files/user-plane/sriov-cni-daemonset.yaml"
    target_path = "/root/sriov-cni-daemonset.yaml"
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
    "08-install-microk8s" = {
      command       = ["snap", "install", "microk8s", "--channel=1.31/stable", "--classic"]
      trigger       = "once"
      fail_on_error = true
    }
    "09-wait-for-microk8s" = {
      command       = ["microk8s", "status", "--wait"]
      trigger       = "once"
      fail_on_error = true
    }
    "10-microk8s-get-community-addons" = {
      command       = ["microk8s", "addons", "repo", "add", "community", "https://github.com/Gmerold/microk8s-community-addons", "--reference", "fix-sriov-addon"]
      trigger       = "once"
      fail_on_error = true
    }
    "11-microk8s-enable-hostpath-storage" = {
      command       = ["microk8s", "enable", "hostpath-storage"]
      trigger       = "once"
    }
    "12-microk8s-enable-multus" = {
      command       = ["microk8s", "enable", "multus"]
      trigger       = "once"
    }
    "13-microk8s-enable-sriov-device-plugin" = {
      command       = ["microk8s", "enable", "sriov-device-plugin", "-r", "/root/sriov_resources.json"]
      trigger       = "once"
    }
    "14-deploy-sriov-cni" = {
      command       = ["microk8s.kubectl", "create", "-f", "/root/sriov-cni-daemonset.yaml"]
      trigger       = "once"
    }
    "15-microk8s-enable-metallb" = {
      command       = ["microk8s", "enable", "metallb:10.201.0.200/32"]
      trigger       = "once"
    }
    "16-microk8s-disable-default-dns" = {
      command       = ["microk8s", "disable", "dns"]
      trigger       = "once"
    }
    "17-microk8s-enable-custom-dns" = {
      command       = ["microk8s", "enable", "dns:10.201.0.1"]
      trigger       = "once"
    }
    "18-add-ubuntu-user-to-snap_microk8s-group" = {
      command       = ["usermod", "-a", "-G", "microk8s", "ubuntu"]
      trigger       = "once"
      fail_on_error = true
    }
    "19-get-microk8s-config" = {
      command       = ["microk8s.config"]
      trigger       = "once"
      fail_on_error = true
      record_output = true
    }
    "20-reboot" = {
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

  execs = {
    "00-wait-for-boot" = {
      command = ["systemctl", "is-system-running", "--wait", "--quiet"]
      trigger = "on_start"
    }
    "01-install-microk8s" = {
      command       = ["snap", "install", "microk8s", "--channel=1.31-strict/stable"]
      trigger       = "once"
      fail_on_error = true
    }
    "02-wait-for-microk8s" = {
      command       = ["microk8s", "status", "--wait"]
      trigger       = "once"
      fail_on_error = true
    }
    "03-microk8s-get-community-addons" = {
      command       = ["microk8s", "addons", "repo", "add", "community", "https://github.com/canonical/microk8s-community-addons", "--reference", "feat/strict-fix-multus"]
      trigger       = "once"
      fail_on_error = true
    }
    "04-microk8s-enable-hostpath-storeage" = {
      command       = ["microk8s", "enable", "hostpath-storage"]
      trigger       = "once"
    }
    "05-microk8s-enable-multus" = {
      command       = ["microk8s", "enable", "multus"]
      trigger       = "once"
    }
    "06-microk8s-disable-default-dns" = {
      command       = ["microk8s", "disable", "dns"]
      trigger       = "once"
    }
    "07-microk8s-enable-custom-dns" = {
      command       = ["microk8s", "enable", "dns:10.201.0.1"]
      trigger       = "once"
    }
    "08-add-ubuntu-user-to-snap_microk8s-group" = {
      command       = ["usermod", "-a", "-G", "snap_microk8s", "ubuntu"]
      trigger       = "once"
      fail_on_error = true
    }
    "09-get-microk8s-config" = {
      command       = ["microk8s.config"]
      trigger       = "once"
      fail_on_error = true
      record_output = true
    }
    "10-run-rc.local" = {
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
    content            = lxd_instance.control-plane.execs["08-get-microk8s-config"].stdout
    target_path        = "/home/ubuntu/control-plane-cluster.yaml"
    uid                = 1000
    gid                = 1000
    create_directories = true
  }

  file {
    content            = lxd_instance.user-plane.execs["19-get-microk8s-config"].stdout
    target_path        = "/home/ubuntu/user-plane-cluster.yaml"
    uid                = 1000
    gid                = 1000
    create_directories = true
  }

  file {
    content            = lxd_instance.gnbsim.execs["09-get-microk8s-config"].stdout
    target_path        = "/home/ubuntu/gnb-cluster.yaml"
    uid                = 1000
    gid                = 1000
    create_directories = true
  }

  execs = {
    "00-wait-for-boot" = {
      command = ["systemctl", "is-system-running", "--wait", "--quiet"]
      trigger = "on_start"
    }
    "01-install-microk8s" = {
      command       = ["snap", "install", "microk8s", "--channel=1.31-strict/stable"]
      trigger       = "once"
      fail_on_error = true
    }
    "02-wait-for-microk8s" = {
      command       = ["microk8s", "status", "--wait"]
      trigger       = "once"
      fail_on_error = true
    }
    "03-microk8s-disable-default-dns" = {
      command       = ["microk8s", "disable", "dns"]
      trigger       = "once"
    }
    "04-microk8s-enable-custom-dns" = {
      command       = ["microk8s", "enable", "dns:10.201.0.1"]
      trigger       = "once"
    }
    "05-microk8s-enable-hostpath-storeage" = {
      command       = ["microk8s", "enable", "hostpath-storage"]
      trigger       = "once"
    }
    "06-microk8s-enable-metallb" = {
      command       = ["microk8s", "enable", "metallb:10.201.0.50-10.201.0.51"]
      trigger       = "once"
    }
    "07-add-ubuntu-user-to-snap_microk8s-group" = {
      command       = ["usermod", "-a", "-G", "snap_microk8s", "ubuntu"]
      trigger       = "once"
      fail_on_error = true
    }
    "08-install-juju" = {
      command       = ["snap", "install", "juju", "--channel=3.6/stable"]
      trigger       = "once"
    }
    "09-create-juju-shared-folder" = {
      command       = ["mkdir", "-p", "/home/ubuntu/.local/share/juju"]
      uid           = 1000
      gid           = 1000
      trigger       = "once"
    }
    "10-bootstrap-juju" = {
      command       = ["/bin/sh", "-c", "su ubuntu -c \"juju bootstrap microk8s --config controller-service-type=loadbalancer sdcore\""]
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
