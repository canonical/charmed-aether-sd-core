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
    "dns.mode"     = "managed"
    "dns.domain"   = "mgmt.local"
    "raw.dnsmasq"  = <<-EOF
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
    lxd_instance.control-plane
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
    lxd_instance.control-plane
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

  depends_on = [
    lxd_storage_pool.sdcore-pool,
    lxd_network.sdcore-mgmt
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
    lxd_instance.juju-controller
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
    lxd_instance.juju-controller
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

  depends_on = [
    lxd_storage_pool.sdcore-pool,
    lxd_network.sdcore-mgmt,
    lxd_network.sdcore-ran
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
    lxd_instance.gnbsim
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
    lxd_instance.gnbsim
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

  depends_on = [
    lxd_storage_pool.sdcore-pool,
    lxd_network.sdcore-mgmt,
    lxd_network.sdcore-core,
    lxd_network.sdcore-access
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
    lxd_instance.user-plane
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
    lxd_instance.user-plane
  ]
}
