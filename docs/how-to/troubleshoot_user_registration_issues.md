# Troubleshoot subscriber registration issues
This guide provides step-by-step troubleshooting actions to remediate subscriber registration issues. We hope you don't need this guide. If you encounter an issue and aren't able to address it via this guide, please raise an issue [here][Bug Report].

The examples use GNBSIM as the 5G gNodeB and UE simulator.

## 1. Subscriber registration failure

### Symptoms
The `juju debug-log sdcore-gnbsim-k8s/leader` command reports an error in the UE registration:
```console
handling event: REGISTRATION-REJECT-EVENT	{"component": "GNBSIM", "category": "SimUe", "supi": "imsi-001010100007487"}
```
#### Possible reasons
This error is typically raised when the UE is not provisioned in SD-Core or the link between AMF and AUSF or between AUSF and UDM/UDR is not established.

### Recommended Actions
#### Provisioning
Validate that the UE is provisioned in SD-Core, either via the UI or the API. Validate that the UE trying to connect to the core has the same IMSI.

#### Configuration
Validate the AMF is able to select an AUSF by inspecting logs using `kubectl logs -n sdcore amf-0 -c amf -f`. The logs should report:
```console
INFO	gmm/handler.go:1509	Authentication procedure	{"component": "AMF", "category": "GMM", "amf_ue_ngap_id": "AMF_UE_NGAP_ID:36", "suci": "suci-0-001-01-0-0-0-0100007487"}
INFO	message/send.go:80	send Authentication Request	{"component": "AMF", "category": "GMM", "amf_ue_ngap_id": "AMF_UE_NGAP_ID:36", "suci": "suci-0-001-01-0-0-0-0100007487"}
INFO	gmm/handler.go:583	Handle InitialRegistration	{"component": "AMF", "category": "GMM", "amf_ue_ngap_id": "AMF_UE_NGAP_ID:2", "suci": "suci-0-001-01-0-0-0-0100007487", "supi": "SUPI:imsi-001010100007487"}
INFO	gmm/handler.go:2254	Handle Registration Complete	{"component": "AMF", "category": "GMM", "amf_ue_ngap_id": "AMF_UE_NGAP_ID:2", "suci": "suci-0-001-01-0-0-0-0100007487", "supi": "SUPI:imsi-001010100007487"}
INFO	fsm/fsm.go:99	handle event[ContextSetup Success], transition from [ContextSetup] to [Registered]	{"component": "LIB", "category": "FSM"}
```

Validate the AUSF is able to select a UDM by inspecting logs using `kubectl logs -n sdcore ausf-0 -c ausf -f`. The logs should report:
```console
INFO	producer/ue_authentication.go:84	HandleUeAuthPostRequest	{"component": "AUSF", "category": "UeAuthPost"}
INFO	producer/ue_authentication.go:66	Auth5gAkaComfirmRequest	{"component": "AUSF", "category": "5gAkaAuth"}
```

Validate the UDM is able to select a UDR by inspecting logs using `kubectl logs -n sdcore udm-0 -c udm -f`. The logs should report no errors after this line:
```console
INFO	producer/generate_auth_data.go:84	handle GenerateAuthDataRequest	{"component": "UDM", "category": "UEAU"}
```
If the logs do not match, ensure that NRF, AUSF, UDM, UDR pods are up and running using `kubectl get pods -n sdcore`.
The command should report `Running` for all the three pods.
```console
NAME                            READY   STATUS    RESTARTS   AGE
nrf-0                           2/2     Running   0          15m
ausf-0                          2/2     Running   0          15m
udm-0                           2/2     Running   0          13m
udr-0                           2/2     Running   0          13m
```
If any of the pods is not in `Running` state, you can try to restart it using `kubectl kill <pod-name> -n sdcore`.

## 2. Subscriber authentication failure

### Symptoms
The `juju debug-log sdcore-gnbsim-k8s/leader` command reports an error in the UE authentication:
```console
handling event: AUTHENTICATION-REJECT-EVENT	{"component": "GNBSIM", "category": "SimUe", "supi": "imsi-001010100007487"}
```
#### Possible reasons
This error is typically raised when the UE is provisioned in SD-Core but the authentication (OPc and/or key) data in SD-Core does not match the actual UE data or the link between AMF and AUSF or between AUSF and UDM/UDR is not established.

