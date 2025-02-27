# Mastering

In this tutorial, we will deploy and run the SD-Core 5G core network following Control Plane and User Plane Separation (CUPS).
The User Plane will be deployed in DPDK mode.
The radio and cell phone simulator will also be deployed on an isolated cluster.
This tutorial uses [LXD](https://canonical.com/lxd) with Terraform to deploy the required infrastructure.

## 1. Prepare the Host machine

A machine running Ubuntu 22.04 with the following resources:

- At least one NIC with internet access
- 8 cores
- 32 GB RAM
- 150 GiB disk

### Networks

The following IP networks will be used to connect and isolate the network functions:

| Name         | Subnet        | Gateway IP |
| ------------ | ------------- | ---------- |
| `management` | 10.201.0.0/24 | 10.201.0.1 |
| `access`     | 10.202.0.0/24 | 10.202.0.1 |
| `core`       | 10.203.0.0/24 | 10.203.0.1 |
| `ran`        | 10.204.0.0/24 | 10.204.0.1 |

### Install and Configure LXD

Install LXD:

```console
sudo snap install lxd
```

Initialize LXD:

```console
sudo usermod -aG lxd "$USER"
newgrp lxd
lxd init --auto
```

### Install Terraform

Install Terraform:

```console
sudo snap install terraform --classic
```

## 2. Create Virtual Machines

To complete this tutorial, you will need four virtual machines with access to the networks as follows:

| Machine                              | CPUs | RAM | Disk | Networks                       |
| ------------------------------------ | ---- | --- | ---- | ------------------------------ |
| Control Plane Kubernetes Cluster     | 4    | 8g  | 40g  | `management`                   |
| User Plane Kubernetes Cluster        | 4    | 12g | 20g  | `management`, `access`, `core` |
| Juju Controller + Kubernetes Cluster | 4    | 6g  | 40g  | `management`                   |
| gNB Simulator Kubernetes Cluster     | 2    | 3g  | 20g  | `management`, `ran`            |

The complete infrastructure can be created with Terraform using the following commands:

```console
git clone https://github.com/canonical/charmed-aether-sd-core.git
cd charmed-aether-sd-core/terraform
terraform init
terraform apply -auto-approve
```

```{note}
The current version of the Terraform module has some race conditions, if the deployment fail, a retry will
usually fix the issue.
```

### Checkpoint 1: Are the VM's ready ?

You should be able to see all the VMs in a `Running` state with their default IP addresses by executing the following command:

```console
lxc list
```

The output should be similar to the following:

```
+-----------------+---------+-----------------------+------+-----------------+-----------+
|      NAME       |  STATE  |         IPV4          | IPV6 |      TYPE       | SNAPSHOTS |
+-----------------+---------+-----------------------+------+-----------------+-----------+
| control-plane   | RUNNING | 10.201.0.101 (enp5s0) |      | VIRTUAL-MACHINE | 0         |
+-----------------+---------+-----------------------+------+-----------------+-----------+
| gnbsim          | RUNNING | 10.204.0.100 (enp6s0) |      | VIRTUAL-MACHINE | 0         |
|                 |         | 10.201.0.103 (enp5s0) |      |                 |           |
+-----------------+---------+-----------------------+------+-----------------+-----------+
| juju-controller | RUNNING | 10.201.0.104 (enp5s0) |      | VIRTUAL-MACHINE | 0         |
+-----------------+---------+-----------------------+------+-----------------+-----------+
| user-plane      | RUNNING | 10.203.0.100 (enp6s0) |      | VIRTUAL-MACHINE | 0         |
|                 |         | 10.202.0.100 (enp7s0) |      |                 |           |
|                 |         | 10.201.0.102 (enp5s0) |      |                 |           |
+-----------------+---------+-----------------------+------+-----------------+-----------+
```

## 3. Configure VMs for SD-Core Deployment

This section covers installation of necessary tools on the VMs which are going to build up the infrastructure for SD-Core.

### Prepare the SD-Core Control Plane VM

Login to the `control-plane` VM:

```console
lxc exec control-plane -- su --login ubuntu
```

Install MicroK8s with the necessary plugins:

```console
sudo snap install microk8s --channel=1.31-strict/stable
sudo microk8s enable hostpath-storage
sudo usermod -a -G snap_microk8s $(whoami)
sudo microk8s enable metallb:10.201.0.52-10.201.0.53
sudo microk8s disable dns
sudo microk8s enable dns:10.201.0.1
```

Export the Kubernetes configuration and copy it to the `juju-controller` VM:

```console
sudo microk8s.config > /tmp/control-plane-cluster.yaml
scp /tmp/control-plane-cluster.yaml juju-controller.mgmt.local:
```

Log out of the VM.

### Prepare the SD-Core User Plane VM

Log in to the `user-plane` VM:

```console
lxc exec user-plane -- su --login ubuntu
```

#### Enable HugePages

Update Grub to enable 2 units of 1Gi HugePages in the User Plane VM. Then, the VM is gracefully rebooted to activate the settings.

```console
sudo sed -i "s/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX='default_hugepagesz=1G hugepages=2'/" /etc/default/grub
sudo update-grub
sudo reboot
```

Log in to the `user-plane` VM again:

```console
lxc exec user-plane -- su --login ubuntu
```

##### Checkpoint 2: Are HugePages enabled ?

You should be able to see the 2 units of Free HugePages with 1048576 kB size by executing the following command:

```console
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

#### Take note of access and core interfaces MAC addresses

List the network interfaces to take note of the MAC addresses of the `enp6s0` and `enp7s0` interfaces.
In this example, the `core` interface named `enp6s0` has the MAC address `00:16:3e:87:67:eb` and the `access` interface named `enp7s0` has the MAC address `00:16:3e:31:d7:e0`.

```console
ip link
```

```console
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: enp5s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP mode DEFAULT group default qlen 1000
    link/ether 00:16:3e:52:85:ef brd ff:ff:ff:ff:ff:ff
3: enp6s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP mode DEFAULT group default qlen 1000
    link/ether 00:16:3e:87:67:eb brd ff:ff:ff:ff:ff:ff
4: enp7s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP mode DEFAULT group default qlen 1000
    link/ether 00:16:3e:31:d7:e0 brd ff:ff:ff:ff:ff:ff
```

#### Load the `vfio-pci` driver in the User Plane VM

Enable the `vfio-pci` driver:

```console
cat << EOF | sudo sudo tee -a /etc/rc.local
#!/bin/bash
sudo echo "options vfio enable_unsafe_noiommu_mode=1" > /etc/modprobe.d/vfio-noiommu.conf
sudo echo "Y" > /sys/module/vfio/parameters/enable_unsafe_noiommu_mode
sudo modprobe vfio enable_unsafe_noiommu_mode=1
EOF
sudo chmod +x /etc/rc.local
sudo /etc/rc.local
```


```{note}
After running the above command, you will not see the interfaces `enp6s0` and `enp7s0` in the `ip link` output.
```

#### Bind `access` and `core` interfaces to VFIO driver

Get the PCI addresses of the access and core interfaces.

```console
sudo lshw -c network -businfo
```

```console
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

```console
sudo apt update
sudo apt install -y driverctl
```

Bind `access` and `core` interfaces to `vfio-pci` driver persistently:

```console
cat << EOF | sudo tee -a /etc/rc.local
#!/bin/bash
sudo driverctl set-override 0000:07:00.0 vfio-pci
sudo driverctl set-override 0000:06:00.0 vfio-pci
EOF
sudo chmod +x /etc/rc.local
sudo /etc/rc.local
```

##### Checkpoint 3: Validate that the VFIO-PCI driver is loaded

Check the current driver of interfaces by running the following command:

```console
sudo driverctl -v list-devices | grep -i net
```

You should see the following output:

```
0000:05:00.0 virtio-pci (Virtio network device)
0000:06:00.0 vfio-pci [*] (Virtio network device)
0000:07:00.0 vfio-pci [*] (Virtio network device)
```

Verify that two VFIO devices are created with a form of `noiommu-{a number}` by running the following command:

```console
ls -l /dev/vfio/
```

You should see a similar output:

```
crw------- 1 root root 242,   0 Aug 17 22:15 noiommu-0
crw------- 1 root root 242,   1 Aug 17 22:16 noiommu-1
crw-rw-rw- 1 root root  10, 196 Aug 17 21:51 vfio
```

#### Install Kubernetes Cluster

Install MicroK8s with the necessary plugins:

```console
sudo snap install microk8s --channel=1.31/stable --classic
sudo microk8s enable hostpath-storage
sudo microk8s addons repo add community https://github.com/canonical/microk8s-community-addons --reference feat/strict-fix-multus
sudo microk8s enable multus
sudo usermod -a -G microk8s $(whoami)
sudo snap alias microk8s.kubectl kubectl
sudo microk8s enable metallb:10.201.0.200/32
sudo microk8s disable dns
sudo microk8s enable dns:10.201.0.1
newgrp microk8s
```

#### Configure Kubernetes for DPDK

Create [SR-IOV Network Device Plugin] ConfigMap by replacing the `pciAddresses` with the PCI addresses of `access` and `core` interfaces:

```console
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

```console
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/sriov-network-device-plugin/v3.6.2/deployments/sriovdp-daemonset.yaml
```

##### Checkpoint 4: Check the allocatable resources in the Kubernetes node

Make sure that there are 2 `1Gi HugePages`, 1 `intel_sriov_vfio_access` and 1 `intel_sriov_vfio_core` are available by running the following command:

```console
sudo snap install jq
kubectl get node -o json | jq '.items[].status.allocatable'
```

After a couple of seconds, you should see the following output:

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

#### Copy vfioveth CNI under /opt/cni/bin on the VM

Copy the `vfioveth` CNI under `/opt/cni/bin`:

```console
sudo mkdir -p /opt/cni/bin
sudo wget -O /opt/cni/bin/vfioveth https://raw.githubusercontent.com/opencord/omec-cni/master/vfioveth
sudo chmod +x /opt/cni/bin/vfioveth
```

Export the Kubernetes configuration and copy it to the `juju-controller` VM:

```console
sudo microk8s.config > /tmp/user-plane-cluster.yaml
scp /tmp/user-plane-cluster.yaml juju-controller.mgmt.local:
```

Log out of the VM.

### Prepare the gNB Simulator VM

Log in to the `gnbsim` VM:

```console
lxc exec gnbsim -- su --login ubuntu
```

Install MicroK8s and add the Multus plugin:

```console
sudo snap install microk8s --channel=1.31-strict/stable
sudo microk8s enable hostpath-storage
sudo microk8s addons repo add community \
    https://github.com/canonical/microk8s-community-addons \
    --reference feat/strict-fix-multus
sudo microk8s enable multus
sudo microk8s disable dns
sudo microk8s enable dns:10.201.0.1
sudo usermod -a -G snap_microk8s $(whoami)
```

Export the Kubernetes configuration and copy it to the `juju-controller` VM:

```console
sudo microk8s.config > /tmp/gnb-cluster.yaml
scp /tmp/gnb-cluster.yaml juju-controller.mgmt.local:
```

Create the MACVLAN bridges for `enp6s0`, and label them accordingly:

```console
cat << EOF | sudo tee /etc/rc.local
#!/bin/bash

sudo ip link add ran link enp6s0 type macvlan mode bridge
sudo ip link set dev ran up
EOF
sudo chmod +x /etc/rc.local
sudo /etc/rc.local
```

Log out of the VM.

### Prepare the Juju Controller VM

Log in to the `juju-controller` VM:

```console
lxc exec juju-controller -- su --login ubuntu
```

Begin by installing MicroK8s to hold the Juju controller.
Configure MetalLB to expose one IP address for the controller (`10.201.0.50`) and one for the Canonical Observability Stack (`10.201.0.51)`:

```console
sudo snap install microk8s --channel=1.31-strict/stable
sudo microk8s enable hostpath-storage
sudo microk8s enable metallb:10.201.0.50-10.201.0.51
sudo microk8s disable dns
sudo microk8s enable dns:10.201.0.1
sudo usermod -a -G snap_microk8s $(whoami)
newgrp snap_microk8s
```

Install Juju and bootstrap the controller to the local MicroK8s install as a LoadBalancer service.
This will expose the Juju controller on the first allocated MetalLB address:

```console
mkdir -p ~/.local/share/juju
sudo snap install juju --channel=3.6/stable
juju bootstrap microk8s --config controller-service-type=loadbalancer sdcore
```

At this point, the Juju controller is ready to start managing external clouds.
Add the Kubernetes clusters representing the user plane, control plane, and gNB simulator to Juju.
This is done by using the Kubernetes configuration file generated when setting up the clusters above.

```console
cd /home/ubuntu
export KUBECONFIG=control-plane-cluster.yaml
juju add-k8s control-plane-cluster --controller sdcore
export KUBECONFIG=user-plane-cluster.yaml
juju add-k8s user-plane-cluster --controller sdcore
export KUBECONFIG=gnb-cluster.yaml
juju add-k8s gnb-cluster --controller sdcore
```

Install Terraform:

```console
sudo snap install terraform --classic
```

## 4. Deploy SD-Core Control Plane

The following steps build on the Juju controller which was bootstrapped and knows how to manage the SD-Core Control Plane Kubernetes cluster.

First, we will create a new Terraform module which we will use to deploy SD-Core Control Plane.
After the successful deployment, we will configure the Access and Mobility Management Function (AMF) IP address for sharing with the radios and the Traefik external hostname for exposing the SD-Core Network Management System (NMS).
This host name must be resolvable by the gNB and the IP address must be reachable and resolve to the AMF unit.
In the bootstrap step, we set the Control Plane MetalLB IP range, and that is what we use in the configuration.
Lastly, the module will expose the Software as a Service offer for the AMF.

Create Juju model for the SD-Core Control Plane:

```console
juju add-model control-plane control-plane-cluster
```

Create new folder called `terraform`:

```console
mkdir terraform
```

Inside newly created `terraform` folder create a `versions.tf` file:

```console
cd terraform
cat << EOF > versions.tf
terraform {
  required_providers {
    juju = {
      source  = "juju/juju"
      version = ">= 0.12.0"
    }
  }
}
EOF
```

Create Terraform module:

```console
cat << EOF > main.tf
data "juju_model" "control-plane" {
  name = "control-plane"
}

