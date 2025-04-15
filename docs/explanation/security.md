# Security

## Chiseled container images built frequently

Each charm in Charmed Aether SD-Core is distributed by Canonical as a ROCK container image. These images are built using [Rockcraft]( https://documentation.ubuntu.com/rockcraft/en/latest/), a tool to build secure, stable, and OCI-compliant container images.

Each image is chiseled to contain only the bare minimum to run the application. This means that the images are small, and contain only the necessary dependencies to run the application. This reduces the attack surface of the application and makes it easier to maintain.

Each Charmed Aether SD-Core ROCK is scanned for vulnerabilities and built on a weekly schedule. This means that the images are always up-to-date with the latest security patches and bug fixes.

## TLS everywhere

Charmed Aether SD-Core enforces TLS encryption across all communication within the 5G network functions.

Each Charmed Aether SD-Core charm generates its private key and a certificate signing request (CSR). The CSR is then transmitted to a TLS certificate provider, which in turn signs the certificate and sends it back to the charm. Subsequently, the 5G network function utilizes this certificate to encrypt its communications with other network functions.

By default, the TLS certificate provider employed is the [self-signed-certificates operator](https://charmhub.io/self-signed-certificates). However, users have the flexibility to utilize any TLS certificates provider as long as it supports the `tls-certificates` integration.

## Access Control and Secure Communication in NMS

Charmed Aether SD-Core uses JWT-based authentication with role-based permissions to ensure secure access. Admin users have full control over all resources and accounts, while all other users have restricted permissions, limited to managing the resources they create and their own accounts. Authentication tokens expire after one hour. Furthermore, all HTTP endpoints in the Network Management System (NMS) are secured with HTTPS.

## Database Security

Charmed Aether SD-Core ensures security and isolation by keeping network functions, NMS users and subscribers' data in different databases.

Granular access control restricts each database user's permissions to their respective data store, ensuring isolation, minimizing risks and enforcing the least privilege principle.

## Input Validation

Input validation mechanisms are implemented within charms and the Network Management System (NMS) to enhance the secure handling of user-provided inputs. These validations primarily target inputs used for:

- Configuring the Network Management System (NMS)
- Managing and operating charms

By ensuring validation and sanitization of certain inputs, the platform aims to reduce the risks associated with vulnerabilities like SQL injection, command injection, and exploitation attempts.

## Log Confidentiality

Charmed Aether SD-Core adopts enhanced log confidentiality practices to ensure that sensitive or confidential data is excluded from log files.

- Subscriber authentication tokens or identifiers such as location
- Encryption keys
- Configuration secrets or network-specific credentials

By adhering to these practices, the platform prevents unintended disclosure of confidential information through logging mechanisms and ensures privacy.

## Secure Dependencies

All libraries and dependencies utilized in Juju charms are continuously monitored, scanned, and updated. This automation ensures:

- The use of up-to-date libraries and dependencies.
- Identification and mitigation of vulnerabilities in third-party packages.
