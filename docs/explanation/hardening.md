# Hardening

## Infrastructure Hardening

1. Deploy the Charmed Aether SD-Core behind a firewall:
   - Allow only inbound traffic to required ports for the 5G Core.
   - Enable only outgoing traffic necessary for communication with trusted endpoints like RAN and DN.

2. Restrict protocols to 5G Core essentials:
   a. Allow:
      - SCTP: For N2 interface communication (AMF).
      - UDP: For PFCP (SMF <-> UPF) and GTP-U (UPF <-> RAN).
      - TCP: For HTTP/HTTPS services like NRF or API communication.
      - DNS/TLS: For discovery and secure communication.

   b. Block other protocols including ICMP, FTP, Telnet, or legacy application protocols unless absolutely necessary.

3. Protect public endpoints and management systems:
   - Use IP whitelisting to allow only trusted IP ranges.
   - Place the Charmed Aether SD-Core network behind a VPN or private network for additional security.

## Hardening Containerized Applications

1. Enforce Pod Security:
   - Use the Kubernetes Pod Security Admission controller.
   - Apply the `restricted` profile to namespaces with the following command:

```bash
kubectl label namespace <namespace> pod-security.kubernetes.io/enforce=restricted
```

## Operational Hardening

1. Integrate with the Canonical Observability Stack:
   - Set up monitoring and alerts by integrating with the Canonical Observability Stack (COS).
   - Refer to the [integration guide](https://canonical-charmed-aether-sd-core.readthedocs-hosted.com/en/latest/how-to/integrate_sdcore_with_observability) for steps.

