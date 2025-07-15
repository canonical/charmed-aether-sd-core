# Deploy a Single Node Production SD-Core

This guide covers how to install a SD-Core 5G core network on a single node for production.

## Requirements for production node

- 1 physical server
  - 16 cores server CPU, supporting AVX2 and RDRAND and PDPE1GB instructions
  - 64 GB of RAM
  - 1 1Gb NIC (with 1 static IPv4 address configured, with internet access)
  - 2 10Gb NIC or faster (connected to access and core networks, but unconfigured)
  - Ubuntu Server 24.04 installed and up to date

- Static IP addresses
  - 1 management IP address configured on the 1Gb NIC
  - 4 IP addresses reserved on the management subnet, unconfigured
  - 1 access IP address, routable to gNodeB subnet
  - 1 core IP address, routable to the Internet

## Requirements for machine used for installation

- Juju >= 3.6
- Kubectl 1.33
- Git
- Terraform

## Prepare production node

There steps need to be run on the production node itself.

Install driverctl:

```console
sudo apt update
sudo apt install -y driverctl
```

Configure two 1G huge pages:

```console
sudo sed -i "s/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX='default_hugepagesz=1G hugepages=2'/" /etc/default/grub
sudo update-grub
```

Record the PCI addresses of the access and core network interfaces, updating the interface names to match your setup:

```console
export ACCESS_NIC=enp4s0f0
export CORE_NIC=enp4s0f1
cat /sys/class/net/$ACCESS_NIC/address
cat /sys/class/net/$CORE_NIC/address
```

Create the `/etc/rc.local` with the following content, replacing the PCI addresses with the ones from the previous step:

```console
#!/bin/bash

sudo driverctl set-override 0000:04:00.0 vfio-pci
sudo driverctl set-override 0000:04:00.1 vfio-pci
```

Install and bootstrap Canonical K8s:

```console
sudo snap install k8s --classic --channel=1.33-classic/stable
cat << EOF | sudo k8s bootstrap --file -
containerd-base-dir: /opt/containerd
cluster-config:
  network:
    enabled: true
  dns:
    enabled: true
  load-balancer:
    enabled: true
  local-storage:
    enabled: true
  annotations:
    k8sd/v1alpha1/cilium/sctp/enabled: true
EOF
```

Add the Multus plugin:

```console
sudo k8s kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml
```

```{note}
There is an known issue with Multus that can sometimes need more memory than allowed in the DaemonSet, especially when starting many
containers concurrently. If this impacts you, edit the memory limit in the Mutlus DaemonSet to 500Mi:
sudo k8s kubectl edit daemonset -n kube-system kube-multus-ds
```

Create a manifest file `sriovdp-config.yaml`, replacing the PCI addresses with those recorded previously:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: sriovdp-config
data:
  config.json: |
    {
      "resourceList": [
        {
          "resourceName": "intel_sriov_vfio_access",
          "selectors": {
            "pciAddresses": ["0000:04:00.0"]
          }
        },
        {
          "resourceName": "intel_sriov_vfio_core",
          "selectors": {
            "pciAddresses": ["0000:04:00.1"]
          }
        }
      ]
    }
```

Apply the manifest:

```console
sudo k8s kubectl apply -f sriovdp-config.yaml
```

Install the SR-IOV device plugin:

```console
sudo k8s kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/sriov-network-device-plugin/master/deployments/sriovdp-daemonset.yaml
```

Install the vfioveth CNI:

```console
sudo wget -O /opt/cni/bin/vfioveth https://raw.githubusercontent.com/opencord/omec-cni/master/vfioveth
sudo chmod +x /opt/cni/bin/vfioveth
```

Create the `ipaddresspools.yaml` manifest for the static IP address pools for MetalLB,
using the 4 unconfigured static IP address from the management network, to update the
following content:

```yaml
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: lb-address-cos
  namespace: metallb-system
spec:
  addresses:
  - 10.201.0.3/32
  avoidBuggyIPs: false
  serviceAllocation:
    namespaces:
      - cos-lite

