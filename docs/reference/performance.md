# Performance

## UPF throughput

### Results

| UE Type               | UPF Mode  | CNI Type    | Downlink   | Uplink     |
| --------------------- | --------- | --------    | ---------  | ---------  |
| UERANSIM              | DPDK      | vfioveth    | 962 Mbps   | 957 Mbps   |
| UERANSIM              | AF_PACKET | bridge      | 7.8 Mbps   | 823.8 Mbps |
| UERANSIM              | AF_PACKET | MACVLAN     | 8.27 Mbps  | 958 Mbps   |
| UERANSIM              | AF_PACKET | host-device | 8 Mbps     | 957.2 Mbps |
| Quectel RM520N-GL     | DPDK      | vfioveth    | 79.8 Mbps  | 12.5 Mbps  |
| Quectel RM520N-GL     | AF_PACKET | bridge      | 0.741 Mbps | 11.7 Mbps  |
| Quectel RM520N-GL     | AF_PACKET | MACVLAN     | 0.748 Mbps | 12.8 Mbps  |
| Quectel RM520N-GL     | AF_PACKET | host-device | 0.739 Mbps | 12.46 Mbps |

### Methodology

Tests were performed using `iperf3` to measure the throughput between the
UE and an iPerf3 server going through the UPF.

The tests results were obtained by running each test 5 times and averaging the
results.

#### Environment

#### UPF Host

Hardware:
- CPU: Intel i5-1240P
- RAM: 32 GB DDR5
- Network cards: Intel 82599ES 10-Gigabit SFI/SFP+

Software:
- OS: Ubuntu 24.04
- Kubernetes: microk8s 1.31.3
- sdcore-upf-k8s: 1.5/stable; revision 691

#### RAN Host

Hardware:
- CPU: Intel i5-1240P
- RAM: 16 GB DDR5
- Network cards: Intel 82599ES 10-Gigabit SFI/SFP+

Software:
- OS: Ubuntu 24.04
- Kubernetes: microk8s 1.31.3

#### UERANSIM simulator

The UPF performance was tested with the `ueransim` simulator on the RAN host.
The version used for this test was:

- ueransim snap: latest/edge, revision 3, version 3.2.6+git

This test is limited by the simulation done by `ueransim` and the CPU.

#### Over the air with OpenAirInterface

The throughput was tested end-to-end with Charmed OAI RAN running on the RAN host
with a bandwidth of 40 MHz. The radio unit used was a USRP B210 and the UE module
was a Quectel RM520N-GL over USB.

This test is limited by the radio link configuration.
