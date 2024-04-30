# Public Clouds

Charmed Aether SD-Core is deployable on Kubernetes platforms. MicroK8s is the preferred Kubernetes distribution for SD-Core, and has been tested extensively.

Even though SD-Core can be deployed on managed Kubernetes services offered on public cloud platforms (Microsoft AKS, Amazon EKS,and Google GKE), these platforms do not support SCTP traffic on their load balancers, yet SCTP is essential for the traffic between AMF and gNBs. However, on AWS, it is possible to deploy a VM, install microK8s, and expose an SCTP load balancer, which then allows for SCTP connection to an external gNB.

