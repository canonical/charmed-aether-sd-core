# Getting started

In this tutorial, we will deploy and run an SD-Core 5G core network using Juju and Terraform.
As part of this tutorial, we will also deploy additional components:

- gNB Simulator: a 5G radio and a cellphone simulator,
- SD-Core Router: a software router facilitating communication between the core and the Radio
 Access Network (RAN) to simulate usage of this network.

Both gNB Simulator and SD-Core Router serve only demonstration purposes and shouldn't be part
 of production deployments.

To complete this tutorial, you will need a machine which meets the following requirements:

- A recent `x86_64` CPU (Intel 4ᵗʰ generation or newer, or AMD Ryzen or newer)
- At least 4 cores
- 8GB of RAM
- 50GB of free disk space

## 1. Install MicroK8s

From your terminal, install MicroK8s:

```console
sudo snap install microk8s --channel=1.27-strict/stable
```

Add your user to the `snap_microk8s` group:

```console
sudo usermod -a -G snap_microk8s $USER
newgrp snap_microk8s
```

Add the community repository MicroK8s addon:

```console
sudo microk8s addons repo add community https://github.com/canonical/microk8s-community-addons --reference feat/strict-fix-multus
```

Enable the following MicroK8s addons. We must give MetalLB an address
range that has at least 3 IP addresses for Charmed Aether SD-Core.

```console
sudo microk8s enable hostpath-storage
sudo microk8s enable multus
sudo microk8s enable metallb:10.0.0.2-10.0.0.4
```

## 2. Bootstrap a Juju controller

From your terminal, install Juju.

```console
sudo snap install juju --channel=3.4/stable
```

Bootstrap a Juju controller

```console
juju bootstrap microk8s
```

```{note}
There is a [bug](https://bugs.launchpad.net/juju/+bug/1988355) in Juju that occurs when
bootstrapping a controller on a new machine. If you encounter it, create the following
directory:
`mkdir -p /home/ubuntu/.local/share`
```

## 3. Install Terraform

From your terminal, install Terraform.

```console
sudo snap install terraform --classic
```

## 4. Create Terraform module

On the host machine create a new directory called `terraform`:

```console
mkdir terraform
```

Inside newly created `terraform` directory create a `terraform.tf` file:

```console
cd terraform
cat << EOF > terraform.tf
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

Create a Terraform module containing the SD-Core 5G core network, 5G radio and a cellphone
simulator and a router:

```console
cat << EOF > main.tf
resource "juju_model" "sdcore" {
  name = "sdcore"
}

module "sdcore-router" {
  source = "git::https://github.com/canonical/sdcore-router-k8s-operator//terraform"

  model_name = juju_model.sdcore.name
  depends_on = [juju_model.sdcore]
}

module "sdcore" {
  source = "git::https://github.com/canonical/terraform-juju-sdcore//modules/sdcore-k8s"

  model_name = juju_model.sdcore.name
  create_model = false

  traefik_config = {
    routing_mode = "subdomain"
  }

  depends_on = [module.sdcore-router]
}

module "gnbsim" {
  source = "git::https://github.com/canonical/sdcore-gnbsim-k8s-operator//terraform"

  model_name = juju_model.sdcore.name
  depends_on = [module.sdcore-router]
}

resource "juju_integration" "gnbsim-amf" {
  model = juju_model.sdcore.name

  application {
    name     = module.gnbsim.app_name
    endpoint = module.gnbsim.fiveg_n2_endpoint
  }

  application {
    name     = module.sdcore.amf_app_name
    endpoint = module.sdcore.fiveg_n2_endpoint
  }
}

