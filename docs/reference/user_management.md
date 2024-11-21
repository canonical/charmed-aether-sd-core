# User Management in the NMS

The Charmed Aether SD-Core automatically creates an admin user whose username and password are securely stored in Juju secrets. These credentials are used to log in to the Network Management System (NMS).

The NMS allows the admin user to manage all users, including creating, changing passwords, and deleting accounts. Other users can manage all resources except user accounts.

```{note}
It is not possible to delete the admin user or change their password.
```