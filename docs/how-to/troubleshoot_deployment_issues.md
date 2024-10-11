# Troubleshoot deployment issues

This guide provides step-by-step troubleshooting actions to remediate deployment issues. We hope you don't need this guide. If you encounter an issue and aren't able to address it via this guide, please raise an issue [here][Bug Report].

## 1. Terraform failed to deploy the Charmed Aether SD-Core with `Unable to create model` error

### Symptoms

The `terraform apply -auto-approve` command fails with an error indicating that the Juju model could not be created:

```console
Plan: 72 to add, 0 to change, 0 to destroy.
juju_model.private5g: Creating...
│ Error: Client Error
│   with juju_model.private5g,
│   on main.tf line 1, in resource "juju_model" "private5g":
│    1: resource "juju_model" "private5g" {
│ Unable to create model, got error: failed to open kubernetes client: annotations map[controller.juju.is/id:ced7016b-3a63-4133-8988-cf33068c3cdf
│ model.juju.is/id:2abfe7ab-9e40-4e0d-8158-53450c47b2db] for namespace "private5g" not valid must include map[controller.juju.is/id:ced7016b-3a63-4133-8988-cf33068c3cdf
│ model.juju.is/id:9755936b-8084-4397-8a67-28773b361dfa] (not valid)
```

### Recommended Actions

Validate whether a Juju model already exists with the same name:

```shell
$ juju models
controller: microk8s-localhost

Model       Cloud/Region        Type        Status      Units  Access  Last connection
controller  microk8s/localhost  kubernetes  available   1       admin  just now
private5g*  microk8s/localhost  kubernetes  destroying  -       admin  6 minutes ago
sdcore      microk8s/localhost  kubernetes  available   19      admin  2024-10-04
```

Choose a model name that does not exist in the Juju controller. Read [this guide][Configure SD-Core K8s Deployment] for more information.

## 2. Terraform failed to deploy Charmed Aether SD-Core with `Connection error, please check the controller_addresses property set on the provider` error

### Symptoms

The `terraform apply -auto-approve` command fails with an error indicating that the Juju controller couldn't be connected to:

```console
$ terraform apply --auto-approve
│ Error: Invalid provider configuration
│ Provider "registry.terraform.io/juju/juju" requires explicit configuration. Add a provider block to the root module and configure the provider's required arguments as described in
│ the provider documentation.
│ Error: dial tcp 10.152.183.251:17070: i/o timeout
│   with provider["registry.terraform.io/juju/juju"],
│   on <empty> line 0:
│   (source code not available)
│ Connection error, please check the controller_addresses property set on the provider
```

### Recommended Actions

Validate that the Juju controller is running.

First, list the available Juju controllers:

```shell
$ juju controllers
Use --refresh option with this command to see the latest information.

Controller           Model      User   Access     Cloud/Region        Models  Nodes  HA  Version
microk8s-localhost*  private5g  admin  superuser  microk8s/localhost       9      -   -  3.4.5  
```

If your controller does not show up in the list, please follow [this guide][Bootstrap a Juju Controller] to create a Juju controller.

If the controller is listed, get your controller's `api-endpoints` address.

```shell
$ juju show-controller <your-controller-name>
microk8s-localhost:
  details:
    controller-uuid: ced7016b-3a63-4133-8988-cf33068c3cdf
    api-endpoints: ['10.152.183.251:17070']
    cloud: microk8s
    region: localhost
    agent-version: 3.4.5
```

Perform a healthcheck using your Juju controller's `api-endpoints` address which is `10.152.183.251:17070` in this guide:

```shell
$ curl -ik https://<api-endpoints>/health
HTTP/1.1 200 OK
Date: Thu, 10 Oct 2024 12:39:00 GMT
Content-Length: 8
Content-Type: text/plain; charset=utf-8

running
```

If the healthcheck returns `running` check the firewall rules in your environment. Otherwise, access to the controller `api-server` container and check the logs:

```shell
$ microk8s.kubectl exec -it  controller-0 -n <your-controller-namespace> -c api-server -- bash
juju@controller-0:/var/lib/juju$ ls /var/log/
alternatives.log  apt  bootstrap.log  btmp  dpkg.log  faillog  juju  lastlog  wtmp
```

```{note}
Your controller namespace will be in the format of `controller-<your-controller-name>`.
```

If the logs do not help to fix the issue, remove your controller and create a new accessible Juju controller using [this guide][Manage Juju Controller].

[Bug Report]: https://github.com/canonical/charmed-aether-sd-core/issues/new?assignees=&labels=bug&projects=&template=bug_report.yml
[Configure SD-Core K8s Deployment]: https://canonical-charmed-aether-sd-core.readthedocs-hosted.com/en/latest/how-to/deploy_sdcore_standalone/#deploy
[Manage Juju Controller]: https://juju.is/docs/juju/manage-controllers
[Bootstrap a Juju Controller]: https://canonical-charmed-aether-sd-core.readthedocs-hosted.com/en/latest/tutorials/getting_started/#bootstrap-a-juju-controller