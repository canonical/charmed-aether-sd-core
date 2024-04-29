# Public Clouds

It is not possible to deploy SD-Core on AWS, Microsoft Azure or GCP using their managed Kubernetes services. None of them support the SCTP protocol on load balancers, which prevents the gNodeB from communicating with the AMF.

MicroK8s is the preferred Kubernetes distribution for SD-Core.