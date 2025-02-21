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

# output "control-plane-cluster" {
#   value = {
#     "out" = lxd_instance.juju-controller.execs["11-add-control-plane-cluster"].stdout
#     "err" = lxd_instance.juju-controller.execs["11-add-control-plane-cluster"].stderr
#   }
# }
# output "control-plane-model" {
#   value = {
#     "out" = lxd_instance.juju-controller.execs["12-add-control-plane-model"].stdout
#     "err" = lxd_instance.juju-controller.execs["12-add-control-plane-model"].stderr
#   }
# }
#
# output "user-plane-cluster" {
#   value = {
#     "out" = lxd_instance.juju-controller.execs["13-add-user-plane-cluster"].stdout
#     "err" = lxd_instance.juju-controller.execs["13-add-user-plane-cluster"].stderr
#   }
# }
# output "user-plane-model" {
#   value = {
#     "out" = lxd_instance.juju-controller.execs["14-add-user-plane-model"].stdout
#     "err" = lxd_instance.juju-controller.execs["14-add-user-plane-model"].stderr
#   }
# }
#
# output "gnbsim-cluster" {
#   value = {
#     "out" = lxd_instance.juju-controller.execs["15-add-gnb-cluster"].stdout
#     "err" = lxd_instance.juju-controller.execs["15-add-gnb-cluster"].stderr
#   }
# }
# output "gnbsim-model" {
#   value = {
#     "out" = lxd_instance.juju-controller.execs["16-add-gnbsim-model"].stdout
#     "err" = lxd_instance.juju-controller.execs["16-add-gnbsim-model"].stderr
#   }
# }
