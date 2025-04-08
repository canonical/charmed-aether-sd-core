# Hardening

## Infrastructure and Network Hardening

### Operating System Security

To ensure the security of operating systems in the deployment infrastructure (whether Virtual Machines or bare-metal servers), apply the following steps:

1. Automate OS security patches:
    - Enable automatic security updates to protect against newly discovered vulnerabilities.
    - Tools for automatic updates such as `unattended-upgrades`.
    
2. Enable Secure Boot to ensure the system boots only trusted software, protecting against unauthorized code during startup.

3. Disable Unused Modules and Network Services. Identify and disable OS kernel modules and network services that are not required for application functionality, reducing the system’s attack surface.

### Firewall Rules

Enforcing the firewall rules minimizes the attack surface while preserving the functionality required for operations.

To enhance the security of the deployment infrastructure, firewalls are configured with the following rules:

2. Allow only inbound traffic targeting the required ports for the 5G Core and the outgoing traffic required for communication with trusted endpoints.
3. Allow Only Essential Protocols based on the 5G Core. Those are the required protocols:
    - SCTP: For N2 interface communication (used by AMF).
    - UDP: For PFCP (SMF <-> UPF) or GTP-U (UPF <-> RAN).
    - TCP: For HTTP/HTTPS services like NRF or API communications.
    - DNS/TLS: For Core service discovery and communication.

All other protocols like FTP, Telnet, or legacy application protocols should be dropped unless explicitly needed.

2. Protect Public Endpoints and Network Management System:
    - Restrict access using IP whitelisting to allow only trusted IP ranges.
    - Optionally, implement a VPN or private network to access management systems for additional security.

## Hardening Containerized Applications

### Enforce Pod Security
Kubernetes offers Pod Security Standards (PSS) as a replacement for the deprecated Pod Security Policies (PSP). 
MicroK8s uses the built-in Pod Security Admission controller to enforce these standards.
1. Set Namespace-Level Pod Security Standards (PSS):

Apply `restricted`, `baseline`, or `privileged` profiles at the namespace level:

```bash
kubectl label namespace <namespace> pod-security.kubernetes.io/enforce=restricted
```

### Secrets Management

Kubernetes secrets allow to store sensitive configuration securely.
1. Enable Secrets Encryption:

Encrypt secrets at rest in etcd by enabling the `secrets` add-on within MicroK8s:
```bash
microk8s enable secrets
```

## Operational Hardening

### Monitoring and Alerts

Monitoring and alerting are crucial for ensuring the secure and reliable operation of a 5G Core integrated with the Canonical Observability Stack (COS).

The COS Stack offers a comprehensive set of observability tools such as Prometheus, Loki, Alertmanager, and Grafana to continuously monitor system performance, detect anomalies, and respond to potential security or operational issues.

Loki centralizes log data, allowing operators to correlate logs from multiple 5G Core services to quickly identify the root cause of errors, unusual activity, or potential security breaches.

Notifications for critical incidents, such as resource exhaustion, node failures, or service disruptions, are managed and delivered through Alertmanager which is part of Prometheus. 

All of these observability features are accessible through Grafana, which provides customizable dashboards with actionable insights into the real-time health of the system.

By integrating COS with Charmed Aether SD-Core, operators can establish a secure and resilient operational environment, proactively address issues, and ensure uninterrupted connectivity for end-users. 

Please follow [this guide](https://canonical-charmed-aether-sd-core.readthedocs-hosted.com/en/v1.5/how-to/integrate_sdcore_with_observability/) to integrate with Cos stack.

