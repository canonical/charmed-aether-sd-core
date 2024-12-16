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
sudo snap install microk8s --channel=1.31-strict/stable
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
sudo snap install juju --channel=3.6/stable
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

## 4. Deploy Charmed Aether SD-Core

On the host machine create a new directory called `terraform`:

```console
mkdir terraform
```

Inside newly created `terraform` directory create a `terraform.tf` file:

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

Create a Terraform module containing the SD-Core 5G core network and a router:

```console
cat << EOF > core.tf
resource "juju_model" "sdcore" {
  name = "sdcore"
}

module "sdcore-router" {
  source = "git::https://github.com/canonical/sdcore-router-k8s-operator//terraform"

  model      = juju_model.sdcore.name
  depends_on = [juju_model.sdcore]
}

module "sdcore" {
  source = "git::https://github.com/canonical/terraform-juju-sdcore//modules/sdcore-k8s"

  model        = juju_model.sdcore.name
  depends_on = [module.sdcore-router]
  
  traefik_config = {
    routing_mode = "subdomain"
  }
}

EOF
```

```{note}
You can get a ready example by cloning [this Git repository](https://github.com/canonical/charmed-aether-sd-core).
All necessary files are in the `examples/terraform/getting_started` directory.
```

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
Model   Controller          Cloud/Region        Version  SLA          Timestamp
sdcore  microk8s-localhost  microk8s/localhost  3.6.0    unsupported  11:06:36-05:00

App                       Version  Status   Scale  Charm                     Channel        Rev  Address         Exposed  Message
amf                       1.6.1    active       1  sdcore-amf-k8s            1.6/edge       862  10.152.183.173  no       
ausf                      1.5.1    active       1  sdcore-ausf-k8s           1.6/edge       672  10.152.183.247  no       
grafana-agent             0.40.4   waiting      1  grafana-agent-k8s         latest/stable   80  10.152.183.204  no       installing agent
mongodb                            active       1  mongodb-k8s               6/stable        61  10.152.183.96   no       
nms                       1.1.0    active       1  sdcore-nms-k8s            1.6/edge       790  10.152.183.84   no       
nrf                       1.6.1    active       1  sdcore-nrf-k8s            1.6/edge       747  10.152.183.132  no       
nssf                      1.5.1    active       1  sdcore-nssf-k8s           1.6/edge       628  10.152.183.91   no       
pcf                       1.5.2    active       1  sdcore-pcf-k8s            1.6/edge       669  10.152.183.129  no       
router                             active       1  sdcore-router-k8s         1.6/edge       436  10.152.183.203  no       
self-signed-certificates           active       1  self-signed-certificates  latest/stable  155  10.152.183.219  no       
smf                       1.6.2    active       1  sdcore-smf-k8s            1.6/edge       764  10.152.183.220  no       
traefik                   2.11.0   waiting      1  traefik-k8s               latest/stable  203  10.152.183.27   no       installing agent
udm                       1.5.1    active       1  sdcore-udm-k8s            1.6/edge       625  10.152.183.228  no       
udr                       1.6.1    active       1  sdcore-udr-k8s            1.6/edge       612  10.152.183.141  no       
upf                       1.4.0    active       1  sdcore-upf-k8s            1.6/edge       678  10.152.183.229  no       

