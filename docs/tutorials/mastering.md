# Mastering

In this tutorial, we will deploy and run the SD-Core 5G core network following Control and User Plane Separation (CUPS) principles.
The radio and cell phone simulator will also be deployed on an isolated cluster.
[Multipass](https://multipass.run/) is used to create separate VMs connected with [LXD](https://ubuntu.com/lxd) networking.

## 1. Prepare the Host machine

A machine running Ubuntu 22.04 with the following resources:

- At least one NIC with internet access
- 8 cores
- 32 GB RAM
- 150 GiB disk

### Networks

The following IP networks will be used to connect and isolate the network functions:

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

```console
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

```console
sudo chmod 600 /etc/netplan/99-sdcore-networks.yaml
sudo netplan apply
```

```{note}
Applying new netplan configuration may produce warnings related to file permissions being too open. 
You may safely disregard them.
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

## 2. Create Virtual Machines

To complete this tutorial, you will need seven virtual machines with access to the networks as follows:

| Machine                              | CPUs | RAM | Disk | Networks                       |
|--------------------------------------|------|-----|------|--------------------------------|
| DNS Server                           | 1    | 1g  | 10g  | `management`                   |
| Control Plane Kubernetes Cluster     | 4    | 8g  | 40g  | `management`                   |
| User Plane Kubernetes Cluster        | 2    | 4g  | 20g  | `management`, `access`, `core` |
| Juju Controller + Kubernetes Cluster | 4    | 6g  | 40g  | `management`                   |
| gNB Simulator Kubernetes Cluster     | 2    | 3g  | 20g  | `management`, `ran`            |
| RAN Access Router                    | 1    | 1g  | 10g  | `management`, `ran` , `access` |
| Core Router                          | 1    | 1g  | 10g  | `management`, `core`           |

Create VMs with Multipass:

```console
multipass launch -c 1 -m 1G -d 10G -n dns --network mgmt-br jammy
multipass launch -c 4 -m 8G -d 40G -n control-plane --network mgmt-br jammy
multipass launch -c 2 -m 4G -d 20G -n user-plane  --network mgmt-br --network core-br --network access-br jammy
multipass launch -c 4 -m 6G -d 40G -n juju-controller --network mgmt-br jammy
multipass launch -c 2 -m 3G -d 20G -n gnbsim --network mgmt-br --network ran-br jammy
multipass launch -c 1 -m 1G -d 10G -n ran-access-router --network mgmt-br --network ran-br --network access-br jammy
multipass launch -c 1 -m 1G -d 10G -n core-router --network mgmt-br --network core-br jammy
```

Wait until all the VMs are in a `Running` state.

### Checkpoint 1: Are the VM's ready ?

You should be able to see all the VMs in a `Running` state with their default IP addresses by executing the following command:

```console
multipass list
```

The output should be similar to the following:

```
Name                    State             IPv4             Image
juju-controller         Running           10.231.204.5     Ubuntu 22.04 LTS
core-router             Running           10.231.204.200   Ubuntu 22.04 LTS
control-plane           Running           10.231.204.202   Ubuntu 22.04 LTS
dns                     Running           10.231.204.96    Ubuntu 22.04 LTS
gnbsim                  Running           10.231.204.24    Ubuntu 22.04 LTS
ran-access-router       Running           10.231.204.220   Ubuntu 22.04 LTS
user-plane              Running           10.231.204.121   Ubuntu 22.04 LTS
```

### Install the DNS Server

Log in to the `dns` VM:

```console
multipass shell dns
```

First, replace the content of `/etc/netplan/50-cloud-init.yaml` to configure `mgmt` interface IP address as `10.201.0.100`:

```console
cat << EOF | sudo tee /etc/netplan/50-cloud-init.yaml
network:
    ethernets:
        enp5s0:
            dhcp4: true
        enp6s0:
            dhcp4: false
            addresses:
              - 10.201.0.100/24
    version: 2
EOF
```

Apply the network configuration:

```console
sudo chmod 600 /etc/netplan/50-cloud-init.yaml
sudo netplan apply
```

Install the DNS server:

```console
sudo apt update
sudo apt install dnsmasq -y
sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved
sudo systemctl restart dnsmasq
```

Configure dnsmasq:

```console
cat << EOF | sudo tee /etc/dnsmasq.conf
no-resolv
server=8.8.8.8
server=8.8.4.4
domain=mgmt
addn-hosts=/etc/hosts.tutorial
EOF
```

Update resolv.conf as we are no longer using systemd-resolved:

```console
sudo rm /etc/resolv.conf
echo 127.0.0.1 | sudo tee /etc/resolv.conf
```

The following IP addresses are used in this tutorial and must be present in the DNS Server that all hosts are using:

| Name                                   | IP Address   | Purpose                                                  |
|----------------------------------------|--------------|----------------------------------------------------------|
| `juju-controller.mgmt`                 | 10.201.0.104 | Management address for Juju machine                      |
| `control-plane.mgmt`                   | 10.201.0.101 | Management address for control plane cluster machine     |
| `user-plane.mgmt`                      | 10.201.0.102 | Management address for user plane cluster machine        |
| `gnbsim.mgmt`                          | 10.201.0.103 | Management address for the gNB Simulator cluster machine |
| `api.juju-controller.mgmt`             | 10.201.0.50  | Juju controller address                                  |
| `cos.mgmt`                             | 10.201.0.51  | Canonical Observability Stack address                    |
| `amf.mgmt`                             | 10.201.0.52  | Externally reachable control plane endpoint for the AMF  |
| `control-plane-nms.control-plane.mgmt` | 10.201.0.53  | Externally reachable control plane endpoint for the NMS  |
| `upf.mgmt`                             | 10.201.0.200 | Externally reachable control plane endpoint for the UPF  |

Add records under /etc/hosts:

```console
cat << EOF | sudo tee -a /etc/hosts.tutorial
10.201.0.50    api.juju-controller.mgmt
10.201.0.51    cos.mgmt
10.201.0.52    amf.mgmt
10.201.0.53    control-plane-nms.control-plane.mgmt
10.201.0.101   control-plane.mgmt
10.201.0.102   user-plane.mgmt
10.201.0.103   gnbsim.mgmt
10.201.0.104   juju-controller.mgmt
10.201.0.200   upf.mgmt
EOF
```

Reload the DNS configuration:

```console
sudo systemctl restart dnsmasq
```

### Checkpoint 2: Is the DNS server running properly?

Check the status of the `dnsmasq` service:

```console
sudo systemctl status dnsmasq
```

The expected result should be similar to the below:

```
dnsmasq.service - dnsmasq - A lightweight DHCP and caching DNS server
     Loaded: loaded (/lib/systemd/system/dnsmasq.service; enabled; vendor preset: enabled)
     Active: active (running) since Thu 2024-01-11 13:46:34 +03; 6ms ago
    Process: 2611 ExecStartPre=/etc/init.d/dnsmasq checkconfig (code=exited, status=0/SUCCESS)
    Process: 2619 ExecStart=/etc/init.d/dnsmasq systemd-exec (code=exited, status=0/SUCCESS)
    Process: 2628 ExecStartPost=/etc/init.d/dnsmasq systemd-start-resolvconf (code=exited, status=0/SUCCESS)
```

Test the DNS resolution:

```console
host upf.mgmt
```

You should see `upf.mgmt has address 10.201.0.200`.

Log out of the VM.

### Add DNS server and routes to the other VM's

#### User-plane VM

Log in to the `user-plane` VM:

```console
multipass shell user-plane
```

Configure IP address for `mgmt`, `core` and `access` interfaces, add nameservers  for the `mgmt` interface and add route from `access` to `ran` network by replacing the content of `/etc/netplan/50-cloud-init.yaml`:

```console
cat << EOF | sudo tee /etc/netplan/50-cloud-init.yaml
network:
    ethernets:
        enp5s0:
            dhcp4: true
        enp6s0:
            dhcp4: false
            addresses:
              - 10.201.0.102/24
            nameservers:
                search: [mgmt]
                addresses: [10.201.0.100]
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

```console
sudo chmod 600 /etc/netplan/50-cloud-init.yaml
sudo netplan apply
```

Check the current DNS server:

```console
resolvectl
```

You should see the new DNS server on `Link 3`:

```
Link 3 (enp6s0)
Current Scopes: DNS
     Protocols: +DefaultRoute +LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported
   DNS Servers: 10.201.0.100
    DNS Domain: mgmt
```

Check the route from `access` interface to the `ran` network:

```console
ip route
```

You should see the following routes in addition to the regular host routes:

```
10.201.0.0/24 dev enp6s0 proto kernel scope link src 10.201.0.102
10.202.0.0/24 dev enp8s0 proto kernel scope link src 10.202.0.100
10.203.0.0/24 dev enp7s0 proto kernel scope link src 10.203.0.100
10.204.0.0/24 via 10.202.0.1 dev enp8s0 proto static
```

Log out of the VM.

#### Control-plane VM

Log in to the `control-plane` VM:

```console
multipass shell control-plane
```

Configure IP address and nameservers for `mgmt` interface by replacing the content of `/etc/netplan/50-cloud-init.yaml`:

```console
cat << EOF | sudo tee /etc/netplan/50-cloud-init.yaml
network:
    ethernets:
        enp5s0:
            dhcp4: true
        enp6s0:
            dhcp4: false
            addresses:
              - 10.201.0.101/24
            nameservers:
                search: [mgmt]
                addresses: [10.201.0.100]
            optional: true
    version: 2
EOF
```

Apply the network configuration:

```console
sudo chmod 600 /etc/netplan/50-cloud-init.yaml
sudo netplan apply
```

Check the current DNS server:

```console
resolvectl
```

Log out of the VM.

#### Gnbsim VM

Log in to the `gnbsim` VM:

```console
multipass shell gnbsim
```

Configure IP address for `mgmt` and `ran` interfaces add nameservers for the `mgmt` interface and add route from `ran` to `access` network by replacing the content of `/etc/netplan/50-cloud-init.yaml`:

```console
cat << EOF | sudo tee /etc/netplan/50-cloud-init.yaml
network:
    ethernets:
        enp5s0:
            dhcp4: true
        enp6s0:
            dhcp4: false
            addresses:
              - 10.201.0.103/24
            nameservers:
                search: [mgmt]
                addresses: [10.201.0.100]
            optional: true
        enp7s0:
            dhcp4: false
            addresses:
              - 10.204.0.100/24
            routes:
              - to: 10.202.0.0/24
                via: 10.204.0.1
            optional: true
    version: 2
EOF
```

Apply the network configuration:

```console
sudo chmod 600 /etc/netplan/50-cloud-init.yaml
sudo netplan apply
```

Check the current DNS server:

```console
resolvectl
```

Check the route from `ran` interface to the `access` network:

```console
ip route
```

You should see the following routes in addition to the regular host routes:

```
10.201.0.0/24 dev enp6s0 proto kernel scope link src 10.201.0.103
10.202.0.0/24 via 10.204.0.1 dev enp7s0 proto static
10.204.0.0/24 dev enp7s0 proto kernel scope link src 10.204.0.100
```

Log out of the VM.

#### Juju-controller VM

Log in to the `juju-controller` VM:

```console
multipass shell juju-controller
```

Configure IP address and nameservers for `mgmt` interface by replacing the content of `/etc/netplan/50-cloud-init.yaml`:

```console
cat << EOF | sudo tee /etc/netplan/50-cloud-init.yaml
network:
    ethernets:
        enp5s0:
            dhcp4: true
        enp6s0:
            dhcp4: false
            addresses:
              - 10.201.0.104/24
            nameservers:
                search: [mgmt]
                addresses: [10.201.0.100]
            optional: true
    version: 2
EOF
```

Apply the network configuration:

```console
sudo chmod 600 /etc/netplan/50-cloud-init.yaml
sudo netplan apply
```

Check the current DNS server:

```console
resolvectl
```

Log out of the VM.

#### RAN-access-router VM

Log in to the `ran-access-router` VM:

```console
multipass shell ran-access-router
```

Configure IP address for `mgmt`, `ran` and `access` interfaces by replacing the content of `/etc/netplan/50-cloud-init.yaml`:

```console
cat << EOF | sudo tee /etc/netplan/50-cloud-init.yaml
network:
    ethernets:
        enp5s0:
            dhcp4: true
        enp6s0:
            dhcp4: false
            addresses:
              - 10.201.0.110/24
            optional: true
        enp7s0:
            dhcp4: false
            addresses:
              - 10.204.0.1/24
            optional: true
        enp8s0:
            dhcp4: false
            addresses:
              - 10.202.0.1/24
            optional: true
    version: 2
EOF
```

Apply the network configuration:

```console
sudo chmod 600 /etc/netplan/50-cloud-init.yaml
sudo netplan apply
```

The `access-gateway-ip` is expected to forward the packets from the `access-interface` to the `gnb-subnet`.

Set up IP forwarding:

```console
echo net.ipv4.ip_forward=1 | sudo tee /etc/sysctl.conf
sudo sysctl -w net.ipv4.ip_forward=1
```

Log out of the VM.

#### Core-router VM

Log in to the `core-router` VM:

```console
multipass shell core-router
```

Configure IP address for `mgmt` and `core` interfaces by replacing the content of `/etc/netplan/50-cloud-init.yaml`:

```console
cat << EOF | sudo tee /etc/netplan/50-cloud-init.yaml
network:
    ethernets:
        enp5s0:
            dhcp4: true
        enp6s0:
            dhcp4: false
            addresses:
              - 10.201.0.114/24
            optional: true
        enp7s0:
            dhcp4: false
            addresses:
              - 10.203.0.1/24
            optional: true
    version: 2
EOF
```

Apply the network configuration:

```console
sudo chmod 600 /etc/netplan/50-cloud-init.yaml
sudo netplan apply
```

Set up IP forwarding and NAT:

```console
cat << EOF | sudo tee /etc/rc.local
#!/bin/bash
iptables -t nat -A POSTROUTING -o enp5s0 -j MASQUERADE -s 10.203.0.0/24
EOF
sudo chmod +x /etc/rc.local
sudo /etc/rc.local
sudo sysctl -w net.ipv4.ip_forward=1 | sudo tee -a /etc/sysctl.conf
```

Log out of the VM.

## 3. Configure VMs for SD-Core Deployment

This section covers setting up the SSH keys and installation of necessary tools on the VMs which are going to build up the infrastructure for SD-Core.

As we are going to be copying files around using ssh, we now will set up a new ssh key on the host running the tutorial:

```console
ssh-keygen -f ~/tutorial_rsa -N ""
```

Copy the keys to all the SD-Core VMs:

```console
for VM in control-plane juju-controller gnbsim user-plane
do
  multipass transfer ~/tutorial_rsa ${VM}:.ssh/id_rsa
  multipass transfer ~/tutorial_rsa.pub ${VM}:.ssh/id_rsa.pub
  multipass exec ${VM} -- sh -c 'cat .ssh/id_rsa.pub >> .ssh/authorized_keys'
done
```

```{note}
You may now delete the `tutorial_rsa` and `tutorial_rsa.pub` files from the host.
```

### Prepare SD-Core Control Plane VM

Login to the `control-plane` VM:

```console
multipass shell control-plane
```

Install MicroK8s:

```console
sudo snap install microk8s --channel=1.29-strict/stable
sudo microk8s enable hostpath-storage
sudo usermod -a -G snap_microk8s $USER
```

The control plane needs to expose two services: the AMF and the NMS.
In this step, we enable the MetalLB add on in MicroK8s, and give it a range of two IP addresses:

```console
sudo microk8s enable metallb:10.201.0.52-10.201.0.53
```

Now update MicroK8s DNS to point to our DNS server:

```console
sudo microk8s disable dns
sudo microk8s enable dns:10.201.0.100
```

Export the Kubernetes configuration and copy it to the `juju-controller` VM:

```console
sudo microk8s.config > control-plane-cluster.yaml
scp control-plane-cluster.yaml juju-controller.mgmt:
```

Log out of the VM.

### Prepare SD-Core User Plane VM

Log in to the `user-plane` VM:

```console
multipass shell user-plane
```

Install MicroK8s, configure MetalLB to expose 1 IP address for the UPF (`10.201.0.200`) and enable the Multus plugin:

```console
sudo snap install microk8s --channel=1.29-strict/stable
sudo microk8s enable hostpath-storage
sudo microk8s enable metallb:10.201.0.200/32
sudo microk8s addons repo add community \
    https://github.com/canonical/microk8s-community-addons \
    --reference feat/strict-fix-multus
sudo microk8s enable multus
sudo usermod -a -G snap_microk8s $USER
```

Update MicroK8s DNS to point to our DNS server:

```console
sudo microk8s disable dns
sudo microk8s enable dns:10.201.0.100
```

Export the Kubernetes configuration and copy it to the `juju-controller` VM:

```console
sudo microk8s.config > user-plane-cluster.yaml
scp user-plane-cluster.yaml juju-controller.mgmt:
```

In this guide, the following network interfaces are available on the SD-Core `user-plane` VM:

| Interface Name | Purpose                                                                                                                                                           |
|----------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| enp6s0         | internal Kubernetes management interface. This maps to the `management` subnet.                                                                                   |
| enp7s0         | core interface. This maps to the `core` subnet.                                                                                                                   |
| enp8s0         | access interface. This maps to the `access` subnet. Note that internet egress is required here and routing tables are already set to route gNB generated traffic. |

Now we create the MACVLAN bridges for `enp7s0` and `enp8s0`.
These instructions are put into a file that is executed on reboot so the interfaces will come back:

```console
cat << EOF | sudo tee /etc/rc.local
#!/bin/bash

sudo ip link add access link enp8s0 type macvlan mode bridge
sudo ip link set dev access up
sudo ip link add core link enp7s0 type macvlan mode bridge
sudo ip link set dev core up
EOF
sudo chmod +x /etc/rc.local
sudo /etc/rc.local
```

Log out of the VM.

### Prepare gNB Simulator VM

Log in to the `gnbsim` VM:

```console
multipass shell gnbsim
```

Install MicroK8s and add the Multus plugin:

```console
sudo snap install microk8s --channel=1.29-strict/stable
sudo microk8s enable hostpath-storage
sudo microk8s addons repo add community \
    https://github.com/canonical/microk8s-community-addons \
    --reference feat/strict-fix-multus
sudo microk8s enable multus
sudo usermod -a -G snap_microk8s $USER
```

Update MicroK8s DNS to point to our DNS server:

```console
sudo microk8s disable dns
sudo microk8s enable dns:10.201.0.100
```

Export the Kubernetes configuration and copy it to the `juju-controller` VM:

```console
sudo microk8s.config > gnb-cluster.yaml
scp gnb-cluster.yaml juju-controller.mgmt:
```

In this guide, the following network interfaces are available on the `gnbsim` VM:

| Interface Name | Purpose                                                                         |
|----------------|---------------------------------------------------------------------------------|
| enp6s0         | internal Kubernetes management interface. This maps to the `management` subnet. |
| enp7s0         | ran interface. This maps to the `ran` subnet.                                   |

Now we create the MACVLAN bridges for `enp7s0`, and label them accordingly:

```console
cat << EOF | sudo tee /etc/rc.local
#!/bin/bash

sudo ip link add ran link enp7s0 type macvlan mode bridge
sudo ip link set dev ran up
EOF
sudo chmod +x /etc/rc.local
sudo /etc/rc.local
```

Log out of the VM.

### Prepare the Juju Controller VM

Log in to the `juju-controller` VM:

```console
multipass shell juju-controller
```

Begin by installing MicroK8s to hold the Juju controller.
Configure MetalLB to expose one IP address for the controller (`10.201.0.50`) and one for the Canonical Observability Stack (`10.201.0.51)`:

```console
sudo snap install microk8s --channel=1.29-strict/stable
sudo microk8s enable hostpath-storage
sudo microk8s enable metallb:10.201.0.50-10.201.0.51
sudo usermod -a -G snap_microk8s $USER
newgrp snap_microk8s
```

Update MicroK8s DNS to point to our DNS server:

```console
sudo microk8s disable dns
sudo microk8s enable dns:10.201.0.100
```

```{note}
The `microk8s enable` command confirms enabling the DNS before it actually happens.
Before going forward, please make sure that the DNS is actually running. 
To do that run `microk8s.kubectl -n kube-system get pods` and make sure that the `coredns` pod is in `Running` status.
```

Install Juju and bootstrap the controller to the local MicroK8s install as a LoadBalancer service.
This will expose the Juju controller on the first allocated MetalLB address:

```console
mkdir -p ~/.local/share/juju
sudo snap install juju --channel=3.4/stable
juju bootstrap microk8s --config controller-service-type=loadbalancer sdcore
```

At this point, the Juju controller is ready to start managing external clouds.
Add the Kubernetes clusters representing the user plane, control plane, and gNB simulator to Juju.
This is done by using the Kubernetes configuration file generated when setting up the clusters above.

```console
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

