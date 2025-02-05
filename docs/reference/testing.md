# Testing

Charmed Aether SD-Core is tested at different levels to ensure its correctness and performance. The tests are focused on the operational aspects of the solution - deploy, integrate, scale, upgrade.

## Individual Charm tests

- **Unit tests**: Each charm has a suite of unit tests that assert the correctness of the charm's behavior under different scenarios. Those tests are written using the [Scenario](https://github.com/canonical/ops-scenario) unit testing framework for charms. The tests are run automatically on each pull request. The tests are located in the `tests/unit/` directory of each charm. For example, the unit tests for the `sdcore-amf` charm are located [here](https://github.com/canonical/sdcore-amf-k8s-operator/tree/main/tests/unit).
- **Integration tests**: Each charm has a suite of integration tests that deploy the charm in a Kubernetes cluster, alongside its dependencies, and assert that it behaves correctly. The tests are run automatically on each pull request. The tests are located in the `tests/integration/` directory of each charm. For example, the integration tests for the `sdcore-amf` charm are located [here](https://github.com/canonical/sdcore-amf-k8s-operator/tree/main/tests/integration).

## Solution tests

- **end-to-end tests**: Charmed Aether SD-Core is tested as a whole using end-to-end tests that deploy the entire solution via Terraform in a Kubernetes cluster. Those tests also deploy a simulated RAN and UE using the [sdcore-gnbsim-k8s charm](https://github.com/canonical/sdcore-gnbsim-k8s-operator/) and run a series of tests that assesss that a subscriber can register, use the data plane, and deregister. The tests are run automatically once a day. The tests are located [here](https://github.com/canonical/sdcore-tests) and a dashboard of the test results is available [here]( https://canonical.github.io/sdcore-tests/).

## Performance tests

Performance tests are run to assess the throughput of the solution under different scenarios. The tests are run manually once every release. More information about the performance tests can be found [here](performance.md).

## A note on workload testing

Charmed Aether SD-Core is a charmed distribution of Aether SD-Core. The focus of the testing is therefore on the charms themselves. If you are interested in learning more about how the 5G core is tested (ex. 3GPP procedures), please refer to the upstream project.
