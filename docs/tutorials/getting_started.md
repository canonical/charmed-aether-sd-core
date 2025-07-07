# Getting started

In this tutorial, we will deploy and run an SD-Core 5G core network using Juju and Terraform.
As part of this tutorial, we will also deploy a gNB Simulator which is a 5G radio and a cellphone simulator.

The gNB Simulator serves only demonstration purposes and shouldn't be part of production deployments.

To complete this tutorial, you will need a machine which meets the following requirements:

- A recent `x86_64` CPU (Intel 4ᵗʰ generation or newer, or AMD Ryzen or newer)
- At least 4 cores
- 8GB of RAM
- 50GB of free disk space

## 1. Install Canonical K8s

From your terminal, install Canonical K8s and bootstrap it:

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

Add the Multus plugin.

```console
sudo k8s kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml
```

We must give MetalLB an address range that has at least 3 IP addresses for Charmed Aether SD-Core.

```console
sudo k8s set load-balancer.cidrs="10.0.0.2-10.0.0.4"
```

## 2. Bootstrap a Juju controller

From your terminal, install Juju.

```console
sudo snap install juju --channel=3.6/stable
```

Save the K8s credentials to allow bootstrapping Juju controller.

```console
mkdir -p ~/.kube
sudo k8s config > ~/.kube/config
mkdir -p ~/.local/share/juju/
sudo k8s config > ~/.local/share/juju/credentials.yaml
```

Bootstrap a Juju controller

```console
juju bootstrap k8s
```

```{note}
There is a [bug](https://bugs.launchpad.net/juju/+bug/1988355) in Juju that occurs when
bootstrapping a controller on a new machine. If you encounter it, create the following
directory:
`mkdir -p ~/.local/share`
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

Inside newly created `terraform` directory create a `versions.tf` file:

```console
cd terraform
cat << EOF > versions.tf
terraform {
  required_providers {
    juju = {
      source  = "juju/juju"
      version = ">= 0.20.0"
    }
  }
}
EOF
```

Create a Terraform module containing the SD-Core 5G core network:

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

  model      = juju_model.sdcore.name
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
juju status --relations --watch 1s
```

The deployment is ready when all the charms are in the `active/idle` state.<br>
It is normal for `grafana-agent` and `traefik` to be in `blocked` state.<br>

Example:

```console
ubuntu@host:~/terraform $ juju status
Model   Controller  Cloud/Region  Version  SLA          Timestamp
sdcore  k8s         k8s           3.6.6    unsupported  11:35:07+02:00

App                       Version  Status   Scale  Charm                     Channel        Rev  Address         Exposed  Message
amf                       1.6.4    active       1  sdcore-amf-k8s            1.6/edge       908  10.152.183.217  no       
ausf                      1.6.2    active       1  sdcore-ausf-k8s           1.6/edge       713  10.152.183.19   no       
grafana-agent             0.40.4   blocked      1  grafana-agent-k8s         1/stable       111  10.152.183.102  no       Missing ['grafana-cloud-config']|['logging-consumer'] for logging-provider; ['grafana-cloud-config']|['send-remote-wr...
mongodb                            active       1  mongodb-k8s               6/stable        61  10.152.183.18   no       
nms                       1.1.0    active       1  sdcore-nms-k8s            1.6/edge       849  10.152.183.42   no       
nrf                       1.6.2    active       1  sdcore-nrf-k8s            1.6/edge       790  10.152.183.234  no       
nssf                      1.6.1    active       1  sdcore-nssf-k8s           1.6/edge       669  10.152.183.40   no       
pcf                       1.6.1    active       1  sdcore-pcf-k8s            1.6/edge       710  10.152.183.129  no           
self-signed-certificates           active       1  self-signed-certificates  1/stable       263  10.152.183.71   no       
smf                       2.0.2    active       1  sdcore-smf-k8s            1.6/edge       801  10.152.183.81   no       
traefik                   2.11.0   blocked      1  traefik-k8s               latest/stable  234  10.152.183.244  no       "external_hostname" must be set while using routing mode "subdomain"
udm                       1.6.1    active       1  sdcore-udm-k8s            1.6/edge       664  10.152.183.241  no       
udr                       1.6.2    active       1  sdcore-udr-k8s            1.6/edge       645  10.152.183.96   no       
upf                       2.0.1    active       1  sdcore-upf-k8s            1.6/edge       767  10.152.183.173  no       

Unit                         Workload  Agent  Address       Ports  Message
amf/0*                       active    idle   10.1.194.206         
ausf/0*                      active    idle   10.1.194.235         
grafana-agent/0*             blocked   idle   10.1.194.208         Missing ['grafana-cloud-config']|['logging-consumer'] for logging-provider; ['grafana-cloud-config']|['send-remote-wr...
mongodb/0*                   active    idle   10.1.194.237         Primary
nms/0*                       active    idle   10.1.194.255         
nrf/0*                       active    idle   10.1.194.213         
nssf/0*                      active    idle   10.1.194.243         
pcf/0*                       active    idle   10.1.194.250                 
self-signed-certificates/0*  active    idle   10.1.194.239         
smf/0*                       active    idle   10.1.194.202         
traefik/0*                   blocked   idle   10.1.194.230         "external_hostname" must be set while using routing mode "subdomain"
udm/0*                       active    idle   10.1.194.249         
udr/0*                       active    idle   10.1.194.245         
upf/0*                       active    idle   10.1.194.217         

Offer  Application  Charm           Rev  Connected  Endpoint        Interface       Role
amf    amf          sdcore-amf-k8s  908  0/0        fiveg-n2        fiveg_n2        provider
nms    nms          sdcore-nms-k8s  849  0/0        fiveg_core_gnb  fiveg_core_gnb  provider
upf    upf          sdcore-upf-k8s  767  0/0        fiveg_n3        fiveg_n3        provider
```

