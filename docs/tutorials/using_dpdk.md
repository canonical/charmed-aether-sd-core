# Using DPDK

In this tutorial, we will deploy User Plane Function (UPF) in DPDK mode using the [sdcore-user-plane-k8s] Terraform Module in a VM.
[Multipass] is used to create User plane VM with a [LXD] backend.

## Requirements

A machine running Ubuntu 22.04 with the following resources:

- At least one NIC with internet access
- CPU that supports AVX2, RDRAND and PDPE1GB instructions (Intel Haswell, AMD Excavator or equivalent)
- 8 cores
- 16 GB RAM
- 50 GiB disk

## 1. Prepare the Host machine

### Enable HugePages

As a `root` user, update the Grub to enable 2 * 1Gi HugePages in the host machine. Then, the host is gracefully rebooted to activate the settings.

```shell
sudo sed -i "s/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX='default_hugepagesz=1G hugepages=2'/" /etc/default/grub
sudo update-grub
sudo init 6
```

#### Checkpoint 1: Are HugePages enabled ?

You should be able to see the 2 * Free Hugepages with 1048576 kB size by executing the following command:

```shell
cat /proc/meminfo | grep Huge
```

The output should be similar to the following:

```console
AnonHugePages:         0 kB
ShmemHugePages:        0 kB
FileHugePages:         0 kB
HugePages_Total:       2
HugePages_Free:        2
HugePages_Rsvd:        0
HugePages_Surp:        0
Hugepagesize:    1048576 kB
Hugetlb:         2097152 kB
```

### Networks

The following IP networks will be used for User Plane function deployment:

| Name         | Subnet        | Gateway IP |
|--------------|---------------|------------|
| `management` | 10.201.0.0/24 | 10.201.0.1 |
| `access`     | 10.202.0.0/24 | 10.202.0.1 |
| `core`       | 10.203.0.0/24 | 10.203.0.1 |
| `ran`        | 10.204.0.0/24 | 10.204.0.1 |

On the host machine, create local network bridges to be used by LXD by adding below configuration under `/etc/netplan/99-sdcore-networks.yaml`.
Before creating the configuration of the network bridges, please make sure that:

- mgmt-br route metric value is higher than your default route's metric
- core-br metric value is higher than your mgmt-br route's metric

Change the metrics of SD-Core routes which are indicated with comments below, relatively to your default route's metric if required.

```shell
cat << EOF | sudo tee /etc/netplan/99-sdcore-networks.yaml
# /etc/netplan/99-sdcore-networks.yaml
network:
  bridges:
    mgmt-br:
      addresses:
        - 10.201.0.14/24
      routes:
        - to: default
          via: 10.201.0.1
          metric: 110 # Set the value higher than your default route's metric
    access-br:
      addresses:
        - 10.202.0.14/24
      routes:
        - to: 10.204.0.0/24
          via: 10.202.0.1
    core-br:
      addresses:
        - 10.203.0.14/24
      routes:
        - to: default
          via: 10.203.0.1
          metric: 203 # Set the value higher than your mgmt-br route's metric
    ran-br:
      addresses:
        - 10.204.0.14/24
      routes:
        - to: 10.202.0.0/24
          via: 10.204.0.1
  version: 2
EOF
```

Arrange the file permissions and apply the network configuration:

```shell
sudo chmod 600 /etc/netplan/99-sdcore-networks.yaml
sudo netplan apply
```

```{note}
Applying new netplan configuration may produce warnings related to file permissions being too open. 
You may safely disregard them.
```

```{note}
`ran-br` bridge is only used to create a route from `access` to `ran` network in User Plane Function.
```

### Install and Configure LXD

Install LXD:

```console
sudo snap install lxd
```

Initialize LXD:

```console
lxd init --auto
```

### Install and configure Multipass

Install Multipass:

```console
sudo snap install multipass
```

Set LXD as local driver:

```console
multipass set local.driver=lxd
```

Connect Multipass to LXD:

```console
sudo snap connect multipass:lxd lxd
```

## 2. Create a Virtual Machine

To complete this tutorial, you will need one virtual machine with access to the networks as follows:

| Machine                              | CPUs | RAM | Disk | Networks                       |
|--------------------------------------|------|-----|------|--------------------------------|
| User Plane Kubernetes Cluster        | 4    | 12g | 20g  | `management`, `access`, `core` |

Create VM with Multipass:

