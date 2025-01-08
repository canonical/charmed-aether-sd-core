# Performance

## UPF throughput

The UPF performance results presented here were tested on real hardware. The
computer used had the following specifications:

- CPU: Intel i5-1240P
- RAM: 32 Gb DDR5
- Network cards: Intel 82599ES 10-Gigabit SFI/SFP+

The software consisted of:

- OS: Ubuntu 24.04
- Kubernetes: microk8s 1.31.3
- sdcore-upf-k8s: 1.5/stable; revision 691

The UPF was running in DPDK mode, with the network cards passed through SR-IOV.

### RAN Host Specifications

- CPU: Intel i5-1240P
- RAM: 16 Gb DDR5
- Network cards: Intel 82599ES 10-Gigabit SFI/SFP+

The software consisted of:

- OS: Ubuntu 24.04
- Kubernetes: microk8s 1.31.3

### UERANSIM simulator

The UPF performance was tested with the `ueransim` simulator on the RAN host.
The version used for this test was:

- ueransim snap: latest/edge, revision 3, version 3.2.6+git

This test is limited by the simulation done by `ueransim` and the CPU.

The results were:

- Uplink: 957 Mbps
- Downlink: 962 Mbps

### Over the air with OpenAirInterface

The throughput was tested end-to-end with Charmed OAI RAN running on the RAN host
with a bandwidth of 40 MHz. The radio unit used was a USRP B210 and the UE module
was a Quectel RM520N-GL over USB.

This test is limited by the radio link configuration.

The results were:

- Uplink: 12.5 Mbps
- Downlink: 79.8 Mbps