resource "juju_integration" "gnbsim-nms" {
  model = juju_model.sdcore.name

  application {
    name     = module.gnbsim.app_name
    endpoint = module.gnbsim.fiveg_gnb_identity_endpoint
  }

  application {
    name     = module.sdcore.nms_app_name
    endpoint = module.sdcore.fiveg_gnb_identity_endpoint
  }
}
EOF
```

```{note}
You can get a ready example by cloning [this Git repository](https://github.com/canonical/charmed-aether-sd-core).
All necessary files are in the `examples/terraform/getting_started` directory.
```

## 5. Deploy SD-Core

Initialize Juju Terraform provider:

```console
terraform init
```

Deploy SD-Core by applying your Terraform configuration:

```console
terraform apply -auto-approve
```

The deployment process should take approximately 15-20 minutes.

Monitor the status of the deployment:

```console
juju switch sdcore
watch -n 1 -c juju status --color --relations
```

The deployment is ready when all the charms are in the `Active/Idle` state.<br>
It is normal for `grafana-agent` to remain in waiting state.<br>
It is also expected that `traefik` goes to the error state (related Traefik [bug](https://github.com/canonical/traefik-k8s-operator/issues/361)).

Example:

```console
ubuntu@host:~$ juju status
Model      Controller                  Cloud/Region                Version  SLA          Timestamp
sdcore  microk8s-localhost  microk8s-classic/localhost  3.4.5    unsupported  08:08:50Z

App                       Version  Status   Scale  Charm                     Channel        Rev  Address         Exposed  Message
amf                       1.4.4    active       1  sdcore-amf-k8s            1.5/edge       707  10.152.183.176  no       
ausf                      1.4.2    active       1  sdcore-ausf-k8s           1.5/edge       520  10.152.183.65   no       
grafana-agent             0.32.1   waiting      1  grafana-agent-k8s         latest/stable   45  10.152.183.221  no       installing agent
mongodb                            active       1  mongodb-k8s               6/beta          38  10.152.183.92   no       Primary
nms                       1.0.0    active       1  sdcore-nms-k8s            1.5/edge       580  10.152.183.141  no       
nrf                       1.4.1    active       1  sdcore-nrf-k8s            1.5/edge       580  10.152.183.130  no       
nssf                      1.4.1    active       1  sdcore-nssf-k8s           1.5/edge       462  10.152.183.62   no       
pcf                       1.4.3    active       1  sdcore-pcf-k8s            1.5/edge       512  10.152.183.144  no       
router                             active       1  sdcore-router-k8s         1.5/edge       341  10.152.183.218  no       
self-signed-certificates           active       1  self-signed-certificates  latest/stable  155  10.152.183.33   no       
smf                       1.5.2    active       1  sdcore-smf-k8s            1.5/edge       590  10.152.183.64   no       
traefik                   v2.11.0  waiting      1  traefik-k8s               latest/stable  194  10.152.183.198  no       installing agent
udm                       1.4.3    active       1  sdcore-udm-k8s            1.5/edge       489  10.152.183.31   no       
udr                       1.4.1    active       1  sdcore-udr-k8s            1.5/edge       486  10.152.183.82   no       
upf                       1.4.0    active       1  sdcore-upf-k8s            1.5/edge       591  10.152.183.164  no       

Unit                         Workload  Agent  Address      Ports  Message
amf/0*                       active    idle   10.1.10.181         
ausf/0*                      active    idle   10.1.10.186         
grafana-agent/0*             blocked   idle   10.1.10.133         grafana-cloud-config: off, logging-consumer: off
mongodb/0*                   active    idle   10.1.10.155         Primary
nms/0*                       active    idle   10.1.10.174         
nrf/0*                       active    idle   10.1.10.151         
nssf/0*                      active    idle   10.1.10.136         
pcf/0*                       active    idle   10.1.10.146         
router/0*                    active    idle   10.1.10.145         
self-signed-certificates/0*  active    idle   10.1.10.141         
smf/0*                       active    idle   10.1.10.154         
traefik/0*                   error     idle   10.1.10.160         hook failed: "ingress-relation-changed"
udm/0*                       active    idle   10.1.10.187         
udr/0*                       active    idle   10.1.10.176         
upf/0*                       active    idle   10.1.10.169
```

## 6. Configure the ingress

Get the external IP address of Traefik's `traefik-lb` LoadBalancer service:

```console
microk8s.kubectl -n sdcore get svc | grep "traefik-lb"
```

The output should look similar to below:

```console
ubuntu@host:~/terraform$ microk8s.kubectl -n private5g get svc | grep "traefik-lb"
traefik-lb                           LoadBalancer   10.152.183.142   10.0.0.4      80:32435/TCP,443:32483/TCP    11m
```

In this tutorial, the IP is `10.0.0.4`. Please note it, as we will need it in the next step.

Configure Traefik to use an external hostname. To do that, edit `traefik_config`
in the `main.tf` file:

```
:caption: main.tf
(...)
module "sdcore" {
  (...)
  traefik_config = {
    routing_mode      = "subdomain"
    external_hostname = "10.0.0.4.nip.io"
  }
  (...)
}
(...)
```

Apply new configuration:

```console
terraform apply -auto-approve
```

Resolve Traefik error in Juju:

```console
juju resolve traefik/0
```

## 7. Configure the 5G core network through the Network Management System

Retrieve the NMS address:

```console
juju run traefik/0 show-proxied-endpoints
```

The output should be `http://sdcore-nms.10.0.0.4.nip.io/`. Navigate to this address in your
browser.

In the Network Management System (NMS), create a network slice with the following attributes:

- Name: `default`
- MCC: `001`
- MNC: `01`
- UPF: `upf-external.sdcore.svc.cluster.local:8805`
- gNodeB: `sdcore-gnbsim-gnbsim`

You should see the following network slice created:

```{image} ../images/nms_network_slice.png
:alt: NMS Network Slice
:align: center
```

Create a subscriber with the following attributes:
- IMSI: `001010100007487`
- OPC: `981d464c7c52eb6e5036234984ad0bcf`
- Key: `5122250214c33e723a5dd523fc145fc0`
- Sequence Number: `16f3b3f70fc2`
- Network Slice: `default`
- Device Group: `default-default`

You should see the following subscriber created:

```{image} ../images/nms_subscriber.png
:alt: NMS Subscriber
:align: center
```

## 8. Run the 5G simulation

Run the simulation:

```console
juju run gnbsim/leader start-simulation
```

The simulation executed successfully if you see `success: "true"` as one of the output messages:

```console
ubuntu@host:~$ juju run gnbsim/leader start-simulation
Running operation 1 with 1 task
  - task 2 on unit-gnbsim-0

Waiting for task 2...
info: run juju debug-log to get more information.
success: "true"
```

## 9. Destroy the environment

Destroy Terraform deployment:

```console
terraform destroy -auto-approve
```

```{note}
Terraform does not remove anything from the working directory. If needed, please clean up
the `terraform` directory manually by removing everything except for the `main.tf`
and `terraform.tf` files.
```

Destroy the Juju controller and all its models:

```console
juju kill-controller microk8s-localhost
```
