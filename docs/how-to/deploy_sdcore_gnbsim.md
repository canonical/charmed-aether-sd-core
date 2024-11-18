# Deploy SD-Core gNB Simulator

This guide covers how to install and configure the SD-Core gNB Simulator.

## Requirements

- Juju >= 3.5
- A Juju controller has been bootstrapped
- A Kubernetes cluster configured with Multus
- 1 Juju cloud for the Kubernetes cluster has been added

## Deploy gNB Simulator

Create a Juju model.

```console
juju add-model gnbsim gnbsim-cloud
```

Deploy the `sdcore-gnbsim-k8s` operator charm.

```console
juju deploy sdcore-gnbsim-k8s gnbsim --trust --channel=1.5/edge \
  --config gnb-interface=ran \
  --config gnb-ip-address=10.204.0.10/24 \
  --config icmp-packet-destination=8.8.8.8 \
  --config upf-gateway=10.204.0.1 \
  --config upf-subnet=10.202.0.0/24
```

Integrate the simulator with the offering from SD-Core.

```console
juju consume control-plane.amf
juju integrate gnbsim:fiveg-n2 amf:fiveg-n2
```