---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: lb-address-nms
  namespace: metallb-system
spec:
  addresses:
  - 10.201.0.4/32
  avoidBuggyIPs: false
  serviceAllocation:
    namespaces:
      - control-plane
    serviceSelectors:
      - matchExpressions:
        - {key: "app.juju.is/created-by", operator: In, values: [traefik]}

---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: lb-address-amf
  namespace: metallb-system
spec:
  addresses:
  - 10.201.0.5/32
  avoidBuggyIPs: false
  serviceAllocation:
    namespaces:
      - control-plane
    serviceSelectors:
      - matchExpressions:
        - {key: "app.juju.is/created-by", operator: In, values: [amf]}

---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: lb-address-upf
  namespace: metallb-system
spec:
  addresses:
  - 10.201.0.6/32
  avoidBuggyIPs: false
  serviceAllocation:
    namespaces:
      - user-plane
```

Apply the manifest:

```console
sudo k8s kubectl apply -f ipaddresspools.yaml
```

Extract the Kubernetes configuration to a file:

```console
sudo k8s config > sdcore_k8s_config
```

Transfer the resulting file to the machine used for installation.

Reboot:

```console
sudo reboot
```

## Bootstrap a Juju controller

The remaining steps need to be run from the installation machine.

Add the Kubernetes cluster to the Juju client and bootstrap the controller:

```console
export KUBECONFIG=/path/to/sdcore_k8s_config
juju add-k8s sdcore_k8s --cluster_name=k8s --client
juju bootstrap --config controller-service-type=loadbalancer sdcore_k8s
```

## Deploy SD-Core

Create a Terraform module for your deployment:

```console
mkdir terraform
cd terraform
```

Create a `main.tf` file with the following content, updating the values for your deployment:

```terraform
module "sdcore-production" {
  source = "git::https://github.com/canonical/charmed-aether-sd-core//production?ref=feat-prod-deployment"

  amf_ip = "10.201.0.12"
  amf_hostname = "amf.example.com"
  gnb_subnet = "10.204.0.0/24"
  nms_domainname = "sdcore.example.com"
  upf_access_gateway_ip = "10.202.0.1"
  upf_access_ip = "10.202.0.10/24"
  upf_access_mac = "a1:b2:c3:d4:e5:f6"
  upf_core_gateway_ip = "10.203.0.1"
  upf_core_ip = "10.203.0.10/24"
  upf_core_mac = "a1:b2:c3:d4:e5:f7"
  upf_enable_hw_checksum = "true"
  upf_enable_nat = "false"
  upf_hostname = "upf.example.com"
}
```

Initialize the provider and run the deployment:

```console
terraform init
terraform apply -auto-approve
```

## Access NMS

Retrieve the NMS address:

```console
juju switch control-plane
juju run traefik/0 show-proxied-endpoints
```

Retrieve the NMS credentials (`username` and `password`):

```console
juju show-secret NMS_LOGIN --reveal
```

The output looks like this:

```
cvn3usfmp25c7bgqqr60:
  revision: 2
  checksum: f2933262ee923c949cc0bd12b0456184bb85e5bf41075028893eea447ab40b68
  owner: nms
  label: NMS_LOGIN
  created: 2025-04-03T07:57:40Z
  updated: 2025-04-03T08:02:15Z
  content:
    password: pkxp9DYCcZG
    token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NDM2NzA5MzMsInVzZXJuYW1lIjoiY2hhcm0tYWRtaW4tVlNMTSIsInJvbGUiOjF9.Qwp0PIn9L07nTz0XooPvMb8v8-egYJT85MXjoOY9nYQ
    username: charm-admin-VSLM
```

## Access Grafana

Retrieve Grafana's URL and admin password:

```console
juju switch cos-lite
juju run grafana/leader get-admin-password
```

This produces output similar to the following:

```
Running operation 1 with 1 task
  - task 2 on unit-grafana-0

Waiting for task 2...
admin-password: c72uEq8FyGRo
url: http://10.201.0.3/cos-lite-grafana
```
