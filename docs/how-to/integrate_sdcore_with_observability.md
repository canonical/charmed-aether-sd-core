# Integrate SD-Core with Canonical Observability Stack

[Charmed Aether SD-Core Terraform modules][Charmed Aether SD-Core Terraform modules] come with built-in support for the Canonical Observability Stack (COS).
By default, COS deployment and integration is disabled.
This guide covers two ways of integrating SD-Core with COS:
1. [Integrating SD-Core with COS at the deployment stage](#option-1)
2. [Integrating COS with an existing SD-Core deployment](#option-2)

(option-1)=
## Integrating SD-Core with COS at the deployment stage

This option allows deploying COS and integrating it with SD-Core as a Day 1 operation. 

### Pre-requisites

- A Kubernetes cluster capable of handling the load from both SD-Core and COS
- [Charmed Aether SD-Core Terraform modules][Charmed Aether SD-Core Terraform modules] Git repository cloned onto the Juju host machine

### Including COS integration in the SD-Core deployment

Inside the directory of a desired SD-Core Terraform module, create `variables.tfvars` file and add following line(s) to it:

```console
deploy_cos = true
cos_model_name = "YOUR_CUSTOM_COS_MODEL_NAME" (Optional. Defaults to `cos-lite`.)
cos_configuration_config = {} (Optional. Allows customization of the `COS Configuration` application.)
```

```{note}
If you have already created the `.tfvars` file, to customize the deployment of SD-Core, you should edit the existing file rather than create a new one.
```

Proceed with the deployment.

(option-2)=
## Integrating COS with an existing SD-Core deployment

This option allows deploying COS and integrating it with SD-Core as a Day 2 operation.

### Pre-requisites

- A Kubernetes cluster capable of handling the load from both SD-Core and COS
- Any [Charmed Aether SD-Core Terraform module][Charmed Aether SD-Core Terraform modules] deployed

### Adding COS to an existing SD-Core deployment

Go to a directory from which SD-Core was deployed (the one containing Terraform's `.tfstate` file).
Edit the `.tfvars` and add following line(s) to it:

```console
deploy_cos = true
cos_model_name = "<YOUR_CUSTOM_COS_MODEL_NAME>" (Optional. Defaults to `cos-lite`.)
cos_configuration_config = {} (Optional. Allows customization of the `COS Configuration` application.)
```

Apply the changes:

```console
terraform apply -var-file="<YOUR_TFVARS_FILE>" -auto-approve
```

Monitor the status of the deployment:

```console
juju switch <YOUR_CUSTOM_COS_MODEL_NAME>
watch -n 1 -c juju status --color --relations
```

The deployment is ready when all the charms are in the `Active/Idle` state.

## Accessing the 5G Network Overview Grafana dashboard

Retrieve the Grafana URL and admin password:

```console
juju switch cos-lite
juju run grafana/leader get-admin-password
```

You should see the output similar to the following:

```console
Running operation 1 with 1 task
  - task 2 on unit-grafana-0

Waiting for task 2...
admin-password: c72uEq8FyGRo
url: http://10.201.0.51/cos-lite-grafana
```

```{note}
Grafana can be accessed using both `http` (as returned by the command above) or `https`.
```

In your browser, navigate to the URL from the output (`https://10.201.0.51/cos-grafana`).
Login using the "admin" username and the admin password provided in the last command.
Click on "Dashboards" -> "Browse" and select "5G Network Overview".

```{image} ../images/grafana_5g_dashboard_sim_after.png
:alt: Grafana dashboard
:align: center
```

[Charmed Aether SD-Core Terraform modules]: https://github.com/canonical/terraform-juju-sdcore/tree/v1.4