```console
multipass launch -c 4 -m 12G -d 20G -n user-plane  --network mgmt-br --network core-br --network access-br jammy
```

Wait until all the VM is in a `Running` state.

### Checkpoint 1: Is the VM ready ?

You should be able to see the VM in a `Running` state with its default IP addresses by executing the following command:

```shell
multipass list
```

The output should be similar to the following:

```
Name                    State             IPv4             Image
user-plane              Running           10.64.239.201    Ubuntu 22.04 LTS
```

## 3. Prepare the Virtual Machine

Log in to the `user-plane` VM:

```shell
multipass shell user-plane
```

### Enable HugePages in the User Plane VM

Update Grub to enable 2 units of 1Gi HugePages in the User Plane VM. Then, the VM is gracefully rebooted to activate the settings.

```shell
sudo sed -i "s/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX='default_hugepagesz=1G hugepages=2'/" /etc/default/grub
sudo update-grub
sudo init 6
```

Log in to the `user-plane` VM again:

```shell
multipass shell user-plane
```

#### Checkpoint 2: Are HugePages enabled ?

You should be able to see the 2 units of Free HugePages with 1048576 kB size by executing the following command:

```shell
cat /proc/meminfo | grep Huge
```

The output should be similar to the following:

```shell
AnonHugePages:         0 kB
ShmemHugePages:        0 kB
FileHugePages:         0 kB
HugePages_Total:       2
HugePages_Free:        2
HugePages_Rsvd:        0
HugePages_Surp:        0
Hugepagesize:    1048576 kB
Hugetlb:         2097152 kB
```

### Configure IP addresses in the User Plane VM

Configure IP addresses for `mgmt`, `core` and `access` interfaces and add route from `access` to `ran` network by replacing the content of `/etc/netplan/50-cloud-init.yaml`:

```shell
cat << EOF | sudo tee /etc/netplan/50-cloud-init.yaml
network:
    ethernets:
        enp5s0:
            dhcp4: true
        enp6s0:
            dhcp4: false
            addresses:
              - 10.201.0.102/24
            optional: true
        enp7s0:
            dhcp4: false
            addresses:
              - 10.203.0.100/24
            optional: true
        enp8s0:
            dhcp4: false
            addresses:
              - 10.202.0.100/24
            routes:
              - to: 10.204.0.0/24
                via: 10.202.0.1
            optional: true
    version: 2
EOF
```

Apply the network configuration:

```shell
sudo chmod 600 /etc/netplan/50-cloud-init.yaml
sudo netplan apply
```

#### Checkpoint 4: Are network interfaces configured ?

List the network interfaces to check the ip address assignment and please take note of `MAC addresses` of `enp7s0` and `enp8s0` interfaces.
The `core` interface named `enp7s0` has a MAC address `52:54:00:1c:b8:c2` and the `access` interface named as `enp8s0` interface has a MAC address `52:54:00:1f:7d:6c`.

```shell
$ ip a
3: enp6s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 52:54:00:07:4e:1b brd ff:ff:ff:ff:ff:ff
    inet 10.201.0.102/24 brd 10.201.0.255 scope global enp6s0
       valid_lft forever preferred_lft forever
    inet6 fe80::5054:ff:fe07:4e1b/64 scope link 
       valid_lft forever preferred_lft forever
76: enp8s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 52:54:00:1f:7d:6c brd ff:ff:ff:ff:ff:ff
    inet 10.202.0.100/24 brd 10.202.0.255 scope global enp8s0
       valid_lft forever preferred_lft forever
    inet6 fe80::5054:ff:fe1f:7d6c/64 scope link 
       valid_lft forever preferred_lft forever
77: enp7s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 52:54:00:1c:b8:c2 brd ff:ff:ff:ff:ff:ff
    inet 10.203.0.100/24 brd 10.203.0.255 scope global enp7s0
       valid_lft forever preferred_lft forever
    inet6 fe80::5054:ff:fe1c:b8c2/64 scope link 
       valid_lft forever preferred_lft forever
```

### Load `vfio-pci` driver in the User Plane VM

As `root` user, load the `vfio-pci` driver. To make it persistent upon VM restarts, add it to the `/etc/rc.local` file.

```shell
cat << EOF | sudo tee -a /etc/rc.local
#!/bin/bash
sudo echo "vfio-pci" > /etc/modules-load.d/vfio-pci.conf
sudo modprobe vfio-pci
EOF
sudo chmod +x /etc/rc.local
sudo /etc/rc.local
```

