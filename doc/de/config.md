# Konfiguration

## SysConfig-Einstellungen

Der Exporter ist unmittelbar nach der Installation aktiv. Alle Einstellungen sind in der SysConfig unter `Core::Daemon::PrometheusExporter` verfügbar.

### `Daemon::PrometheusExporter::Port`

Der TCP-Port, auf dem der Exporter lauscht. Der Standardwert ist `9405`, der im inoffiziellen Prometheus-Exporter-Portbereich liegt.

Ändern Sie diese Einstellung, wenn ein anderer Dienst auf Ihrem System den Port 9405 bereits belegt.

### `Daemon::PrometheusExporter::Bind`

Die IP-Adresse, an die der Exporter-Socket gebunden wird. Der Standard ist `127.0.0.1`, d. h. nur ein Prometheus-Server auf demselben Host kann den Endpunkt abfragen.

Setzen Sie diesen Wert auf `0.0.0.0`, wenn Ihr Prometheus-Server auf einem anderen Host läuft. Stellen Sie sicher, dass geeignete Firewall-Regeln vorhanden sind, bevor Sie den Port für das Netzwerk öffnen.

## Prometheus-Scrape-Konfiguration

Fügen Sie den folgenden Job zu Ihrer `prometheus.yml` hinzu, um die Znuny-Metriken abzufragen:

```yaml
scrape_configs:
  - job_name: znuny
    static_configs:
      - targets: ['localhost:9405']
```

Ersetzen Sie `localhost` durch den Hostnamen oder die IP-Adresse Ihres Znuny-Servers, wenn Prometheus auf einem anderen Host läuft.

## Optionale Funktionen

### Ticket-Typen (`znuny_tickets_by_tickettype`)

Die Metrik `znuny_tickets_by_tickettype` wird nur ausgegeben, wenn die SysConfig-Option `Ticket::Type` aktiviert ist. Es ist keine weitere Konfiguration erforderlich — der Exporter erkennt die Einstellung automatisch beim Start.

### Ticket-Services (`znuny_tickets_by_service`)

Die Metrik `znuny_tickets_by_service` wird nur ausgegeben, wenn die SysConfig-Option `Ticket::Service` aktiviert ist. Der Exporter lädt das `Kernel::System::Service`-Objekt nur bei aktiver Funktion, um unnötigen Overhead auf Installationen ohne Services zu vermeiden.

## Daemon-Neustart

Nach einer Änderung einer SysConfig-Einstellung muss der Znuny-Daemon neu gestartet werden, damit die neuen Werte wirksam werden:

```bash
bin/znuny.Daemon.pl stop
bin/znuny.Daemon.pl start
```
