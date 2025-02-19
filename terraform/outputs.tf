# Copyright 2025 Canonical Ltd.
# See LICENSE file for licensing details.

output "core-mac-address" {
  value = {
    "out" = lxd_instance.user-plane.execs["05-get-core-mac-address"].stdout
  }
}

output "access-mac-address" {
  value = {
    "out" = lxd_instance.user-plane.execs["06-get-access-mac-address"].stdout
  }
}

output "control-plane-config" {
  value = {
    "out" = lxd_instance.control-plane.execs["08-get-microk8s-config"].stdout
    "err" = lxd_instance.control-plane.execs["08-get-microk8s-config"].stderr
  }
}

output "user-plane-config" {
  value = {
    "out" = lxd_instance.user-plane.execs["20-get-microk8s-config"].stdout
    "err" = lxd_instance.user-plane.execs["20-get-microk8s-config"].stderr
  }
}

output "gnbsim-config" {
  value = {
    "out" = lxd_instance.gnbsim.execs["09-get-microk8s-config"].stdout
    "err" = lxd_instance.gnbsim.execs["09-get-microk8s-config"].stderr
  }
}