Log out of the VM.

```{note}
Due to the newgrp command you will need to log out twice as it started a new shell.
```

## 4. Deploy SD-Core Control Plane

The following steps build on the Juju controller which was bootstrapped and knows how to manage the SD-Core Control Plane Kubernetes cluster.

First, we will create a new Terraform module which we will use to deploy SD-Core Control Plane.
After the successful deployment, we will configure the Access and Mobility Management Function (AMF) IP address for sharing with the radios and the Traefik external hostname for exposing the SD-Core Network Management System (NMS).
This host name must be resolvable by the gNB and the IP address must be reachable and resolve to the AMF unit.
In the bootstrap step, we set the Control Plane MetalLB IP range, and that is what we use in the configuration.
Lastly, the module will expose the Software as a Service offer for the AMF.

Log into the `juju-controller` VM:

```console
multipass shell juju-controller
```

Create Juju model for the SD-Core Control Plane:

```console
juju add-model control-plane control-plane-cluster
```

Create new folder called `terraform`:

```console
mkdir terraform
```

Inside newly created `terraform` folder create a `terraform.tf` file:

```console
cd terraform
cat << EOF > terraform.tf
terraform {
  required_providers {
    juju = {
      source  = "juju/juju"
      version = "~> 0.11.0"
    }
  }
}
EOF
```