module "sdcore-control-plane" {
  source = "git::https://github.com/canonical/terraform-juju-sdcore//modules/sdcore-control-plane-k8s"

  model = data.juju_model.control-plane.name

  amf_config = {
    external-amf-hostname = "amf.mgmt.local"
  }
  traefik_config = {
    routing_mode = "subdomain"
  }
}

EOF
```

Initialize Juju Terraform provider:

```console
terraform init
```

Deploy SD-Core Control Plane:

```console
terraform apply -auto-approve
```

Monitor the status of the deployment:

```console
juju status --watch 1s --relations
```

The deployment is ready when all the charms are in the `Active/Idle` state.<br>
It is normal for `grafana-agent` to remain in waiting state.<br>

Once the deployment is ready, we will proceed to the configuration part.

Get the IP addresses of the AMF and Traefik LoadBalancer services:

Log in to the `control-plane` VM:

```console
ssh control-plane
```

Get LoadBalancer services:

```console
microk8s.kubectl get services -A | grep LoadBalancer
```

This will show output similar to the following:

```console
control-plane    amf-external  LoadBalancer  10.152.183.179  10.201.0.52   38412:30408/SCTP
control-plane    traefik-lb    LoadBalancer  10.152.183.28   10.201.0.53   80:32349/TCP,443:31925/TCP
```

Note both IPs - in this case `10.201.0.52` for the AMF and `10.201.0.53` for Traefik.
We will need them shortly.

```{note}
If the IP for the AMF is not `10.201.0.52`, you will need to update the DNS entry to match the actual external IP for the AMF. In the host, edit the `main.tf` file. Find the following line and set it to the correct IP address, like so:

