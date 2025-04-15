# Hardening

This section explains how to harden Charmed Aether SD-Core by securing infrastructure with firewalls, VPNs, traffic restrictions and IP whitelisting, while enhancing operations through monitoring and alerting with the Canonical Observability Stack (COS).

## Infrastructure Hardening

1. Deploy Charmed Aether SD-Core behind a firewall:

   a. Allow only inbound traffic to required ports for the 5G Core.

         - 2152 (UDP) for UPF (GTP-U traffic)
         - 38412 (SCTP) for AMF (NGAP from gNBs)
         - 443 (HTTPS) for NMS (management access)

   b. Enable only outgoing traffic necessary for communication with trusted endpoints like RAN and DN.

   c. Restrict protocols to 5G Core essentials:

        i. Allow:
            - SCTP: For N2 interface communication (AMF).
            - UDP: For PFCP (SMF <-> UPF) and GTP-U (UPF <-> RAN).
            - TCP: For HTTP/HTTPS services like NRF or API communication.
            - DNS/TLS: For discovery and secure communication.

        ii. Block other protocols including ICMP, FTP, Telnet, or legacy application protocols unless absolutely necessary.
   
   d. Use IP whitelisting to allow only trusted IP ranges.

2. Place Charmed Aether SD-Core network behind a VPN or private network for additional security.

## Operational Hardening

1. Integrate with the Canonical Observability Stack:
   - Set up monitoring and alerts by integrating with the Canonical Observability Stack (COS).
   - Refer to the [integration guide](https://canonical-charmed-aether-sd-core.readthedocs-hosted.com/en/latest/how-to/integrate_sdcore_with_observability) for steps.