Create Terraform module:

```console
cat << EOF > main.tf
module "sdcore-control-plane" {
  source = "git::https://github.com/canonical/terraform-juju-sdcore-k8s//modules/sdcore-control-plane-k8s"

  model_name   = "control-plane"
  create_model = false

  amf_config = {
    external-amf-hostname = "amf.mgmt"
  }
  traefik_config = {
    routing_mode = "subdomain"
  }
}

resource "juju_offer" "amf-fiveg-n2" {
  model            = "control-plane"
  application_name = module.sdcore-control-plane.amf_app_name
  endpoint         = module.sdcore-control-plane.fiveg_n2_endpoint
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
watch -n 1 -c juju status --color --relations
```

The deployment is ready when all the charms are in the `Active/Idle` state.
It is normal for `grafana-agent` to remain in waiting state.

Once the deployment is ready, we will proceed to the configuration part.

Log out of the VM.

Get the IP addresses of the AMF and Traefik LoadBalancer services:

Log in to the `control-plane` VM:

```console
multipass shell control-plane
```

Get LoadBalancer services:

```console
microk8s.kubectl get services -A | grep LoadBalancer
```

This will show output similar to the following:

```console
control-plane    amf-external  LoadBalancer  10.152.183.179  10.201.0.52   38412:30408/SCTP
control-plane    traefik       LoadBalancer  10.152.183.28   10.201.0.53   80:32349/TCP,443:31925/TCP
```

