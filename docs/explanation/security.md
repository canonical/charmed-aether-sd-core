# Security

## Chiseled container images built frequently

Each charm in Charmed Aether SD-Core is distributed by Canonical as a ROCK container image. These images are built using [Rockcraft]( https://documentation.ubuntu.com/rockcraft/en/latest/), a tool to build secure, stable, and OCI-compliant container images.

Each image is chiseled to contain only the bare minimum to run the application. This means that the images are small, and contain only the necessary dependencies to run the application. This reduces the attack surface of the application and makes it easier to maintain.

Each Charmed Aether SD-Core ROCK is scanned for vulnerabilities and built on a weekly schedule. This means that the images are always up-to-date with the latest security patches and bug fixes.

## TLS everywhere

Charmed Aether SD-Core enforces TLS encryption across all communication within the 5G network functions.

Each Charmed Aether SD-Core charm generates its private key and a certificate signing request (CSR). The CSR is then transmitted to a TLS certificate provider, which in turn signs the certificate and sends it back to the charm. Subsequently, the 5G network function utilizes this certificate to encrypt its communications with other network functions.

By default, the TLS certificate provider employed is the [self-signed-certificates operator](https://charmhub.io/self-signed-certificates). However, users have the flexibility to utilize any TLS certificates provider as long as it supports the `tls-certificates` integration.
