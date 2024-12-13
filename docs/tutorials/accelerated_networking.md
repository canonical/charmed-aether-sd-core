# Accelerated Networking

In this tutorial, we will deploy User Plane Function (UPF) in DPDK mode using the [sdcore-user-plane-k8s] Terraform Module in a VM.

This builds upon the [Mastering](mastering.md) tutorial. Follow that tutorial until the "Prepare SD-Core User Plane VM", then come back here.

## 1. Prepare the SD-Core User Plane VM for DPDK

Log in to the `user-plane` VM:

```shell
lxc exec user-plane -- su --login ubuntu
```

### Enable HugePages in the User Plane VM

Update Grub to enable 2 units of 1Gi HugePages in the User Plane VM. Then, the VM is gracefully rebooted to activate the settings.

```shell
sudo sed -i "s/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX='default_hugepagesz=1G hugepages=2'/" /etc/default/grub
sudo update-grub
sudo reboot
```

Log in to the `user-plane` VM again:

```shell
lxc exec user-plane -- su --login ubuntu
```

#### Checkpoint 1: Are HugePages enabled ?

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

### Take note of access and core interfaces MAC addresses

List the network interfaces to take note of the MAC addresses of the `enp6s0` and `enp7s0` interfaces.
In this example, the `core` interface named `enp6s0` has the MAC address `00:16:3e:87:67:eb` and the `access` interface named `enp7s0` has the MAC address `00:16:3e:31:d7:e0`.

```shell
ip link
```

```shell
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: enp5s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP mode DEFAULT group default qlen 1000
    link/ether 00:16:3e:52:85:ef brd ff:ff:ff:ff:ff:ff
3: enp6s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP mode DEFAULT group default qlen 1000
    link/ether 00:16:3e:87:67:eb brd ff:ff:ff:ff:ff:ff
4: enp7s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP mode DEFAULT group default qlen 1000
    link/ether 00:16:3e:31:d7:e0 brd ff:ff:ff:ff:ff:ff
```

### Load the `vfio-pci` driver in the User Plane VM

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
sudo lshw -c network -businfo
```

```shell
Bus info          Device      Class          Description
========================================================
pci@0000:05:00.0              network        Virtio network device
virtio@10         enp5s0      network        Ethernet interface
pci@0000:06:00.0              network        Virtio network device
virtio@11         enp6s0      network        Ethernet interface  # In this example `core` with PCI address `0000:06:00.0` 
pci@0000:07:00.0              network        Virtio network device
virtio@13         enp7s0      network        Ethernet interface # In this example `access` with PCI address `0000:07:00.0` 
```

Install driverctl:

```shell
sudo apt update
sudo apt install -y driverctl
```

Bind `access` and `core` interfaces to `vfio-pci` driver persistently:

```shell
cat << EOF | sudo tee -a /etc/rc.local
#!/bin/bash
sudo driverctl set-override 0000:07:00.0 vfio-pci
sudo driverctl set-override 0000:06:00.0 vfio-pci
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
0000:06:00.0 vfio-pci [*] (Virtio network device)
0000:07:00.0 vfio-pci [*] (Virtio network device)
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
sudo snap install microk8s --channel=1.31/stable --classic
sudo microk8s enable hostpath-storage
sudo microk8s addons repo add community https://github.com/canonical/microk8s-community-addons --reference feat/strict-fix-multus
sudo microk8s enable multus
sudo usermod -a -G microk8s $(whoami)
sudo snap alias microk8s.kubectl kubectl
sudo microk8s enable metallb:10.201.0.200/32
newgrp microk8s
```

Now, update the MicroK8s DNS to point to our DNS server:

```shell
sudo microk8s disable dns
sudo microk8s enable dns:10.201.0.1
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
            "pciAddresses": ["0000:07:00.0"]
          }
        },
        {
          "resourceName": "intel_sriov_vfio_core",
          "selectors": {
            "pciAddresses": ["0000:06:00.0"]
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

Make sure that there are 2 `1Gi HugePages`, 1 `intel_sriov_vfio_access` and 1 `intel_sriov_vfio_core` are available by running the following command:

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

Export the Kubernetes configuration and copy it to the `juju-controller` VM:

```shell
sudo microk8s.config > /tmp/user-plane-cluster.yaml
scp /tmp/user-plane-cluster.yaml juju-controller.mgmt:
```

Log out of the VM and go back to the Mastering tutorial, continuing at the [Prepare gNB Simulator VM](mastering.md/#prepare-gnb-simulator-vm).
When you reach step 5 (`Deploy SD-Core User Plane`), come back here instead.

## 2. Deploy User Plane Function (UPF) in DPDK mode

Create a Juju model named `user-plane`:

```shell
juju add-model user-plane user-plane-cluster
```

Deploy `sdcore-user-plane-k8s` Terraform Module.
In the directory named `terraform`, update the `main.tf` file.
Please replace the `access-interface-mac-address` and `core-interface-mac-address` according your environment. They are advised to be noted in the `Checkpoint 4`.

```shell
cd terraform
cat << EOF >> main.tf
module "sdcore-user-plane" {
  source = "git::https://github.com/canonical/terraform-juju-sdcore//modules/sdcore-user-plane-k8s"

  model = "user-plane"

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
    gnb-subnet = "10.204.0.0/24"
  }
}

EOF
```

Update the Juju Terraform provider:

```shell
terraform init
```

Deploy SD-Core User Plane:

```shell
terraform apply -auto-approve
```

Monitor the status of the deployment:

```shell
juju status --watch 1s --relations
```

The deployment is ready when the UPF application is in the `Active/Idle` state.
It is normal for `grafana-agent` to remain in waiting state.

### Checkpoint 7: Is UPF running in DPDK mode ?

Verify that DPDK BESSD is configured in DPDK mode by using the Juju debug log:

```shell
juju debug-log --replay | grep -i dpdk
```

You should see the following output:

```
unit-upf-0: 16:18:59 INFO unit.upf/0.juju-log Container bessd configured for DPDK
```

Go back to the Mastering tutorial and continue from step: [6. Deploy the gNB Simulator](mastering.md/#6-deploy-the-gnb-simulator).

[SR-IOV Network Device Plugin]: https://github.com/k8snetworkplumbingwg/sriov-network-device-plugin
[sdcore-user-plane-k8s]: https://github.com/canonical/terraform-juju-sdcore/tree/main/modules/sdcore-user-plane-k8s
[LXD]: https://canonical.com/lxd