Note both IPs - in this case `10.201.0.52` for the AMF and `10.201.0.53` for Traefik.
We will need them shortly.

Log out of the VM.

Log into the `juju-controller` VM:

```console
multipass shell juju-controller
```

Configure AMF external IP, using the address obtained in the previous step.
To do that, edit `amf_config` in the `main.tf` file in the `terraform` directory:

```console
cd terraform
```

Updated `amf_config` should look like similar to the below:

```
(...)
module "sdcore-control-plane" {
  (...)
  amf_config = {
    external-amf-ip       = "10.201.0.52"
    external-amf-hostname = "amf.mgmt"
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

Log out of the VM.

## 5. Deploy SD-Core User Plane

The following steps build on the Juju controller which was bootstrapped and knows how to manage the SD-Core User Plane Kubernetes cluster.

First, we will add SD-Core User Plane to the Terraform module created in the previous step.
We will provide necessary configuration (please see the list of the config options with the description in the table below) for the User Plane Function (UPF).
Lastly, we will expose the Software as a Service offer for the UPF.

| Config Option         | Descriptions                                                                                      |
|-----------------------|---------------------------------------------------------------------------------------------------|
| access-gateway-ip     | The IP address of the gateway that knows how to route traffic from the UPF towards the gNB subnet |
| access-interface      | The name of the MACVLAN interface on the Kubernetes host cluster to bridge to the `access` subnet |
| access-ip             | The IP address for the UPF to use on the `access` subnet                                          |
| core-gateway-ip       | The IP address of the gateway that knows how to route traffic from the UPF towards the internet   |
| core-interface        | The name of the MACVLAN interface on the Kubernetes host cluster to bridge to the `core` subnet   |
| core-ip               | The IP address for the UPF to use on the `core` subnet                                            |
| external-upf-hostname | The DNS name of the UPF                                                                           |
| gnb-subnet            | The subnet CIDR where the gNB radios are reachable.                                               |

Log into the `juju-controller` VM:

```console
multipass shell juju-controller
```

Create Juju model for the SD-Core Control Plane:

```console
juju add-model user-plane user-plane-cluster
```

Enter the `terraform` folder created in the previous step:

```console
cd terraform
```

Update the `main.tf` file:

```console
cat << EOF >> main.tf
module "sdcore-user-plane" {
  source = "git::https://github.com/canonical/terraform-juju-sdcore-k8s//modules/sdcore-user-plane-k8s"

