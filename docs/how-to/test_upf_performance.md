# Test UPF Performance

This guide covers how to test the performance of the UPF.

## Requirements

You will need for this test a working deployment of Charmed Aether SD-Core by following the [Mastering Tutorial](../tutorials/mastering.md).

You will also require a machine on the data network to run the `iperf3` server.

## Setting up

Log in to the `juju-controller` VM:

```console
lxc exec juju-controller -- su --login ubuntu
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

On the host, install `iperf3` and start an `iperf3` server:

```console
sudo apt update
sudo apt install iperf3
iperf3 -s
```

```{note}
You may need to use a different port if the default port is already in use.
```

### Uplink

On the `gnbsim` terminal, run the `iperf3` client:

```console
iperf3 -c <IP address of the host> --bind-dev uesimtun0
```

You should see the throughput reported. For example:

```console
ubuntu@gnbsim:~$ iperf3 -c 10.42.0.13 -p 1234 --bind-dev uesimtun0
Connecting to host 10.42.0.13, port 1234
[  5] local 172.250.0.5 port 59850 connected to 10.42.0.13 port 1234
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-1.00   sec   512 KBytes  4.19 Mbits/sec  132   10.5 KBytes       
[  5]   1.00-2.00   sec   384 KBytes  3.14 Mbits/sec   67   6.58 KBytes       
[  5]   2.00-3.00   sec   640 KBytes  5.24 Mbits/sec   77   3.95 KBytes       
[  5]   3.00-4.00   sec  2.12 MBytes  17.8 Mbits/sec  213   2.63 KBytes       
[  5]   4.00-5.00   sec  2.50 MBytes  21.0 Mbits/sec  189   2.63 KBytes       
[  5]   5.00-6.00   sec   768 KBytes  6.30 Mbits/sec  124   3.95 KBytes       
[  5]   6.00-7.00   sec   512 KBytes  4.19 Mbits/sec   84   3.95 KBytes       
[  5]   7.00-8.00   sec   384 KBytes  3.15 Mbits/sec   71   9.21 KBytes       
[  5]   8.00-9.00   sec   384 KBytes  3.15 Mbits/sec  117   1.32 KBytes       
[  5]   9.00-10.00  sec   512 KBytes  4.19 Mbits/sec   76   10.5 KBytes       
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-10.00  sec  8.62 MBytes  7.23 Mbits/sec  1150             sender
[  5]   0.00-10.00  sec  8.25 MBytes  6.92 Mbits/sec                  receiver

iperf Done.
```

### Downlink

On the `gnbsim` terminal, run the `iperf3` client:

```console
iperf3 -c <IP address of the host> --bind-dev uesimtun0
```

You should see the throughput reported. For example:

```console
ubuntu@gnbsim:~$ iperf3 -c 10.42.0.13 -p 1234 --bind-dev uesimtun0 -R
Connecting to host 10.42.0.13, port 1234
Reverse mode, remote host 10.42.0.13 is sending
[  5] local 172.250.0.5 port 52354 connected to 10.42.0.13 port 1234
[ ID] Interval           Transfer     Bitrate
[  5]   0.00-1.00   sec  23.0 MBytes   193 Mbits/sec                  
[  5]   1.00-2.00   sec  22.9 MBytes   192 Mbits/sec                  
[  5]   2.00-3.00   sec  21.8 MBytes   183 Mbits/sec                  
[  5]   3.00-4.00   sec  22.8 MBytes   191 Mbits/sec                  
[  5]   4.00-5.00   sec  23.0 MBytes   193 Mbits/sec                  
[  5]   5.00-6.00   sec  23.0 MBytes   193 Mbits/sec                  
[  5]   6.00-7.00   sec  22.8 MBytes   191 Mbits/sec                  
[  5]   7.00-8.00   sec  22.8 MBytes   191 Mbits/sec                  
[  5]   8.00-9.00   sec  23.1 MBytes   194 Mbits/sec                  
[  5]   9.00-10.00  sec  22.9 MBytes   192 Mbits/sec                  
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-10.00  sec   228 MBytes   191 Mbits/sec  20524             sender
[  5]   0.00-10.00  sec   228 MBytes   191 Mbits/sec                  receiver

iperf Done.
```

### Summary

The results above show the throughput of the connection between the UE and the host. In this case:
- **Uplink**: 7.23 Mbits/sec
- **Downlink**: 191 Mbits/sec