`host-record=amf.mgmt.local,10.201.0.53`

Then, run the following command on the host:

`terraform apply -auto-approve`
```

Log out of the `control-plane` VM.

Configure AMF external IP, using the address obtained in the previous step.
To do that, edit `amf_config` in the `main.tf` file in the `terraform` directory.

Updated `amf_config` should look like similar to the below:

```
(...)
module "sdcore-control-plane" {
  (...)
  amf_config = {
    external-amf-ip       = "10.201.0.52"
    external-amf-hostname = "amf.mgmt.local"
  }
  (...)
}
(...)
```

Configure Traefik's external hostname, using the address obtained in the previous step.
To do that, edit `traefik_config` in the `main.tf` file.

Updated `traefik_config` should look like similar to the below:

```
(...)
module "sdcore-control-plane" {
  (...)
  traefik_config = {
    routing_mode      = "subdomain"
    external_hostname = "10.201.0.53.nip.io"
  }
  (...)
}
(...)
```

Apply the changes:

```console
terraform apply -auto-approve
```

## 5. Deploy User Plane Function (UPF) in DPDK mode

Create a Juju model named `user-plane`:

```console
juju add-model user-plane user-plane-cluster
```

Deploy `sdcore-user-plane-k8s` Terraform Module.
In the directory named `terraform`, update the `main.tf` file.
Please replace the `access-interface-mac-address` and `core-interface-mac-address` according your environment. You would have noted them at the `Checkpoint 4`.

```console
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
    external-upf-hostname = "upf.mgmt.local"
    access-interface-mac-address = "c2:c8:c7:e9:cc:18" # In this example, its the MAC address of access interface.
    core-interface-mac-address = "e2:01:8e:95:cb:4d" # In this example, its the MAC address of core interface
    enable-hw-checksum           = "false"
    gnb-subnet = "10.204.0.0/24"
  }
}

