# Add Inventory to the Network Management System (NMS)

The Network Management System (NMS) has an Inventory section that displays inventory elements, such as gNodeBs and UPFs. These tables are automatically populated by the NMS charm. To add UPFs or gNodeBs to the inventory, integrate their respective charms with the NMS charm using the appropriate Juju relation.

## Integrate with gNodeB Charm

SD-Core can be integrated with any charm that supports the [`fiveg_core_gnb` relation interface](https://charmhub.io/integrations/fiveg_core_gnb/draft) as a requirer. There are two existing solutions that implement this interface. To integrate them with a standalone SD-Core deployment, follow the steps in:

1. [Integrate with SD-Core gNB Simulator](deploy_sdcore_gnbsim.md)
2. [Integrate with an Externally Managed Radio](integrate_sdcore_with_external_gnb.md)

## Integrate with UPF Charm

SD-Core can be integrated with any charm that supports the [`fiveg_n4` relation interface](https://charmhub.io/integrations/fiveg_n4/draft) as a provider.

To deploy and integrate the SD-Core UPF K8s Operator with a standalone SD-Core deployment, follow the steps in: [Deploy SD-Core User Plane in DPDK Mode](deploy_sdcore_user_plane_in_dpdk_mode.md).
