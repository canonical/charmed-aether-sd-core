# Testing

Charmed Aether SD-Core is tested at different levels to ensure its correctness and performance. The tests are focused on the operational aspects of the solution - deploy, configure, and integrate.

## Individual Charm tests

- **Unit tests**: Each charm has a suite of unit tests that assert the correctness of the charm's behavior under different scenarios. We write those tests using the [Scenario](https://github.com/canonical/ops-scenario) unit testing framework for charms. Each individual charm's Continuous Integration pipeline automatically tuns these tests on each pull request. You can find these tests under the `tests/unit/` directory of each charm. For example, the unit tests for the `sdcore-amf` charm are located [here](https://github.com/canonical/sdcore-amf-k8s-operator/tree/main/tests/unit).
- **Integration tests**: Each charm has a suite of integration tests that deploy the charm in a Kubernetes cluster alongside its dependencies and assert that it behaves correctly. The tests are run automatically on each pull request. The tests are located in the `tests/integration/` directory of each charm. For example, the integration tests for the `sdcore-amf` charm are located [here](https://github.com/canonical/sdcore-amf-k8s-operator/tree/main/tests/integration).

## Solution tests

- **end-to-end tests**: Charmed Aether SD-Core is tested as a whole using end-to-end tests that deploy the entire solution via Terraform in a Kubernetes cluster. Those tests also deploy a simulated RAN and UE using the [sdcore-gnbsim-k8s charm](https://github.com/canonical/sdcore-gnbsim-k8s-operator/) and run a series of tests that assess that a subscriber can register, use the data plane, and deregister. The tests are run automatically once a day. The tests are located [here](https://github.com/canonical/sdcore-tests) and a dashboard of the test results is available [here]( https://canonical.github.io/sdcore-tests/).

## Performance tests

We run performance tests to assess the throughput of the solution under different scenarios. We run those tests manually once every release. You can learn more about performance tests [here](performance.md).

## A note on workload testing

Charmed Aether SD-Core is a charmed distribution of Aether SD-Core. Therefore, the testing focuses on the charms themselves - and not on their underlying workloads (ex. 5G network functions). If you want to learn more about how the underlying 5G core is tested (ex., 3GPP procedures), please refer to the upstream project.