EOF
```

Update the Juju Terraform provider:

```console
terraform init
```

Deploy SD-Core User Plane:

```console
terraform apply -auto-approve
```

Monitor the status of the deployment:

```console
juju status --watch 1s --relations
```

The deployment is ready when the UPF application is in the `Active/Idle` state.
It is normal for `grafana-agent` to remain in waiting state.

### Checkpoint 5: Validate that the UPF is running in DPDK mode

Verify that DPDK BESSD is configured in DPDK mode by using the Juju debug log:

```console
juju debug-log --replay | grep -i dpdk
```

You should see the following output:

```
unit-upf-0: 16:18:59 INFO unit.upf/0.juju-log Container bessd configured for DPDK
```

## 6. Deploy the gNB Simulator

The following steps build on the Juju controller which was bootstrapped and knows how to manage the gNB Simulator Kubernetes cluster.

First, we will add gNB Simulator to the Terraform module used in the previous steps.
We will provide necessary configuration (please see the list of the config options with the description in the table below) for the application and integrate the simulator with the relevant 5G Core Network Functions (AMF, NMS and UPF).

| Config Option           | Descriptions                                                                                                                                  |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| gnb-interface           | The name of the MACVLAN interface to use on the host                                                                                          |
| gnb-ip-address          | The IP address to use on the gnb interface                                                                                                    |
| icmp-packet-destination | The target IP address to ping. If there is no egress to the internet on your core network, any IP that is reachable from the UPF should work. |
| upf-gateway             | The IP address of the gateway between the RAN and Access networks                                                                             |
| upf-subnet              | Subnet where the UPFs are located (also called Access network)                                                                                |

In the `juju-controller` VM, create Juju model for the SD-Core Control Plane:

```console
juju add-model gnbsim gnb-cluster
```

Update the `main.tf` file:

```console
cat << EOF >> main.tf
data "juju_model" "gnbsim" {
  name = "gnbsim"
}

