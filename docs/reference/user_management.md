# User Management in the NMS

Upon initialization, the NMS charm creates a first admin user in NMS and securely stores its credentials in a Juju secret with the label `NMS_LOGIN`. These credentials are used by the NMS charm to manage inventory resources like gNodeB's and UPFs. The same credentials can be used by the administrator to log in to the NMS and perform operations.

The NMS allows the admin user to manage all users, including creating, changing passwords, and deleting accounts. Other users can manage all resources except user accounts.

```{note}
It is not possible to delete the admin user or change their password.
```