Unit                         Workload  Agent  Address       Ports  Message
amf/0*                       active    idle   10.1.194.236         
ausf/0*                      active    idle   10.1.194.243         
grafana-agent/0*             blocked   idle   10.1.194.196         Missing ['grafana-cloud-config']|['logging-consumer'] for logging-provider; ['grafana-cloud-config']|['send-remote-wr...
mongodb/0*                   active    idle   10.1.194.249         
nms/0*                       active    idle   10.1.194.203         
nrf/0*                       active    idle   10.1.194.247         
nssf/0*                      active    idle   10.1.194.227         
pcf/0*                       active    idle   10.1.194.224         
router/0*                    active    idle   10.1.194.245         
self-signed-certificates/0*  active    idle   10.1.194.225         
smf/0*                       active    idle   10.1.194.255         
traefik/0*                   error     idle   10.1.194.246         hook failed: "ingress-relation-created"
udm/0*                       active    idle   10.1.194.219         
udr/0*                       active    idle   10.1.194.211         
upf/0*                       active    idle   10.1.194.217         

Offer  Application  Charm           Rev  Connected  Endpoint        Interface       Role
amf    amf          sdcore-amf-k8s  862  0/0        fiveg-n2        fiveg_n2        provider
nms    nms          sdcore-nms-k8s  790  0/0        fiveg_core_gnb  fiveg_core_gnb  provider
upf    upf          sdcore-upf-k8s  678  0/0        fiveg_n3        fiveg_n3        provider
```

## 5. Configure the ingress

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
in the `core.tf` file:

```
:caption: core.tf
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

## 6. Deploy the gNodeB and a cellphone simulator

Inside the `terraform` directory create a new module:

```console
cat << EOF > ran.tf
resource "juju_model" "ran-simulator" {
  name = "ran"
}

module "gnbsim" {
  source = "git::https://github.com/canonical/sdcore-gnbsim-k8s-operator//terraform"

  model      = juju_model.ran-simulator.name
  depends_on = [module.sdcore-router]
}

resource "juju_integration" "gnbsim-amf" {
  model = juju_model.ran-simulator.name

  application {
    name     = module.gnbsim.app_name
    endpoint = module.gnbsim.requires.fiveg_n2
  }

  application {
    offer_url = module.sdcore.amf_fiveg_n2_offer_url
  }
}

resource "juju_integration" "gnbsim-nms" {
  model = juju_model.ran-simulator.name

  application {
    name     = module.gnbsim.app_name
    endpoint = module.gnbsim.requires.fiveg_core_gnb
  }

  application {
    offer_url = module.sdcore.nms_fiveg_core_gnb_offer_url
  }
}

EOF
```

Initialize Juju Terraform provider:

```console
terraform init
```

Apply new configuration:

```console
terraform apply -auto-approve
```

Monitor the status of the deployment:

```console
juju switch ran
watch -n 1 -c juju status --color --relations
```

The deployment is ready when the `gnbsim` application is in the `Waiting/Idle` state and the message is `Waiting for TAC and PLMNs configuration`.<br>

Example:

```console
ubuntu@host:~/terraform $ juju status
Model  Controller          Cloud/Region        Version  SLA          Timestamp
ran    microk8s-localhost  microk8s/localhost  3.6.0    unsupported  12:18:26+02:00

SAAS  Status  Store  URL
amf   active  local  admin/sdcore.amf
nms   active  local  admin/sdcore.nms

App     Version  Status   Scale  Charm              Channel   Rev  Address        Exposed  Message
gnbsim  1.4.5    waiting      1  sdcore-gnbsim-k8s  1.6/edge  638  10.152.183.85  no       installing agent

Unit       Workload  Agent  Address       Ports  Message
gnbsim/0*  waiting   idle   10.1.194.239         Waiting for TAC and PLMNs configuration
```

## 7. Configure the 5G core network through the Network Management System

Retrieve the NMS credentials (`username` and `password`):

```console
juju switch sdcore
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

The output should be `https://sdcore-nms.10.0.0.4.nip.io/`. Navigate to this address in your
browser and use the `username` and `password` to login.

In the Network Management System (NMS), create a network slice with the following attributes:

- Name: `default`
- MCC: `001`
- MNC: `01`
- UPF: `upf-external.sdcore.svc.cluster.local:8805`
- gNodeB: `ran-gnbsim-gnbsim`

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

Switch to the `ran` model and make sure that the `gnbsim` application is in `Active/Idle` state.

```console
juju switch ran
juju status
```

The output should be similar to below:

Example:

```console
ubuntu@host:~/terraform $ juju status
Model  Controller          Cloud/Region        Version  SLA          Timestamp
ran    microk8s-localhost  microk8s/localhost  3.6.0    unsupported  12:18:26+02:00

SAAS  Status  Store  URL
amf   active  local  admin/sdcore.amf
nms   active  local  admin/sdcore.nms

App     Version  Status  Scale  Charm              Channel   Rev  Address        Exposed  Message
gnbsim  1.4.5    active      1  sdcore-gnbsim-k8s  1.6/edge  638  10.152.183.85  no       

Unit       Workload  Agent  Address       Ports  Message
gnbsim/0*  active    idle   10.1.194.239
```

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
info: 5/5 profiles passed
success: "true"
```

## 9. Destroy the environment

Destroy Terraform deployment:

```console
terraform destroy -auto-approve
```

```{note}
Terraform does not remove anything from the working directory. If needed, please clean up
the `terraform` directory manually by removing everything except for the `core.tf`
and `terraform.tf` files.
```

Destroy the Juju controller and all its models:

```console
juju kill-controller microk8s-localhost
```
