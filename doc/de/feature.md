# Funktionalität

## Prometheus-Metriken-Endpunkt

Dieses Add-on integriert einen Prometheus-kompatiblen Metriken-Exporter direkt in den Znuny-Daemon-Prozess. Ein separates Skript, ein Cron-Job oder eine Service-Unit ist nicht erforderlich. Nach der Installation stellt der Daemon einen `/metrics`-HTTP-Endpunkt bereit, den jeder Prometheus-Server abfragen kann.

Die folgenden Endpunkte stehen zur Verfügung:

| Pfad | Beschreibung |
|---|---|
| `/metrics` | Prometheus-Textformat (Version 0.0.4) |
| `/health` | Liveness-Check — gibt `OK` zurück |


## Ticket-Metriken

Ticket-Anzahlen werden auf verschiedene Arten gruppiert, um vollständige Transparenz über die aktuelle Arbeitslast zu bieten:

- **Nach Status-Typ** (`znuny_tickets_total`): aggregierte Anzahlen für offene, ausstehende und geschlossene Tickets.
- **Nach individuellem Status** (`znuny_tickets_by_state`): ein Datenpunkt pro konfiguriertem Ticket-Status.
- **Heute erstellt** (`znuny_tickets_created_today`): seit Mitternacht (lokale Serverzeit) erstellte Tickets, nützlich für tägliche Volumen-Dashboards.

## Queue-Metriken

Für jede Queue meldet der Exporter:

- `znuny_queue_tickets_open` — die Anzahl der aktuell offenen Tickets.
- `znuny_queue_tickets_total` — die Gesamtanzahl der Tickets unabhängig vom Status.

Beide Metriken tragen die Labels `queue` und `queue_id`.

## Eskalations- und SLA-Metriken

Die folgenden Metriken helfen dabei, die SLA-Einhaltung auf einen Blick zu überwachen:

| Metrik | Beschreibung |
|---|---|
| `znuny_tickets_escalated` | Offene Tickets, die die allgemeine Eskalationsfrist überschritten haben |
| `znuny_tickets_first_response_overdue` | Offene Tickets, bei denen die Erstantwort überfällig ist |
| `znuny_tickets_update_overdue` | Offene Tickets, bei denen ein Folge-Update überfällig ist |
| `znuny_tickets_solution_overdue` | Offene Tickets, bei denen die Lösung überfällig ist |
| `znuny_tickets_escalation_warning` | Offene Tickets, die sich der Eskalationsfrist nähern (innerhalb von 30 Minuten) |

## Agenten- und Sitzungsmetriken

- `znuny_agents_total` — Anzahl der Agenten-Konten, aufgeteilt nach Gültigkeit (`true` / `false`).
- `znuny_sessions_active` — aktuell aktive Sitzungen, aufgeschlüsselt nach Benutzertyp (agent / customer / unknown).

## Ticket-Typ-Metriken

Wenn die Funktion `Ticket::Type` in Znuny aktiviert ist, werden zwei Metriken mit den Labels `tickettype` und `tickettype_id` ausgegeben:

- `znuny_tickets_by_tickettype` — Ticket-Anzahlen pro Ticket-Typ (alle Status).
- `znuny_open_tickets_by_tickettype` — Anzahl offener Tickets pro Ticket-Typ.

## Service-Metriken

Wenn die Funktion `Ticket::Service` in Znuny aktiviert ist, werden zwei Metriken mit den Labels `service` und `service_id` ausgegeben. Tickets ohne zugewiesenen Service werden unter dem Bucket `service=""` / `service_id="0"` gemeldet:

- `znuny_tickets_by_service` — Ticket-Anzahlen pro Service (alle Status).
- `znuny_open_tickets_by_service` — Anzahl offener Tickets pro Service.

## Scrape-Gesundheitsmetriken

Jeder Scrape gibt außerdem aus:

- `znuny_scrape_duration_seconds` — Dauer der Metrikenerfassung, nützlich für Alerts bei langsamen Datenbankabfragen.
- `znuny_scrape_success` — `1` wenn die Erfassung fehlerfrei abgeschlossen wurde, `0` andernfalls.
