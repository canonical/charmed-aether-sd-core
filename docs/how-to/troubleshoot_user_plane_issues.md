# Troubleshoot user plane issues

This guide provides step-by-step troubleshooting actions to identify user plane
issues. It assumes that a UE (User Equipḿent) was able to connect to the network
and establish a PDU session, meaning that the UE received an IP address. It also
assume that the UE already tried using the connection unsuccessfully.

If you encounter an issue and aren't able to address it via this guide, please
raise an issue [here][Bug Report].

## 1. Validate the UPF charm status

```shell
juju status
```

The UPF charm should be in `Active/Idle` status:

```shell
Model      Controller                  Cloud/Region                Version  SLA          Timestamp
private5g  microk8s-classic-localhost  microk8s-classic/localhost  3.4.6    unsupported  18:56:32Z

App  Version  Status  Scale  Charm           Channel   Rev  Address         Exposed  Message
upf  1.4.0    active      1  sdcore-upf-k8s  1.5/edge  622  10.152.183.236  no

Unit    Workload  Agent  Address       Ports  Message
upf/0*  active    idle   10.1.145.115

Offer  Application  Charm           Rev  Connected  Endpoint  Interface  Role
amf    amf          sdcore-amf-k8s  752  0/0        fiveg-n2  fiveg_n2   provider
upf    upf          sdcore-upf-k8s  622  0/0        fiveg_n3  fiveg_n3   provider
```

## 2. Access `bessctl` for direct UPF troubleshooting

```shell
juju ssh --container bessd upf/leader
```

```shell
/opt/bess/bessctl/bessctl
```

You can exit of `bessctl` by typing `quit` or pressing `Ctrl-D`.

## 3. Validate access and core routes modules are present

```{code-block}
:caption: bessctl

show module accessDstMAC<tab>
show module coreDstMAC<tab>
```

If a module exists, the output should look something like this:

```{code-block}
:caption: bessctl

localhost:10514 $ show module accessDstMAC7E5DCC5D4B2A
  accessDstMAC7E5DCC5D4B2A::Update()
    Input gates:
        0: batches 0           packets 0            accessRoutes:0 ->	
    Output gates:
        0: batches 40          packets 40           -> 0:accessMerge	Track::track0
    Deadends: 0
```

Please note the number of packets under the `Output gates` line.

### A. One or both modules do not exist

In this case, the `routectl` service failed to detect the MAC address of the
corresponding gateway.

Validate the `access-gateway-ip`, `core-gateway-ip` and other network
configurations provided to the charm. You can test connectivity to those gateway
IPs by exiting from `bessctl` and using ping:

```shell
ping <access-gateway-ip>
ping <core-gateway-ip>
```

If those validation are successful, this is a bug. Please raise an issue
[here][Bug Report].

### B. The accessDstMAC module exists, but does not show packets

Network packets destined for the UE are not making it through the UPF. Validate
that packets are coming into the UPF on the Core interface:

```{code-block}
:caption: bessctl

show module coreQ0FastPI
```

If no packets are shown here, validate that packets are going out through the
core interface:

```{code-block}
:caption: bessctl

show module coreQ0FastPO
```

If packets are going out, there is a network problem outside of the UPF, between
the UPF and the data network.

Otherwise, move on to step 4.

### C. The coreDstMAC module exists, but does not show packets

Network packets destined to the Data Network are not being routed to the core
interface. Validate that packets are coming into the UPF from the GNB:

```{code-block}
:caption: bessctl

show module accessQ0FastPI
```

If no packets are coming into the UPF, there is a network problem outside of the
UPF, between the GNB and the UPF.

Otherwise, move on to step 4.

## 4. Trace the traffic through the BESS pipeline

Enable the HTTP server of BESS:

```{code-block}
:caption: bessctl

http
```

This enables a server on `http://localhost:5000`. You can use a port forward to
expose the port to the outside:

```shell
kubectl port-forward -n <model_name> --address 0.0.0.0 pod/upf-0 5000
```

Connect to the server from your browser on port 5000. The URL should be
similar to `http://<k8s-node-ip>:5000`.

You should see a graph similar to this on the page:

```{image} ../images/bess_http_server.png
:alt: BESS node gates
:height: 500px
:align: center
```

You can use the scroll wheel of your mouse to zoom in and out and click and drag
to move around.

Start a constant ping on the UE towards the data network. Make sure that the
`Auto refresh` checkbox is selected, and that the mode is set to `Current rate`.

You should see traffic show up as numbers on the edges between the nodes of the
graph. First, trace the packets coming from the UE. Please note that not all
nodes are covered below for brevity.

1. Start at the `accessQ0FastPI` node
2. Packets should go through the `gtpuDecap` node
3. Packets should make their way to the `coreRoutes` node
4. From the `coreRoutes` node, they should go to the `coreDstMAC*` node
5. Packets will go out of the UPF by going through `coreNAT` and `coreQ0FastPO`

Then, trace the packets coming back from the data network:

1. Start at the `coreQ0FastPI` node
2. Packets should go through the `coreNAT` node
3. Packets should then go through the `gtpuEncap` node
3. Packets should make their way to the `accessRoutes` node
4. From the `accessRoutes` node, they should go to the `accessDstMAC*` node
5. Packets will go out of the UPF by going through `accessQ0FastPO`

Using this process might help you figure out where the issue is. In case you
require additional help, this will be useful information to share on our [Matrix
channel] when asking questions.

## 5. Capture traffic at an arbitrary point in the BESS pipeline

It is possible to take network packet captures at any point in the BESS pipeline
to get a better view of the traffic. To do so, first select the module you are
interested in, then the direction (either packets coming into the module or out
of the module), and then the gate number. The gate number can be found at the
arrow end entering or existing the module. If no gate number is present, use 0.

```{image} ../images/bess_node_gates.png
:alt: BESS node gates
:height: 150px
:align: center
```

For example, to take a network capture for packets coming into the `coreNAT`
module at gate 0, use the following command:

```{code-block}
:caption: bessctl

tcpdump coreNAT in 0
```

To see packets going out of the `gtpuEncap` on gate 1, use:

```{code-block}
:caption: bessctl

tcpdump gtpuEncap out 1
```

You can also pass parameters directly to `tcpdump` at the end of the command,
like the following to not try name resolution on captured addresses:

```{code-block}
:caption: bessctl

tcpdump coreNAT in 0 -n
```

## Going further

For more information on BESS and `bessctl`, please refer to the [upstream documentation].

[Bug Report]: https://github.com/login?return_to=https%3A%2F%2Fgithub.com%2Fcanonical%2Fcharmed-aether-sd-core%2Fissues%2Fnew%3Fassignees%3D%26amp%3Blabels%3Dbug%26amp%3Bprojects%3D%26amp%3Btemplate%3Dbug_report.yml
[Matrix channel]: https://matrix.to/#/#charmhub-charmed5g:ubuntu.com
[upstream documentation]: https://github.com/omec-project/bess/wiki