  model_name   = "user-plane"
  create_model = false

  upf_config = {
    cni-type              = "macvlan" 
    access-gateway-ip     = "10.202.0.1"
    access-interface      = "access"
    access-ip             = "10.202.0.10/24"
    core-gateway-ip       = "10.203.0.1"
    core-interface        = "core"
    core-ip               = "10.203.0.10/24"
    external-upf-hostname = "upf.mgmt"
    gnb-subnet            = "10.204.0.0/24"
  }
}

resource "juju_offer" "upf-fiveg-n4" {
  model            = "user-plane"
  application_name = module.sdcore-user-plane.upf_app_name
  endpoint         = module.sdcore-user-plane.fiveg_n4_endpoint
}

EOF
```

Update Juju Terraform provider:

```console
terraform init
```

Deploy SD-Core User Plane:

```console
terraform apply -auto-approve
```

Monitor the status of the deployment:

```console
watch -n 1 -c juju status --color --relations
```

The deployment is ready when the UPF application is in the `Active/Idle` state.
It is normal for `grafana-agent` to remain in waiting state.

Log out of the VM.

### Checkpoint 3: Does the UPF external LoadBalancer service exist?

You should be able to see the UPF external LoadBalancer service in Kubernetes.

Log in to the `user-plane` VM:

```console
multipass shell user-plane
```

Get the LoadBalancer service:

```console
microk8s.kubectl get services -A | grep LoadBalancer
```

This should produce output similar to the following indicating that the PFCP agent of the UPF is exposed on `10.201.0.200` UDP port 8805:

```console
user-plane  upf-external  LoadBalancer  10.152.183.126  10.201.0.200  8805:31101/UDP
```

Log out of the VM.

## 6. Deploy the gNB Simulator

The following steps build on the Juju controller which was bootstrapped and knows how to manage the gNB Simulator Kubernetes cluster.

First, we will add gNB Simulator to the Terraform module used in the previous steps.
We will provide necessary configuration (please see the list of the config options with the description in the table below) for the application and integrate the simulator with previously exposed AMF offering.
Lastly, we will expose the Software as a Service offer for the simulator.

| Config Option           | Descriptions                                                                                                                                  |
|-------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------|
| gnb-interface           | The name of the MACVLAN interface to use on the host                                                                                          |
| gnb-ip-address          | The IP address to use on the gnb interface                                                                                                    |
| icmp-packet-destination | The target IP address to ping. If there is no egress to the internet on your core network, any IP that is reachable from the UPF should work. |
| upf-gateway             | The IP address of the gateway between the RAN and Access networks                                                                             |
| upf-subnet              | Subnet where the UPFs are located (also called Access network)                                                                                |

Log into the `juju-controller` VM:

```console
multipass shell juju-controller
```

Create Juju model for the SD-Core Control Plane:

```console
juju add-model gnbsim gnb-cluster
```

Enter the `terraform` folder created in the previous step:

```console
cd terraform
```

Update the `main.tf` file:

```console
cat << EOF >> main.tf
module "gnbsim" {
  source = "git::https://github.com/canonical/sdcore-gnbsim-k8s-operator//terraform"

