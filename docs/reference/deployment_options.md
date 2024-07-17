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

[sdcore-k8s-terraform]: https://github.com/canonical/terraform-juju-sdcore/tree/v1.4/modules/sdcore-k8s
[sdcore-control-plane-k8s]: https://github.com/canonical/terraform-juju-sdcore/tree/v1.4/modules/sdcore-control-plane-k8s
[sdcore-user-plane-k8s]: https://github.com/canonical/terraform-juju-sdcore/tree/v1.4/modules/sdcore-user-plane-k8s