module "gnbsim" {
  source = "git::https://github.com/canonical/sdcore-gnbsim-k8s-operator//terraform"

  model = data.juju_model.gnbsim.name
  
  config = {
    gnb-interface           = "ran"
    gnb-ip-address          = "10.204.0.10/24"
    icmp-packet-destination = "8.8.8.8"
    upf-gateway             = "10.204.0.1"
    upf-subnet              = "10.202.0.0/24"
  }
}

resource "juju_integration" "gnbsim-amf" {
  model = data.juju_model.gnbsim.name

  application {
    name     = module.gnbsim.app_name
    endpoint = module.gnbsim.requires.fiveg_n2
  }

  application {
    offer_url = module.sdcore-control-plane.amf_fiveg_n2_offer_url
  }
}

resource "juju_integration" "gnbsim-nms" {
  model = data.juju_model.gnbsim.name

  application {
    name     = module.gnbsim.app_name
    endpoint = module.gnbsim.requires.fiveg_core_gnb
  }

  application {
    offer_url = module.sdcore-control-plane.nms_fiveg_core_gnb_offer_url
  }
}

resource "juju_integration" "nms-upf" {
  model = data.juju_model.control-plane.name

  application {
    name     = module.sdcore-control-plane.nms_app_name
    endpoint = module.sdcore-control-plane.fiveg_n4_endpoint
  }

  application {
    offer_url = module.sdcore-user-plane.upf_fiveg_n4_offer_url
  }
}