### Recommended Actions
#### Provisioning
Validate whether the UE authentication in SD-Core matches the actual UE authentication data, either via the UI or the API.

#### Configuration
If the logs do not match, ensure that NRF, AUSF, UDM, UDR pods are up and running using `kubectl get pods -n sdcore`.
The command should report `Running` for all the three pods.
```console
NAME                            READY   STATUS    RESTARTS   AGE
nrf-0                           2/2     Running   0          15m
ausf-0                          2/2     Running   0          15m
udm-0                           2/2     Running   0          13m
udr-0                           2/2     Running   0          13m
```
If any of the pods is not in `Running` state, you can try to restart it using `kubectl kill <pod-name> -n sdcore`.

## 3. Session establishment failure

### Symptoms

The `juju debug-log sdcore-gnbsim-k8s/leader` command reports an error in the UE authentication:
```console
handling event: PDU-SESSION-ESTABLISHMENT-REJECT-EVENT	{"component": "GNBSIM", "category": "SimUe", "supi": "imsi-001010100007487"}
```
#### Possible reasons
This error is typically raised when the UE is provisioned in SD-Core but the DNN (Data Network Name) and or the S-NSSAI requested by the UE are not available in SD-Core. It is also possible that the AMF is not able to select an SMF, or the SMF is not able to connect to UPF.

### Recommended Actions
#### Provisioning
Validate whether the DNN/S-NSSAI requested by the UE are available in the configured Network Slice and Device Group for the UE, either via the UI or the API.

#### Configuration
Validate the AMF is able to select an AUSF by inspecting logs using `microk8s.kubectl logs -n sdcore amf-0 -c amf -f`. The logs should report:
```console
INFO	gmm/handler.go:94	Transport 5GSM Message to SMF	{"component": "AMF", "category": "GMM", "amf_ue_ngap_id": "AMF_UE_NGAP_ID:54", "suci": "suci-0-001-01-0-0-0-0100007487", "supi": "SUPI:imsi-001010100007487"}
INFO	consumer/sm_context.go:74	Select SMF [snssai: {Sst:1 Sd:102030}, dnn: internet]	{"component": "AMF", "category": "GMM", "amf_ue_ngap_id": "AMF_UE_NGAP_ID:54", "suci": "suci-0-001-01-0-0-0-0100007487", "supi": "SUPI:imsi-001010100007487"}
INFO	gmm/handler.go:262	create smContext[pduSessionID: 10] Success	{"component": "AMF", "category": "GMM", "amf_ue_ngap_id": "AMF_UE_NGAP_ID:54", "suci": "suci-0-001-01-0-0-0-0100007487", "supi": "SUPI:imsi-001010100007487"}
INFO	message/send.go:288	send PDU Session Resource Setup Request	{"component": "AMF", "category": "NGAP", "ran_addr": "10.1.142.71/192.168.251.5:9487", "amf_ue_ngap_id": "AMF_UE_NGAP_ID:54"}
```

