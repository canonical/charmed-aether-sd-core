# Production deployment

The currently supported configuration for production deployments consist of a single
physical server running the entire core network. This includes both the control plane
and the user plane, and the observability stack.

All the components of the gNodeB are not covered in this deployment and should be run
externally.

## Minimum Hardware requirements

- 1 physical server
    - 16 cores server CPU, supporting AVX2 and RDRAND and PDPE1GB instructions
    - 64 GB of RAM
    - 1 1Gb NIC
    - 2 10Gb NIC or faster

## Network environment

### Management network

A management network is required to be connected to the 1Gb NIC.

- 1 static IPv4 address configured, with internet access
- 4 static IPv4 addresses in the same subnet reserved, but not configured

### Core network

A network for internet access from the UEs.

- 1 static IPv4 address reserved

### Access network

A network for gNodeBs connectivity.

- 1 static IPv4 address reserved

## Operating system

Ubuntu Server 24.04

## Kubernetes

Canonical Kubernetes 1.33

## Networking diagram

```{image} ../images/single_node_production.svg
:alt: SD-Core Network Diagram
:height: 500px
:align: center
```