EOF
```

Update Juju Terraform provider:

```console
terraform init
```

Deploy the gNB simulator:

```console
terraform apply -auto-approve
```

Monitor the status of the deployment:

```console
juju status --watch 1s --relations
```

The deployment is ready when the `gnbsim` application is in the `Waiting/Idle` state and the message is `Waiting for TAC and PLMNs configuration`.<br>

## 7. Configure SD-Core

The following steps show how to configure the SD-Core 5G core network.
In this step we will create a network slice, a device group and a subscriber.

Retrieve the NMS credentials (`username` and `password`):

```console
juju switch control-plane
juju show-secret NMS_LOGIN --reveal
```
The output looks like this:
```
csurgu7mp25c761k2oe0:
  revision: 1
  owner: nms
  label: NMS_LOGIN
  created: 2024-11-20T10:22:49Z
  updated: 2024-11-20T10:22:49Z
  content:
    password: ',u7=VEE3XK%t'
    token: ""
    username: charm-admin-SOOO
```

Retrieve the NMS address:

```console
juju run traefik/0 show-proxied-endpoints
```

The output should be `https://control-plane-nms.10.201.0.53.nip.io/`.
Navigate to this address in your browser and use the `username` and `password` to login.

In the Network Management System (NMS), create a network slice with the following attributes:

- Name: `Tutorial`
- MCC: `001`
- MNC: `01`
- UPF: `upf.mgmt.local:8805`
- gNodeB: `gnbsim-gnbsim-gnbsim (tac:1)`

You should see the following network slice created.

```{image} ../images/mastering_network_slice.png
:alt: NMS Network Slice
:align: center
```

Navigate to Device groups and click on Create. Fill in the following:

- Name: `device-group`
- Network Slice: `Tutorial`
- Subscriber IP pool: `172.250.1.0/16`
- DNS: `8.8.8.8`
- MTU (bytes): `1456`
- Maximum bitrate (Mbps):
  - Downstream: `200`
  - Upstream: `20`
- QoS:
  - 5QI: `1: GBR - Conversational Voice`
  - ARP: `6`

You should see the following device group created:

```{image} ../images/mastering_device_group.png
:alt: NMS Device Group
:align: center
```

We will now add a subscriber with the IMSI that was provided to the gNB simulator.
Navigate to Subscribers and click on Create. Fill in the following:

- IMSI: `001010100007487`
- OPC: `981d464c7c52eb6e5036234984ad0bcf`
- Key: `5122250214c33e723a5dd523fc145fc0`
- Sequence Number: `16f3b3f70fc2`
- Network Slice: `Tutorial`
- Device Group: `device-group`

## 8. Integrate SD-Core with the Canonical Observability Stack (COS)

