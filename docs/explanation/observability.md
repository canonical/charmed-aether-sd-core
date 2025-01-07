# Observability

Charmed Aether SD-Core fully integrates with Canonical’s Observability Stack (COS) to provide a comprehensive view of the 5G network's operations. Through this integration, operators can effectively monitor network usage, gauge performance metrics, and diagnose potential issues.

- **Metrics**: All charms within Charmed Aether SD-Core implement the [prometheus_scrape](https://charmhub.io/integrations/prometheus_scrape) charm relation interface, which allows them to expose metrics that are scraped by Prometheus and available in Grafana. This includes metrics about status, subscriber connectivity, throughput, in addition to the default Go runtime metrics.

- **Logging**: All charms within Charmed Aether SD-Core implement the [loki_push_api](https://charmhub.io/integrations/loki_push_api) charm relation interface, which allows them to send logs to the Loki, the COS logging service. This enables operators to collect, centralize, and query logs from the 5G network functions.

- **Dashboard**: Charmed Aether SD-Core includes a “5G Network Overview” Grafana dashboard that displays information about network performance, subscriber connectivity, system status, and more.

- **Tracing (optional)**: All charms within Charmed Aether SD-Core implement the [tracing](https://charmhub.io/integrations/tracing) charm relation interface, which allows them to send traces to Tempo, the COS tracing service. This enables operators to trace requests through the 5G network and diagnose potential issues.

For more information about COS, read its [official documentation](https://charmhub.io/topics/canonical-observability-stack).
