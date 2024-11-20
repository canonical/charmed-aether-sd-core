# User Management

The Charmed Aether SD-Core automatically creates an admin user whose username and password are securely stored in Juju secrets. These credentials are used to log in to the Network Management System (NMS).

The NMS allows the admin user to manage all users, including creating, changing passwords, and deleting accounts. Other users can manage all resources except user accounts.

```{caution}
Avoid changing the admin user's password directly in the NMS. This password must also be updated in the corresponding Juju secret to prevent inconsistencies and maintain system accessibility.
```