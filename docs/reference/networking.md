# Networking

## Network Architecture

SD-Core requires the following IP networks:
- **Management:** Network used by Juju and Kubernetes to communicate with the SD-Core components.
- **Core:** Network used by the UPF to communicate with the SMF.
- **Access:** Network used by the UPF to communicate with the RAN.
- **RAN:** Network used by the radio components to communicate with the core network.

```{image} ../images/sdcore_networking.png
:alt: SD-Core Network Architecture
:height: 500px
:align: center
```

## Connectivity between Control Plane and User Plane

The following table describes connectivity requirements between the Control Plane and the User Plane.

| Protocol | Source Module | Source Port | Destination Module | Destination Port | 
|----------|---------------|-------------|--------------------|------------------|
| UDP      | SMF           | 8805        | UPF                | 8805             |