  model_name = "gnbsim"
  
  config = {
    gnb-interface           = "ran"
    gnb-ip-address          = "10.204.0.10/24"
    icmp-packet-destination = "8.8.8.8"
    upf-gateway             = "10.204.0.1"
    upf-subnet              = "10.202.0.0/24"
  }
}

resource "juju_integration" "gnbsim-amf" {
  model = "gnbsim"

  application {
    name     = module.gnbsim.app_name
    endpoint = module.gnbsim.fiveg_n2_endpoint
  }

  application {
    offer_url = juju_offer.amf-fiveg-n2.url
  }
}

resource "juju_offer" "gnbsim-fiveg-gnb-identity" {
  model            = "gnbsim"
  application_name = module.gnbsim.app_name
  endpoint         = module.gnbsim.fiveg_gnb_identity_endpoint
}

EOF
```

Update Juju Terraform provider:

```console
terraform init
```

Deploy SD-Core User Plane:

```console
terraform apply -auto-approve
```

Monitor the status of the deployment:

```console
watch -n 1 -c juju status --color --relations
```

The deployment is ready when the `gnbsim` application is in the `Active/Idle` state.

Log out of the VM.

## 7. Configure SD-Core

The following steps show how to configure the SD-Core 5G core network.

We will start by creating integrations between the Network Management System (NMS) and the UPF and the gNB Simulator.
Once the integrations are ready, we will create the core network configuration: a network slice, a device group and a subscriber.

Log into the `juju-controller` VM:

```console
multipass shell juju-controller
```

Enter the `terraform` folder created in the previous step:

```console
cd terraform
```

Add required integrations to the `main.tf` file used in the previous steps:

```console
cat << EOF >> main.tf
resource "juju_integration" "nms-gnbsim" {
  model = "control-plane"

  application {
    name     = module.sdcore-control-plane.nms_app_name
    endpoint = module.sdcore-control-plane.fiveg_gnb_identity_endpoint
  }

  application {
    offer_url = juju_offer.gnbsim-fiveg-gnb-identity.url
  }
}

