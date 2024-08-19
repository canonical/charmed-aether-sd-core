# SD-Core deployment options

`````{tab-set}
    
````{tab-item} Single site deployment

Use the [sdcore-k8s][sdcore-k8s-terraform] Terraform module to deploy a standalone 5G core network.
This module contains the 5G control plane functions, the UPF, the NMS (Network Management System), 
Grafana Agent, Self Signed Certificates and MongoDB.

```{image} ../images/sdcore_single_site.png
:alt: Single site deployment
:height: 600
:align: center
```

````

````{tab-item} Edge deployment

Use the [sdcore-control-plane-k8s][sdcore-control-plane-k8s] Terraform module to deploy 
the 5G control plane in a central place and the [sdcore-user-plane-k8s][sdcore-user-plane-k8s] 
Terraform module to deploy the 5G user plane in edge sites.

```{image} ../images/sdcore_edge.png
:alt: Edge deployment
:height: 600
:align: center
```

````

`````

## User Plane Function

The User Plane Function (UPF) is available in two different charms:

`````{tab-set}
    
````{tab-item} Kubernetes

The [UPF Kubernetes Charm](https://charmhub.io/sdcore-upf-k8s) can be deployed on a Kubernetes cluster. Network Configuration is done using Multus. Unless the charm is deployed in DPDK mode, the charm will not modify the host network configuration. To deploy the Kubernetes charm, follow this [guide](/how-to/deploy_sdcore_cups/).

````

````{tab-item} Machine

The [UPF Machine charm](https://charmhub.io/sdcore-upf) can be deployed on a bare metal machine or a VM. The UPF machine charm will modify the host network configuration:
- Create network interfaces (DPDK mode only)
- Set interfaces IP addresses
- Modify interfaces MTU
- Set MAC addresses on interfaces (DPDK mode only)
- Bring interfaces up
- Create IP routes
- Create IP tables rules

To deploy the Machine charm, follow this [guide](/how-to/deploy_sdcore_upf_machine/).

````

`````

[sdcore-k8s-terraform]: https://github.com/canonical/terraform-juju-sdcore/tree/main/modules/sdcore-k8s
[sdcore-control-plane-k8s]: https://github.com/canonical/terraform-juju-sdcore/tree/main/modules/sdcore-control-plane-k8s
[sdcore-user-plane-k8s]: https://github.com/canonical/terraform-juju-sdcore/tree/main/modules/sdcore-user-plane-k8s
