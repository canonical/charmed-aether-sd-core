# Performance

## UPF throughput

### Results

| UE Type               | UPF Mode  | Downlink  | Uplink    |
| --------------------- | --------- | --------- | --------- |
| UERANSIM              | DPDK      | 962 Mbps  | 957 Mbps  |
| OAI UE (Over the air) | DPDK      | 79.8 Mbps | 12.5 Mbps |
| UERANSIM              | AF_PACKET | 6.146     | 268.2     |

### Methodology

Tests were performed using `iperf3` to measure the throughput between the
UE and an iPerf3 server going through the UPF.

The tests results were obtained by running each test 5 times and averaging the
results.

#### Environment

#### UPF Host

Software:
- OS: Ubuntu 24.04
- Kubernetes: microk8s 1.31.3
- sdcore-upf-k8s: 1.5/stable; revision 691

#### RAN Host

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