```{note}
Using `vfio-pci`, by default, needs IOMMU to be enabled. IOMMU support could be checked by running the command `ls /sys/kernel/iommu_groups/`. 
If IOMMU groups do not exist in the command output then it is not supported.
In the environments which do not support IOMMU, `vfio-pci` needs to be loaded with additional module parameter persistently using the command below.
```

Enable VFIO driver unsafe IOMMU mode if IOMMU mode is not supported:

```shell
cat << EOF | sudo sudo tee -a /etc/rc.local
sudo echo "options vfio enable_unsafe_noiommu_mode=1" > /etc/modprobe.d/vfio-noiommu.conf
sudo echo "Y" > /sys/module/vfio/parameters/enable_unsafe_noiommu_mode
sudo modprobe vfio enable_unsafe_noiommu_mode=1
EOF
sudo chmod +x /etc/rc.local
sudo /etc/rc.local
```

### Bind `access` and `core` interfaces to VFIO driver

Get the PCI addresses of the access and core interfaces.

```shell
$ sudo lshw -c network -businfo
Bus info          Device      Class          Description
========================================================
pci@0000:05:00.0              network        Virtio network device
virtio@10         enp5s0      network        Ethernet interface
pci@0000:06:00.0              network        Virtio network device
virtio@11         enp6s0      network        Ethernet interface
pci@0000:07:00.0              network        Virtio network device
virtio@13         enp7s0      network        Ethernet interface  # In this example `core` with PCI address `0000:07:00.0` 
pci@0000:08:00.0              network        Virtio network device
virtio@12         enp8s0      network        Ethernet interface # In this example `access` with PCI address `0000:08:00.0` 
```

Install driverctl:

```shell
sudo apt install -y driverctl
```

Bind `access` and `core` interfaces to `vfio-pci` driver persistently:

```shell
cat << EOF | sudo tee -a /etc/rc.local
#!/bin/bash
sudo driverctl set-override 0000:08:00.0 vfio-pci
sudo driverctl set-override 0000:07:00.0 vfio-pci
EOF
sudo chmod +x /etc/rc.local
sudo /etc/rc.local
```

#### Checkpoint 5: Verify that VFIO-PCI driver is loaded ?

Check the current driver of interfaces by running the following command:

```shell
sudo driverctl -v list-devices | grep -i net
```

You should see the following output:

```
0000:05:00.0 virtio-pci (Virtio network device)
0000:06:00.0 virtio-pci (Virtio network device)
0000:07:00.0 vfio-pci [*] (Virtio network device)
0000:08:00.0 vfio-pci [*] (Virtio network device)
```

Verify that two VFIO devices are created with a form of `noiommu-{a number}` by running the following command:

```shell
ls -l /dev/vfio/
```

You should see a similar output:

```
crw------- 1 root root 242,   0 Aug 17 22:15 noiommu-0
crw------- 1 root root 242,   1 Aug 17 22:16 noiommu-1
crw-rw-rw- 1 root root  10, 196 Aug 17 21:51 vfio
```

### Install Kubernetes Cluster

Install the Microk8s and enable the `hostpath-storage`, `multus` and  `metallb` plugins.

```shell
sudo snap install microk8s --channel=1.29/stable --classic
sudo microk8s enable hostpath-storage
sudo microk8s addons repo add community https://github.com/canonical/microk8s-community-addons --reference feat/strict-fix-multus
sudo microk8s enable multus
sudo usermod -a -G microk8s $USER
sudo snap alias microk8s.kubectl kubectl
sudo microk8s enable metallb:10.201.0.200/32
```

### Configure Kubernetes for DPDK