resource "juju_integration" "nms-upf" {
  model = "control-plane"

  application {
    name     = module.sdcore-control-plane.nms_app_name
    endpoint = module.sdcore-control-plane.fiveg_n4_endpoint
  }

  application {
    offer_url = juju_offer.upf-fiveg-n4.url
  }
}

EOF
```

Apply the changes:

```console
terraform apply -auto-approve
```

Retrieve the NMS address:

```console
juju switch control-plane
juju run traefik/0 show-proxied-endpoints
```

The output should be `http://control-plane-nms.10.201.0.53.nip.io/`.
Navigate to this address in your browser.

In the Network Management System (NMS), create a network slice with the following attributes:

- Name: `Tutorial`
- MCC: `208`
- MNC: `93`
- UPF: `upf.mgmt:8805`
- gNodeB: `gnbsim-gnbsim-gnbsim (tac:1)`

You should see the following network slice created.
Note the device group has been expanded to show the default group that is created in the slice for you.

```{image} ../images/nms_tutorial_network_slice_with_device_group.png
:alt: NMS Network Slice
:align: center
```

We will now add a subscriber with the IMSI that was provided to the gNB simulator.
Navigate to Subscribers and click on Create.
Fill in the following:

- IMSI: `208930100007487`
- OPC: `981d464c7c52eb6e5036234984ad0bcf`
- Key: `5122250214c33e723a5dd523fc145fc0`
- Sequence Number: `16f3b3f70fc2`
- Network Slice: `Tutorial`
- Device Group: `Tutorial-default`

