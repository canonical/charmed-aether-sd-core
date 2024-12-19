# Test UPF Performance

This guide covers how to test the performance of the UPF.

## Requirements

You will need for this test a working deployment of Charmed Aether SD-Core by following the [Mastering Tutorial](../tutorials/mastering.md).

You will also require a machine on the data network to run the `iperf3` server.

## Setting up

Log in to the `juju-controller` VM:

```console
lxc exec juju-controller --user 1000 -- bash -l
```

Disable the GNB simulator temporarily:

```console
juju switch gnbsim
juju scale-application gnbsim 0
```

Connect to the gnbsim host:

```console
ssh gnbsim
```

Install the required software:

```console
sudo apt update
sudo apt install iperf3
sudo snap install ueransim --edge
sudo snap connect ueransim:network-control
```

Note down the IP of the `gnbsim` VM's management interface:

```console
ip a show dev enp5s0
```

Edit the UERANSIM's gNodeB configuration file:

```console
sudo vim /var/snap/ueransim/common/gnb.yaml
```

Edit the `ngapIp` field to the IP of the management interface noted
above.

Edit the `gtpIp` field to `10.204.0.100`.

Edit the `address` field under `amfConfigs` to `amf.mgmt`.

This section of the file should look like this:

```yaml
linkIp: 127.0.0.1    # IP to use between UE and GNB
ngapIp: 10.201.0.103 # IP to use to communicate with the AMF
gtpIp:  10.204.0.100 # IP to use to communicate with the UPF

# List of AMF address information
amfConfigs:
  - address: amf.mgmt
    port: 38412
```

## Running the simulator

Prepare 2 terminals connected to the `gnbsim` VM.

In the first one, run the gNodeB:

```console
sudo ueransim.nr-gnb -c /var/snap/ueransim/common/gnb.yaml
```

The logs should report:

```
NG Setup procedure is successful
```

In the second terminal, run the UE:

```console
sudo ueransim.nr-ue -c /var/snap/ueransim/common/ue.yaml
```

The logs should report:

```
Connection setup for PDU session[1] is successful, TUN interface[uesimtun0, 172.250.0.5] is up
```

The exact IP address might the UE gets might be different.

## Test the connectivity

Open another terminal to the `gnbsim` VM. Run the command:

```console
ping -I uesimtun0 8.8.8.8
```

The pings should get replies.

## Test connectivity to host

Open a terminal to the host running the VMs. Note down its IP:

```console
ip addr show
```

From the `gnbsim` VM, try to ping it through UE simulator:

```console
ping -I uesimtun0 <IP address of the host>
```

## Run performance test

On the host, start an `iperf3` server:

```console
sudo apt update
sudo apt install iperf3
iperf3 -s
```

On the `gnbsim` terminal, run the `iperf3` client:

```console
iperf3 -c <IP address of the host> --bind-dev uesimtun0
```