The following steps show how to integrate the SD-Core 5G core network with the Canonical Observability Stack (COS).

First, we will add COS to the Terraform module used in the previous steps.
Next, we will expose the Software as a Service offers for the COS and create integrations with SD-Core 5G core network components.

### Deploy COS Lite

Add `cos-lite` Terraform module to the `main.tf` file used in the previous steps:

```console
cat << EOF >> main.tf
module "cos-lite" {
  source = "git::https://github.com/canonical/terraform-juju-sdcore//modules/external/cos-lite"

  model_name               = "cos-lite"
  deploy_cos_configuration = true
  cos_configuration_config = {
    git_repo                 = "https://github.com/canonical/sdcore-cos-configuration"
    git_branch               = "main"
    grafana_dashboards_path  = "grafana_dashboards/sdcore/"
  }
}

EOF
```

Update Juju Terraform provider:

```console
terraform init
```

Deploy COS:

```console
terraform apply -auto-approve
```

Monitor the status of the deployment:

```console
juju switch cos-lite
juju status --watch 1s --relations
```

The deployment is ready when all the charms are in the `Active/Idle` state.

### Integrate SD-Core with COS Lite

Once the COS deployment is ready, add integrations between SD-Core and COS applications to the `main.tf` file:

```console
cat << EOF >> main.tf
resource "juju_integration" "control-plane-prometheus" {
  model = data.juju_model.control-plane.name

  application {
    name     = module.sdcore-control-plane.grafana_agent_app_name
    endpoint = module.sdcore-control-plane.send_remote_write_endpoint
  }

  application {
    offer_url = module.cos-lite.prometheus_remote_write_offer_url
  }
}

resource "juju_integration" "control-plane-loki" {
  model = data.juju_model.control-plane.name

  application {
    name     = module.sdcore-control-plane.grafana_agent_app_name
    endpoint = module.sdcore-control-plane.logging_consumer_endpoint
  }

  application {
    offer_url = module.cos-lite.loki_logging_offer_url
  }
}

resource "juju_integration" "user-plane-prometheus" {
  model = data.juju_model.user-plane.name

  application {
    name     = module.sdcore-user-plane.grafana_agent_app_name
    endpoint = module.sdcore-user-plane.send_remote_write_endpoint
  }

  application {
    offer_url = module.cos-lite.prometheus_remote_write_offer_url
  }
}

resource "juju_integration" "user-plane-loki" {
  model = data.juju_model.user-plane.name

  application {
    name     = module.sdcore-user-plane.grafana_agent_app_name
    endpoint = module.sdcore-user-plane.logging_consumer_endpoint
  }

  application {
    offer_url = module.cos-lite.loki_logging_offer_url
  }
}

EOF
```

Apply the changes:

```console
terraform apply -auto-approve
```

#### Checkpoint 4: Validate that the Grafana dashboard available

From the `juju-controller` VM, retrieve the Grafana URL and admin password:

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
url: http://10.201.0.51/cos-lite-grafana
```

```{note}
Grafana can be accessed using both `http` (as returned by the command above) or `https`.
```

In your browser, navigate to the URL from the output (`https://10.201.0.51/cos-lite-grafana`).
Login using the "admin" username and the admin password provided in the last command.
Click on "Dashboards" -> "Browse" and select "5G Network Overview".

This dashboard presents an overview of your 5G Network status.
Keep this page open, we will revisit it shortly.

```{image} ../images/grafana_5g_dashboard_sim_before.png
:alt: Initial Grafana dashboard showing UPF status
:align: center
```

```{note}
It may take up to 5 minutes for the relevant metrics to be available in Prometheus.
```

## 9. Run the 5G simulation

On the `juju-controller` VM, switch to the `gnbsim` model.

```console
juju switch gnbsim
```

Start the simulation.

```console
juju run gnbsim/leader start-simulation
```

The simulation executed successfully if you see `success: "true"` as one of the output messages:

```
Running operation 1 with 1 task
  - task 2 on unit-gnbsim-0

Waiting for task 2...
info: 5/5 profiles passed
success: "true"
```