Create [SR-IOV Network Device Plugin] ConfigMap by replacing the `pciAddresses` with the PCI addresses of `access` and `core` interfaces:

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
            "pciAddresses": ["0000:08:00.0"]
          }
        },
        {
          "resourceName": "intel_sriov_vfio_core",
          "selectors": {
            "pciAddresses": ["0000:07:00.0"]
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

#### Checkpoint 6: Check the allocatable resources in the Kubernetes node

Make sure that there are 2*1Gi HugePages, 1* `intel_sriov_vfio_access` and 1* `intel_sriov_vfio_core` are available by running the following command:

```shell
sudo snap install jq
kubectl get node -o json | jq '.items[].status.allocatable'
```

You should see the following output:

```
{
  "cpu": "4",
  "ephemeral-storage": "19086016Ki",
  "hugepages-1Gi": "2Gi",
  "hugepages-2Mi": "0",
  "intel.com/intel_sriov_vfio_access": "1",
  "intel.com/intel_sriov_vfio_core": "1",
  "memory": "14160716Ki",
  "pods": "110"
}
```

### Copy vfioveth CNI under /opt/cni/bin on the VM

Copy the `vfioveth` CNI under `/opt/cni/bin`:

```shell
sudo mkdir -p /opt/cni/bin
sudo wget -O /opt/cni/bin/vfioveth https://raw.githubusercontent.com/opencord/omec-cni/master/vfioveth
sudo chmod +x /opt/cni/bin/vfioveth
```

### Install Juju and create a Juju controller

Install Juju.

```shell
mkdir -p ~/.local/share/juju
sudo snap install juju --channel=3.4/stable
```

Add Microk8s as a cloud to Juju.

```shell
sudo microk8s config | juju add-k8s user-plane-cloud --client
```

Create a Juju controller on the `user-plane-cloud`:

```shell
juju bootstrap user-plane-cloud
```

Log out of the VM.

## 4. Deploy User Plane Function (UPF) in DPDK mode

Log in to the `user-plane` VM:

```shell
multipass shell user-plane
```

Create a Juju model named `user-plane`:

```shell
juju add-model user-plane user-plane-cloud
```

Install Terraform.

```shell
sudo snap install terraform --classic
```

Deploy `sdcore-user-plane-k8s` Terraform Module.
Create an empty directory named `terraform` and create a `main.tf` file.
Please replace the `access-interface-mac-address` and `core-interface-mac-address` according your environment. They are advised to be noted in the `Checkpoint 4`.

```shell
mkdir terraform
cd terraform
cat << EOF > main.tf
module "sdcore-user-plane" {
  source = "git::https://github.com/canonical/terraform-juju-sdcore-k8s//modules/sdcore-user-plane-k8s"

  model_name   = "user-plane"
  create_model = false

  upf_config = {
    cni-type               = "vfioveth"
    upf-mode              = "dpdk"
    access-gateway-ip     = "10.202.0.1"
    access-ip             = "10.202.0.10/24"
    core-gateway-ip       = "10.203.0.1"
    core-ip               = "10.203.0.10/24"
    external-upf-hostname = "upf.mgmt"
    access-interface-mac-address = "c2:c8:c7:e9:cc:18" # In this example, its the MAC address of access interface.
    core-interface-mac-address = "e2:01:8e:95:cb:4d" # In this example, its the MAC address of core interface
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

Monitor the status of the deployment:

```shell
watch -n 1 -c juju status --color
```

The deployment is ready when the UPF application is in the `Active/Idle` state.
It is normal for `grafana-agent` to remain in waiting state.

### Checkpoint 7: Is UPF running in DPDK mode ?

You should be able to see the UPF in the `Active/Idle` state by running the following command:

```shell
juju status   
```

This should produce output similar to the following:

```
Model       Controller        Cloud/Region      Version  SLA          Timestamp
user-plane  my-k8s-localhost  my-k8s/localhost  3.4.2    unsupported  14:25:39+03:00

App            Version  Status   Scale  Charm              Channel        Rev  Address         Exposed  Message
grafana-agent  0.35.2   waiting      1  grafana-agent-k8s  latest/stable   64  10.152.183.158  no       installing agent
upf                     active       1  sdcore-upf-k8s     1.5/edge       205  10.152.183.221  no       

Unit              Workload  Agent  Address      Ports  Message
grafana-agent/0*  blocked   idle   10.1.36.254         grafana-cloud-config: off, logging-consumer: off
upf/0*            active    idle   10.1.36.193         
```

Verify that DPDK BESSD is configured in DPDK mode by using the Juju debug log:

```shell
juju debug-log --replay | grep -i dpdk
```

You should see the following output:

```
unit-upf-0: 16:18:59 INFO unit.upf/0.juju-log Container bessd configured for DPDK
```

Log out of the VM.

[SR-IOV Network Device Plugin]: https://github.com/k8snetworkplumbingwg/sriov-network-device-plugin
[sdcore-user-plane-k8s]: https://github.com/canonical/terraform-juju-sdcore-k8s/tree/main/modules/sdcore-user-plane-k8s
[Multipass]: https://multipass.run/
[LXD]: https://ubuntu.com/lxd
