# Deploy SD-Core User Plane in DPDK mode

This guide covers how to deploy the User Plane Function (UPF) in DPDK mode using Terraform modules.
Navigate between the tabs below to find the steps suitable for your setup (Kubernetes charm of Machine charm).

``````{tab-set}

`````{tab-item} Kubernetes Charm

## Requirements

- A Kubernetes cluster which meets or exceeds below requirements:
  - CPU supporting AVX2 and RDRAND and PDPE1GB instructions (Intel Haswell, AMD Excavator or equivalent)
  - Kernel with SCTP protocol and vfio-pci driver support
  - 4 cores
  - SR-IOV interfaces for Access and Core networks
  - At least two 1G HugePages available
  - `driverctl` installed
  - LoadBalancer with 1 available address for the UPF
  - Multus CNI enabled
- Juju >= 3.6/stable
- A Juju controller bootstrapped onto the Kubernetes cluster
- Terraform 

## Configure UPF host

### Change the driver of the network interfaces to `vfio-pci`

As `root` user on the UPF host, load the `vfio-pci` driver:

```shell
echo "vfio-pci" > /etc/modules-load.d/vfio-pci.conf
modprobe vfio-pci
```

```{note}
Using `vfio-pci`, by default, needs IOMMU to be enabled. In the environments which do not support
IOMMU, `vfio-pci` needs to be loaded with additional module parameter:
`echo "options vfio enable_unsafe_noiommu_mode=1" > /etc/modprobe.d/vfio-noiommu.conf`
```

Get PCI address of `access` and `core` interfaces:

```shell
$ sudo lshw -c network -businfo
Bus info          Device           Class      Description
=========================================================
pci@0000:00:05.0  ens5             network    Elastic Network Adapter (ENA)
pci@0000:00:06.0  ens6             network    Elastic Network Adapter (ENA) # access interface
pci@0000:00:07.0  ens7             network    Elastic Network Adapter (ENA) # core interface
```

Bind `access` and `core` interfaces to the `vfio-pci` driver:

```shell
sudo driverctl set-override 0000:00:06.0 vfio-pci
sudo driverctl set-override 0000:00:07.0 vfio-pci
````

### Configure Kubernetes for DPDK

Create ConfigMap with configuration for the [SR-IOV Network Device Plugin]:

```shell
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: sriovdp-config
  namespace: kube-system
data:
  config.json: |
    {
      "resourceList": [
        {
          "resourceName": "intel_sriov_vfio_access",
          "selectors": {
            "pciAddresses": ["0000:00:06.0"]
          }
        },
        {
          "resourceName": "intel_sriov_vfio_core",
          "selectors": {
            "pciAddresses": ["0000:00:07.0"]
          }
        }
      ]
    }
EOF
```

Deploy [SR-IOV Network Device Plugin]:

```shell
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/sriov-network-device-plugin/v3.6.2/deployments/sriovdp-daemonset.yaml
```

Copy the `vfioveth` CNI under `/opt/cni/bin` on Kubernetes host:

```shell
sudo mkdir -p /opt/cni/bin
sudo wget -O /opt/cni/bin/vfioveth https://raw.githubusercontent.com/opencord/omec-cni/master/vfioveth
sudo chmod +x /opt/cni/bin/vfioveth
```

## Deploy SD-Core UPF Operator

Create a Juju model named `user-plane`:

```shell
juju add-model user-plane user-plane-cloud
```

Deploy `sdcore-user-plane-k8s` Terraform Module.
Create an empty directory named `terraform` and create a `main.tf` file.

```{note}
All the addresses presented below serve as an example. Make sure to replace them with the values matching your setup.
If Kubernetes host is a virtual machine rather than a Bare-metal server, set the `enable-hw-checksum` parameter in the `upf_config` to False.
```

