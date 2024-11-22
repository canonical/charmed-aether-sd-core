# User Management in the NMS

Upon initialization, the NMS charm creates an admin user in NMS and securely stores its credentials in a Juju secret with the label `NMS_LOGIN`. These credentials are used by the NMS charm to manage inventory resources, such as gNodeBs and UPFs. Additionally, the administrator can use the same credentials to log in to the NMS and perform operations.

In the NMS, there is a single admin account with full access to manage all resources, including user accounts. This account cannot be deleted or have its password changed.

Other user accounts are created with the `user` role, which allows them to manage all resources except user accounts.