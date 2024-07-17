# Getting started

In this tutorial, we will deploy and run the SD-Core 5G core network using Juju and Terraform.
As part of this tutorial, we will also deploy additional components (gNB Simulator - a 5G radio
and a cellphone simulator, SD-Core Router - a software router facilitating communication between
the core and the Radio Access Network (RAN)) to simulate usage of this network. Both gNB Simulator
and SD-Core Router serve only demonstration purposes and shouldn't be part of production
deployments.

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
      version = ">= 0.11.0"
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
  source = "git::https://github.com/canonical/sdcore-router-k8s-operator//terraform?ref=v1.4"
  channel = "1.4/beta"

  model_name = juju_model.sdcore.name
  depends_on = [juju_model.sdcore]
}

module "sdcore" {
  source = "git::https://github.com/canonical/terraform-juju-sdcore//modules/sdcore-k8s?ref=v1.4"

  model_name = juju_model.sdcore.name
  create_model = false

  traefik_config = {
    routing_mode = "subdomain"
  }

  depends_on = [module.sdcore-router]
}

module "gnbsim" {
  source = "git::https://github.com/canonical/sdcore-gnbsim-k8s-operator//terraform?ref=v1.4"
  channel = "1.4/beta"

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
You can get a ready example by cloning [this Git repository](https://github.com/canonical/charmed-aether-sd-core) and switching to the `v1.4` branch.
All necessary files are in the `examples/terraform/getting_started` directory.
```

## 5. Deploy SD-Core

Initialize Juju Terraform provider:

```console
terraform init
```

Deploy 5G network.

```console
terraform apply -auto-approve
```

The deployment process should take approximately 15-20 minutes.

Monitor the status of the deployment:

```console
juju switch sdcore
watch -n 1 -c juju status --color --relations
```

The deployment is ready when all the charms are in the `Active/Idle` state. It is normal
for `grafana-agent` to remain in waiting state. Example:

```console
ubuntu@host:~$ juju status
Model   Controller          Cloud/Region        Version  SLA          Timestamp
sdcore  microk8s-localhost  microk8s/localhost  3.4.2    unsupported  10:15:12+02:00

App                       Version  Status   Scale  Charm                     Channel        Rev  Address         Exposed  Message
amf                                active       1  sdcore-amf-k8s            1.4/beta       160  10.152.183.64   no       
ausf                               active       1  sdcore-ausf-k8s           1.4/beta       139  10.152.183.140  no       
gnbsim                             active       1  sdcore-gnbsim-k8s         1.4/beta       108  10.152.183.197  no       
grafana-agent             0.35.2   waiting      1  grafana-agent-k8s         latest/stable   64  10.152.183.105  no       installing agent
mongodb                            active       1  mongodb-k8s               6/beta          38  10.152.183.55   no       Primary
nms                                active       1  sdcore-nms-k8s            1.4/beta       127  10.152.183.220  no       
nrf                                active       1  sdcore-nrf-k8s            1.4/beta       142  10.152.183.226  no       
nssf                               active       1  sdcore-nssf-k8s           1.4/beta       116  10.152.183.222  no       
pcf                                active       1  sdcore-pcf-k8s            1.4/beta       120  10.152.183.94   no       
router                             active       1  sdcore-router-k8s         1.4/beta       109  10.152.183.203  no       
self-signed-certificates           active       1  self-signed-certificates  latest/stable   72  10.152.183.210  no       
smf                                active       1  sdcore-smf-k8s            1.4/beta       134  10.152.183.125  no       
traefik                   v2.11.0  active       1  traefik-k8s               latest/stable  176  10.0.0.3        no       
udm                                active       1  sdcore-udm-k8s            1.4/beta       104  10.152.183.111  no       
udr                                active       1  sdcore-udr-k8s            1.4/beta       114  10.152.183.162  no       
upf                                active       1  sdcore-upf-k8s            1.4/beta       161  10.152.183.254  no       
webui                              active       1  sdcore-webui-k8s          1.4/beta        86  10.152.183.53   no

Unit                         Workload  Agent  Address      Ports  Message
amf/0*                       active    idle   10.1.182.23
ausf/0*                      active    idle   10.1.182.18
gnbsim/0*                    active    idle   10.1.182.50
grafana-agent/0*             blocked   idle   10.1.182.51         logging-consumer: off, grafana-cloud-config: off
mongodb/0*                   active    idle   10.1.182.35         Primary
nms/0*                       active    idle   10.1.182.2
nrf/0*                       active    idle   10.1.182.53
nssf/0*                      active    idle   10.1.182.48
pcf/0*                       active    idle   10.1.182.46
router/0*                    active    idle   10.1.182.57
self-signed-certificates/0*  active    idle   10.1.182.56
smf/0*                       active    idle   10.1.182.27
traefik/0*                   active    idle   10.1.182.40
udm/0*                       active    idle   10.1.182.52
udr/0*                       active    idle   10.1.182.39
upf/0*                       active    idle   10.1.182.60
webui/0*                     active    idle   10.1.182.33
```

## 6. Configure the ingress

Get the IP address of the Traefik application:

```console
juju status traefik
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

Retrieve the NMS address:

```console
juju run traefik/0 show-proxied-endpoints
```

The output should be `https://sdcore-nms.10.0.0.4.nip.io/`. Navigate to this address in your
browser.


## 7. Configure the 5G core network through the Network Management System

In the Network Management System (NMS), create a network slice with the following attributes:

- Name: `default`
- MCC: `208`
- MNC: `93`
- UPF: `upf-external.sdcore.svc.cluster.local:8805`
- gNodeB: `sdcore-gnbsim-gnbsim`

You should see the following network slice created:

```{image} ../images/nms_network_slice.png
:alt: NMS Network Slice
:align: center
```

Create a subscriber with the following attributes:
- IMSI: `208930100007487`
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