```shell
mkdir terraform
cd terraform
cat << EOF > main.tf
module "sdcore-user-plane" {
  source = "git::https://github.com/canonical/terraform-juju-sdcore//modules/sdcore-user-plane-k8s"

  model = "user-plane"

  upf_config = {
    cni-type              = "vfioveth"
    upf-mode              = "dpdk"
    access-gateway-ip     = "10.202.0.1"
    access-ip             = "10.202.0.10/24"
    core-gateway-ip       = "10.203.0.1"
    core-ip               = "10.203.0.10/24"
    access-interface-mac-address = "c2:c8:c7:e9:cc:18"
    core-interface-mac-address = "e2:01:8e:95:cb:4d"
    enable-hw-checksum           = "false"
  }
}

EOF
```

Initialize the Juju Terraform provider:

```shell
terraform init
```

Deploy SD-Core User Plane:

```shell
terraform apply -auto-approve
```

`````

`````{tab-item} Machine Charm

## Requirements

- A UPF host which meets or exceeds below requirements:
  - Ubuntu 24.04
  - CPU supporting AVX2 and RDRAND and PDPE1GB instructions (Intel Haswell, AMD Excavator or equivalent)
  - 4 cores
  - At least two 1G HugePages available
  - 3 network interfaces
  - `driverctl` installed
- Juju host
  - Juju>=3.6
  - Cloud of type `manual` created
- Terraform

## Configure UPF host

### Change the driver of the network interfaces to `vfio-pci`

As `root` user on the UPF host, load the `vfio-pci` driver:

```shell
echo "vfio-pci" > /etc/modules-load.d/vfio-pci.conf
modprobe vfio-pci
```

```{note}
Using `vfio-pci`, by default, needs IOMMU to be enabled. In the environments which do not support
IOMMU, `vfio-pci` needs to be loaded with additional module parameter:
`echo "options vfio enable_unsafe_noiommu_mode=1" > /etc/modprobe.d/vfio-noiommu.conf`
```

Get PCI address of `access` and `core` interfaces:

```shell
$ sudo lshw -c network -businfo
Bus info          Device           Class      Description
=========================================================
pci@0000:05:00.0  enp5s0           network    Virtio 1.0 network device
pci@0000:06:00.0  enp6s0           network    Virtio 1.0 network device # access interface
pci@0000:07:00.0  enp7s0           network    Virtio 1.0 network device # core interface
```

Bind `access` and `core` interfaces to the `vfio-pci` driver:

```shell
sudo driverctl set-override 0000:06:00.0 vfio-pci
sudo driverctl set-override 0000:07:00.0 vfio-pci
```

## Deploy SD-Core UPF Operator

Create a Juju model named `user-plane`:

```shell
juju add-model user-plane user-plane-cloud
```

Add UPF host to the model:

```shell
juju add-machine ssh:<USERNAME>@<UPF HOST NAME> --private-key <PATH TO THE SSH PRIVATE KEY>
```

Deploy `sdcore-user-plane` Terraform Module.
Create an empty directory named `terraform` and create a `main.tf` file.

```{note}
All the addresses presented below serve as an example. Make sure to replace them with the values matching your setup.
If the host is a virtual machine rather than a Bare-metal server, set the `enable-hw-checksum` parameter in the `upf_config` to False.
```

```shell
mkdir terraform
cd terraform
cat << EOF > main.tf
module "sdcore-user-plane" {
  source = "git::https://github.com/canonical/terraform-juju-sdcore//modules/sdcore-user-plane"

  model          = "user-plane"
  machine_number = 0

  upf_config = {
    upf-mode                     = "dpdk"
    access-interface-name        = "access"
    access-ip                    = "10.202.0.10/24"
    access-gateway-ip            = "10.202.0.1"
    access-interface-mac-address = "c2:c8:c7:e9:cc:18"
    access-interface-pci-address = "0000:06:00.0"
    core-interface-name          = "core"
    core-ip                      = "10.203.0.10/24"
    core-gateway-ip              = "10.203.0.1"
    core-interface-mac-address   = "e2:01:8e:95:cb:4d"
    core-interface-pci-address   = "0000:07:00.0"
    enable-hw-checksum           = "false"
  }
}

EOF
```

Initialize the Juju Terraform provider:

```shell
terraform init
```

Deploy SD-Core User Plane:

```shell
terraform apply -auto-approve
```

`````

``````

[SR-IOV Network Device Plugin]: https://github.com/k8snetworkplumbingwg/sriov-network-device-plugin
