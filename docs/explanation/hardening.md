# Hardening

## Infrastructure Hardening

### Firewall Rules

Enforcing the firewall rules minimizes the attack surface while preserving the functionality required for operations. To enhance the security of the deployment infrastructure, firewalls can be configured with the following rules:

1. Allow only inbound traffic targeting the required ports for the 5G Core and the outgoing traffic required for communication with trusted endpoints such as RAN and DN.
2. Allow only essential protocols based on the 5G Core as follows:
    - SCTP: For N2 interface communication (used by AMF).
    - UDP: For PFCP (SMF <-> UPF) or GTP-U (UPF <-> RAN).
    - TCP: For HTTP/HTTPS services like NRF or API communications.
    - DNS/TLS: For Core service discovery and communication.

   All other protocols like ICMP, FTP, Telnet, or legacy application protocols should be dropped unless explicitly needed.

3. Protect public endpoints and Network Management System (NMS):
    - Restrict access using IP whitelisting to allow only trusted IP ranges.
    - Optionally, deploy the core system behind a VPN or private network to enhance security for management systems.

## Hardening Containerized Applications

### Enforce Pod Security

To align with Kubernetes security best practices, MicroK8s leverages the Pod Security Admission controller. When setting up namespaces, we recommend applying the `restricted` profile, which enforces the highest security standards required for production workloads.

To apply the `restricted` profile at the namespace level, use the following command:

```bash
kubectl label namespace <namespace> pod-security.kubernetes.io/enforce=restricted
```

## Operational Hardening

### Monitoring and Alerts

Monitoring and alerting are essential for maintaining the secure and reliable operation of Charmed Aether SD-Core. By integrating COS with Charmed Aether SD-Core, operators can proactively address issues, maintain system resilience and ensure uninterrupted connectivity for end-users. For detailed steps, please follow [this guide](https://canonical-charmed-aether-sd-core.readthedocs-hosted.com/en/latest/how-to/integrate_sdcore_with_observability).