Validate the SMF is able to connect to UPF by inspecting logs using `kubectl logs -n sdcore smf-0 -c smf -f`. The logs should report:
```console
INFO	pdusession/api_individual_sm_context.go:97	receive Update SM Context Request	{"component": "SMF", "category": "PduSess"}
INFO	producer/pdu_session.go:313	PDUSessionSMContextUpdate, update received	{"component": "SMF", "category": "PduSess", "uuid": "urn:uuid:554a3fbb-0d23-451b-b3e9-c6fad3e96c8c", "id": "imsi-001010100007487", "pduid": 10}
INFO	producer/n1n2_data_handler.go:320	PDUSessionSMContextUpdate, N2 SM info type PDU_RES_SETUP_RSP received	{"component": "SMF", "category": "PduSess", "uuid": "urn:uuid:554a3fbb-0d23-451b-b3e9-c6fad3e96c8c", "id": "imsi-001010100007487", "pduid": 10}
INFO	context/sm_context.go:276	context state change, current state[SmStateActive] next state[SmStateModify]	{"component": "SMF", "category": "CTX", "uuid": "urn:uuid:554a3fbb-0d23-451b-b3e9-c6fad3e96c8c", "id": "imsi-001010100007487", "pduid": 10}
INFO	context/sm_context.go:276	context state change, current state[SmStateModify] next state[SmStatePfcpModify]	{"component": "SMF", "category": "CTX", "uuid": "urn:uuid:554a3fbb-0d23-451b-b3e9-c6fad3e96c8c", "id": "imsi-001010100007487", "pduid": 10}
INFO	context/sm_context.go:276	context state change, current state[SmStatePfcpModify] next state[SmStatePfcpModify]	{"component": "SMF", "category": "CTX", "uuid": "urn:uuid:554a3fbb-0d23-451b-b3e9-c6fad3e96c8c", "id": "imsi-001010100007487", "pduid": 10}
INFO	producer/pdu_session.go:384	PDUSessionSMContextUpdate, send PFCP Modification	{"component": "SMF", "category": "PduSess", "uuid": "urn:uuid:554a3fbb-0d23-451b-b3e9-c6fad3e96c8c", "id": "imsi-001010100007487", "pduid": 10}
INFO	message/send.go:355	sent PFCP Session Modify Request to NodeID[10.152.183.225]	{"component": "SMF", "category": "PFCP", "uuid": "urn:uuid:554a3fbb-0d23-451b-b3e9-c6fad3e96c8c", "id": "imsi-001010100007487", "pduid": 10}
INFO	handler/handler.go:530	handle PFCP Session Modification Response	{"component": "SMF", "category": "PFCP"}
INFO	handler/handler.go:567	PFCP Modification Response Accept	{"component": "SMF", "category": "PduSess", "uuid": "urn:uuid:554a3fbb-0d23-451b-b3e9-c6fad3e96c8c", "id": "imsi-001010100007487", "pduid": 10}
INFO	handler/handler.go:588	PFCP Session Modification Success[4]	{"component": "SMF", "category": "PFCP", "uuid": "urn:uuid:554a3fbb-0d23-451b-b3e9-c6fad3e96c8c", "id": "imsi-001010100007487", "pduid": 10}
INFO	context/sm_context.go:276	context state change, current state[SmStatePfcpModify] next state[SmStateActive]	{"component": "SMF", "category": "CTX", "uuid": "urn:uuid:554a3fbb-0d23-451b-b3e9-c6fad3e96c8c", "id": "imsi-001010100007487", "pduid": 10}
INFO	context/sm_context.go:276	context state change, current state[SmStateActive] next state[SmStateActive]	{"component": "SMF", "category": "CTX", "uuid": "urn:uuid:554a3fbb-0d23-451b-b3e9-c6fad3e96c8c", "id": "imsi-001010100007487", "pduid": 10}
```
If the logs do not match, ensure that NRF, AUSF, SMF, UPF pods are up and running using `kubectl get pods -n sdcore`.
The command should report `Running` for all the three pods.
```console
NAME                            READY   STATUS    RESTARTS   AGE
nrf-0                           2/2     Running   0          15m
ausf-0                          2/2     Running   0          15m
smf-0                           2/2     Running   0          13m
upf-0                           3/3     Running   0          13m
```
If any of the pods is not in `Running` state, you can try to restart it using `kubectl kill <pod-name> -n sdcore`.

If all pods are running, you can check that SMF and UPF are reachable from each other:
1. retrieve SMF address from Juju: `juju status | grep "smf/0" | awk '{print $4}'`
2. enter UPF pod: `juju ssh --container bessd upf/leader`
3. from there, use `ping <smf-ip>` to assess connectivity.

If pods can communicate, you can check K8S exposes PFCP service from UPF using `kubectl get service -n sdcore upf-external`. The output should include the following:
```console
[...]
  ports:
  - name: pfcp
    nodePort: 31621
    port: 8805
    protocol: UDP
    targetPort: 8805
  selector:
    app.kubernetes.io/name: upf
  sessionAffinity: None
  type: LoadBalancer
[...]
```
If the output does not match, please raise an issue [here][Bug Report]. 

If the output matches, you can check any network configuration or firewall preventing the PFCP communication between SMF and UPF.

[Bug Report]: https://github.com/canonical/charmed-aether-sd-core/issues/new?template=bug_report.yml
