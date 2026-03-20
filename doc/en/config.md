# Configuration

## SysConfig settings

The exporter is active immediately after installation. All settings are available in SysConfig under `Core::Daemon::PrometheusExporter`.

### `Daemon::PrometheusExporter::Port`

The TCP port on which the exporter listens. The default value is `9405`, which is in the unofficial Prometheus exporter port range.

Change this setting if another service already occupies port 9405 on your system.

### `Daemon::PrometheusExporter::Bind`

The IP address the exporter socket binds to. The default is `127.0.0.1`, which means only a Prometheus server running on the same host can scrape the endpoint.

Set this to `0.0.0.0` if your Prometheus server runs on a separate host. Ensure appropriate firewall rules are in place before opening the port to the network.

## Prometheus scrape configuration

Add the following job to your `prometheus.yml` to scrape the Znuny metrics:

```yaml
scrape_configs:
  - job_name: znuny
    static_configs:
      - targets: ['localhost:9405']
```

Replace `localhost` with the hostname or IP of your Znuny server if Prometheus runs on a different host.

## Optional features

### Ticket types (`znuny_tickets_by_type`)

The metric `znuny_tickets_by_type` is only emitted when the SysConfig option `Ticket::Type` is enabled. No additional configuration is required — the exporter detects the setting automatically at startup.

### Ticket services

The exporter loads the `Kernel::System::Service` object only when `Ticket::Service` is enabled, avoiding unnecessary overhead on installations that do not use services.

## Daemon restart

After changing any SysConfig setting, restart the Znuny Daemon for the new values to take effect:

```bash
bin/znuny.Daemon.pl stop
bin/znuny.Daemon.pl start
```
