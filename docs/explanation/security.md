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

Charmed Aether SD-Core platform implements strict access controls and role-based permissions. Other than the admin user, all users are granted limited permissions, ensuring that they can only access, edit, or delete the resources they have created. These include slices, device groups and subscribers. Additionally, each user can only view and manage their own account and has ability to change their own password.

The admin user, however, has full control over the platform. These capabilities include creating and deleting users, managing all resources (slices, device groups, subscribers, etc.), and viewing and editing all accounts. This hierarchical access control provides a secure and organized way to manage users and resources within the system.

To further enhance security, authentication tokens are valid for only one hour. This ensures that access to the platform remains temporary and reduces the risk of unauthorized access in case a token is exposed. This layered security model ensures that permissions are strictly enforced, reducing potential risks and maintaining the integrity of the Charmed Aether SD-Core platform.

Additionally, all HTTP endpoints in the Network Management System (NMS) are secured using HTTPS. This encrypts data in transit and mitigates risks of man-in-the-middle (MITM) attacks. With strong TLS implementations, HTTPS ensures secure connections and protects sensitive information transmitted within the system.

## Database Security

To ensure enhanced security and organization, the Charmed Aether SD-Core platform implements three distinct and isolated data stores. Each data store is dedicated to a specific type of data:

- Network Functions (NFs) data: Stores information related to configurations, operations and the policies of 5G Core network.
- Subscriber data: Contains authentication data and other details related to subscribers.
- NMS users data: Manages data specific to the Network Management System (NMS), including user information, roles, and access permissions.

Access to these databases is tightly controlled by granting different database users the necessary permissions to only access their respective data stores. This granular access control ensures that each database is securely isolated, which reduces risks, prevents unauthorized access, and enforces the principle of least privilege.

## Input Validation

Comprehensive input validation is implemented within charms and the Network Management System (NMS) to mitigate the risk of injection attacks and ensure secure handling of user-provided inputs. 

This validation applies to inputs used for:

- Configuring the Network Management System (NMS)
- Managing and operating charms

By performing through validation and sanitization of inputs in these components, the platform effectively prevents vulnerabilities such as SQL injection, command injection, and other malicious exploitation attempts. This ensures the integrity and security of the platform's underlying systems and protects against unauthorized access or data manipulation.

## Log Confidentiality

The Charmed Aether SD-Core platform enforces strict log confidentiality standards to ensure that sensitive or confidential data is never included in log files. This policy applies to all Network Function logging frameworks and ensures the exclusion of:

- Subscriber authentication tokens or identifiers such as location
- Encryption keys
- Configuration secrets or network-specific credentials

By adhering to these practices, the platform prevents unintended disclosure of confidential information through logging mechanisms, ensuring privacy and maintaining regulatory compliance.

## Secure Dependencies

All libraries and dependencies utilized in Juju charms are continuously monitored, scanned, and updated using **Renovate**. This automation ensures:

- The use of up-to-date libraries and dependencies.
- Identification and mitigation of vulnerabilities in third-party packages.

By leveraging Renovate, the platform ensures that all Juju charms remain secure and aligned with the latest updates, reducing risks associated with outdated or vulnerable code.