Log out of the VM.

## 8. Integrate SD-Core with the Canonical Observability Stack (COS)

The following steps show how to integrate the SD-Core 5G core network with the Canonical Observability Stack (COS).

First, we will add COS to the Terraform module used in the previous steps.
Next, we will expose the Software as a Service offers for the COS and create integrations with SD-Core 5G core network components.

### Deploy COS Lite

Log into the `juju-controller` VM:

```console
multipass shell juju-controller
```

Enter the `terraform` folder created in the previous step:

```console
cd terraform
```

Add `cos-lite` Terraform module to the `main.tf` file used in the previous steps:

```console
cat << EOF >> main.tf
module "cos-lite" {
  source = "git::https://github.com/canonical/terraform-juju-sdcore-k8s//modules/external/cos-lite"

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

Expose the Software as a Service offers for the COS:

```console
cat << EOF >> main.tf
resource "juju_offer" "prometheus-remote-write" {
  model            = module.cos-lite.model_name
  application_name = module.cos-lite.prometheus_app_name
  endpoint         = "receive-remote-write"
}

resource "juju_offer" "loki-logging" {
  model            = module.cos-lite.model_name
  application_name = module.cos-lite.loki_app_name
  endpoint         = "logging"
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
watch -n 1 -c juju status --color --relations
```

The deployment is ready when all the charms are in the `Active/Idle` state.

### Integrate SD-Core with COS Lite

Once the COS deployment is ready, add integrations between SD-Core and COS applications to the `main.tf` file:

```console
cat << EOF >> main.tf
resource "juju_integration" "control-plane-prometheus" {
  model = "control-plane"

  application {
    name     = module.sdcore-control-plane.grafana_agent_app_name
    endpoint = module.sdcore-control-plane.send_remote_write_endpoint
  }

  application {
    offer_url = juju_offer.prometheus-remote-write.url
  }
}

resource "juju_integration" "control-plane-loki" {
  model = "control-plane"

  application {
    name     = module.sdcore-control-plane.grafana_agent_app_name
    endpoint = module.sdcore-control-plane.logging_consumer_endpoint
  }

  application {
    offer_url = juju_offer.loki-logging.url
  }
}

resource "juju_integration" "user-plane-prometheus" {
  model = "user-plane"

  application {
    name     = module.sdcore-user-plane.grafana_agent_app_name
    endpoint = module.sdcore-user-plane.send_remote_write_endpoint
  }

  application {
    offer_url = juju_offer.prometheus-remote-write.url
  }
}

resource "juju_integration" "user-plane-loki" {
  model = "user-plane"

  application {
    name     = module.sdcore-user-plane.grafana_agent_app_name
    endpoint = module.sdcore-user-plane.logging_consumer_endpoint
  }

  application {
    offer_url = juju_offer.loki-logging.url
  }
}

EOF
```

Apply the changes:

```console
terraform apply -auto-approve
```

## Checkpoint 4: Is Grafana dashboard available?

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
info: run juju debug-log to get more information.
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
juju debug-log | grep imsi-208930100007487
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

Destroy Terraform deployment:

```console
terraform destroy -auto-approve
```

```{note}
Terraform does not remove anything from the working directory.
If needed, please clean up the `terraform` directory manually by removing everything except for the `main.tf` and `terraform.tf` files.
```

Destroy Juju controller:

```bash
juju destroy-controller --destroy-all-models sdcore --destroy-storage
```

You can now proceed to remove Juju itself on the `juju-controller` VM:

```console
sudo snap remove juju
```

MicroK8s can also be removed from each cluster as follows:

```console
sudo snap remove microk8s
```

You may wish to reboot the Multipass VMs to ensure no residual network configurations remain.

Multipass VMs also can be deleted from the host machine:

```console
multipass delete --all
```

If required, all the VMs can be permanently removed:

```console
multipass purge
```

Remove the configuration file from the host machine:

```console
sudo rm /etc/netplan/99-sdcore-networks.yaml
```

Reboot the host machine to restore the network configuration to the original state.