## 5. Configure the ingress

Get the external IP address of Traefik's `traefik-lb` LoadBalancer service:

```console
sudo k8s kubectl -n sdcore get svc | grep "traefik-lb"
```

The output should look similar to below:

```console
ubuntu@host:~/terraform $ sudo k8s kubectl -n sdcore get svc | grep "traefik-lb"
traefik-lb                           LoadBalancer   10.152.183.83    10.0.0.2      80:30462/TCP,443:30163/TCP    9m4s
```

In this tutorial, the IP is `10.0.0.2`. Please note it, as we will need it in the next step.

Configure Traefik to use an external hostname. To do that, edit `traefik_config` in the `core.tf` file:

```
:caption: core.tf
(...)
module "sdcore" {
  (...)
  traefik_config = {
    routing_mode      = "subdomain"
    external_hostname = "10.0.0.2.nip.io"
  }
  (...)
}
(...)
```

Apply new configuration:

```console
terraform apply -auto-approve
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
juju status --relations --watch 1s
```

The deployment is ready when the `gnbsim` application is in the `Waiting/Idle` state and the message is `Waiting for TAC and PLMNs configuration`.<br>

Example:

```console
ubuntu@host:~/terraform $ juju status
Model Controller  Cloud/Region  Version  SLA          Timestamp
ran   k8s         k8s           3.6.7    unsupported  12:18:26+02:00

SAAS  Status  Store  URL
amf   active  local  admin/sdcore.amf
nms   active  local  admin/sdcore.nms

App     Version  Status   Scale  Charm              Channel   Rev  Address        Exposed  Message
gnbsim  1.6.1    waiting      1  sdcore-gnbsim-k8s  1.6/edge  697  10.152.183.85  no       installing agent

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

Retrieve the NMS address:

```console
juju run traefik/0 show-proxied-endpoints
```

The output should be `https://sdcore-nms.10.0.0.2.nip.io/`. Navigate to this address in your
browser and use the `username` and `password` to login.

### Assign Tracking Area Code (TAC) to the gNodeB

In the Network Management System (NMS) navigate to the `Inventory` tab. Click the `Edit` button next to the integrated gNB name and set `TAC` to `1`:

```{image} ../images/getting_started_gnb_tac.png
:alt: NMS Inventory
:align: center
```

Confirm new `TAC` value by clicking the `Submit` button.

### Create a Network Slice

Navigate to the `Network slices` tab and create a network slice with the following attributes:

- Name: `default`
- MCC: `001`
- MNC: `01`
- UPF: `upf-external.sdcore.svc.cluster.local:8805`
- gNodeB: `ran-gnbsim-gnbsim`

You should see the following network slice created:

```{image} ../images/getting_started_network_slice.png
:alt: NMS Network Slice
:align: center
```

### Create a Device Group

Navigate to the `Device groups` tab and create a device group with the following attributes:

- Name: `device-group`
- Network Slice: `default`
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

```{image} ../images/getting_started_device_group.png
:alt: NMS Device Group
:align: center
```

### Create a Subscriber

Navigate to `Subscribers` tab and click the `Create` button. Fill in the following:

- Network Slice: `default`
- Device Group: `device-group`

Click the two `Generate` buttons to automatically fill in the values in the form. Note the IMSI, OPC, and Key; we are going to use them in the next step.

After clicking the `Submit` button you should see the subscriber created:

```{image} ../images/getting_started_subscriber.png
:alt: NMS Subscriber
:align: center
```

### Set up the subscriber information using Terraform module

To configure gnbsim with the subscriber information, add a config block to the gnbsim module in your `ran.tf` file. 

Replace the placeholders with the values you noted earlier:

```
:caption: ran.tf
module "gnbsim" {
  # ...
  config = {
    imsi      = "<IMSI>"
    usim-opc  = "<OPC>"
    usim-key  = "<Key>"
  }
  # ...
```

Apply the updated configuration:

```console
terraform apply -auto-approve
```

## 8. Run the 5G simulation

Switch to the `ran` model:

```console
juju switch ran
```

Make sure that the `gnbsim` application is in `Active/Idle` state.

```console
juju status
```

The output should be similar to below:

Example:

```console
ubuntu@host:~/terraform $ juju status
Model  Controller  Cloud/Region  Version  SLA          Timestamp
ran    k8s         k8s           3.6.7    unsupported  12:18:26+02:00

SAAS  Status  Store  URL
amf   active  local  admin/sdcore.amf
nms   active  local  admin/sdcore.nms

App     Version  Status  Scale  Charm              Channel   Rev  Address        Exposed  Message
gnbsim  1.6.1    active      1  sdcore-gnbsim-k8s  1.6/edge  697  10.152.183.85  no       

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
the `terraform` directory manually by removing everything except for the `core.tf`, `ran.tf`
and `versions.tf` files.
```

Destroy the Juju controller and all its models:

```console
juju kill-controller k8s
```
