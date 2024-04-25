# Observability

Charmed Aether SD-Core fully integrates with Canonical’s Observability Stack (COS) to provide a comprehensive view of the 5G network's operations. Through this integration, operators can effectively monitor network usage, gauge performance metrics, and diagnose potential issues.

- **Metrics**: The AMF, SMF and UPF network functions expose metrics about status, subscriber connectivity and more. Those metrics are scraped by Prometheus and available in Grafana.

- **Logging**: The MongoDB charm forwards its logs to Loki which makes them available in Grafana.

- **Dashboard**: Charmed Aether SD-Core includes a “5G Network Overview” dashboard that displays information about UPF throughput and subscriber connectivity.

For more information about COS, read its [official documentation](https://charmhub.io/topics/canonical-observability-stack).