## Checkpoint 5: Check the simulation logs to see the communication between elements and the data exchange

### gNB Simulation Logs

Let's take a look at the juju debug-log now by running the following command:

```console
juju debug-log --no-tail
```

This will emit the full log of the simulation starting with the following message:

```console
unit-gnbsim-0: 16:43:50 INFO unit.gnbsim/0.juju-log gnbsim simulation output:
```

As there is a lot of output, we can better understand if we filter by specific elements.
For example, let's take a look at the control plane transport of the log.
To do that, we search for `ControlPlaneTransport` in the Juju debug-log.
This shows the simulator locating the AMF and exchanging data with it.

```console
$ juju debug-log | grep ControlPlaneTransport
2023-11-30T16:43:40Z [TRAC][GNBSIM][GNodeB][ControlPlaneTransport] Connecting to AMF
2023-11-30T16:43:40Z [INFO][GNBSIM][GNodeB][ControlPlaneTransport] Connected to AMF, AMF IP: 10.201.0.52 AMF Port: 38412
...
```

We can do the same for the user plane transport to see it starts on the RAN network with IP address `10.204.0.10` as we requested, and it is communicating with our UPF at `10.202.0.10` as expected.

To follow the UE itself, we can filter by the IMSI.

```console
juju debug-log | grep imsi-001010100007487
```

### Control Plane Logs

You may view the control plane logs by logging into the control plane cluster and using Kubernetes commands as follows:

```console
microk8s.kubectl logs -n control-plane -c amf amf-0 --tail 70
microk8s.kubectl logs -n control-plane -c ausf ausf-0 --tail 70
microk8s.kubectl logs -n control-plane -c nrf nrf-0 --tail 70
microk8s.kubectl logs -n control-plane -c nssf nssf-0 --tail 70
microk8s.kubectl logs -n control-plane -c pcf pcf-0 --tail 70
microk8s.kubectl logs -n control-plane -c smf smf-0 --tail 70
microk8s.kubectl logs -n control-plane -c udm udm-0 --tail 70
microk8s.kubectl logs -n control-plane -c udr udr-0 --tail 70
```

## Checkpoint 6: View the metrics

### Grafana Metrics

You can also revisit the Grafana dashboard to view the metrics for the test run.
You can see the IMSI is connected and has received an IP address.
There is now one active PDU session, and the ping test throughput can be seen in the graphs.

```{image} ../images/grafana_5g_dashboard_sim_after.png
:alt: Grafana dashboard showing throughput metrics
:align: center
```

## 10. Review

We have deployed 4 Kubernetes clusters, bootstrapped a Juju controller to manage them all, and deployed portions of the Charmed Aether SD-Core software according to CUPS principles.
You now have 5 Juju models as follows:

- `control-plane` where all the control functions are deployed
- `controller` where Juju manages state of the models
- `cos-lite` where the Canonical Observability Stack is deployed
- `gnbsim` where the gNB simulator is deployed
- `user-plane` where all the user plane function is deployed

You have learned how to:

- view the logs for the various functions
- manage the integrations between deployed functions
- run a simulation testing data flow through the 5G core
- view the metrics produced by the 5G core

```{note}
For your convenience, a complete Terraform module covering the deployments and integrations from this tutorial, is available in [this Git repository](https://github.com/canonical/charmed-aether-sd-core).
All necessary files are in the `examples/terraform/mastering` directory.
```

## 11. Cleaning up

On the host machine, destroy the Terraform deployment to get rid of the whole infrastructure:

```console
terraform destroy -auto-approve
```

```{note}
Terraform does not remove anything from the working directory.
If needed, please clean up the `terraform` directory manually by removing everything except for the `main.tf` and `versions.tf` files.
```


[SR-IOV Network Device Plugin]: https://github.com/k8snetworkplumbingwg/sriov-network-device-plugin
[sdcore-user-plane-k8s]: https://github.com/canonical/terraform-juju-sdcore/tree/main/modules/sdcore-user-plane-k8s
[LXD]: https://canonical.com/lxd
