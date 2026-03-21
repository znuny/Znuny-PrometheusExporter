# Functionality

## Prometheus metrics endpoint

This add-on integrates a Prometheus-compatible metrics exporter directly into the Znuny Daemon process. No separate script, cron job, or service unit is required. Once installed, the Daemon exposes a `/metrics` HTTP endpoint that any Prometheus server can scrape.

The following endpoints are available:

| Path | Description |
|---|---|
| `/metrics` | Prometheus text exposition format (version 0.0.4) |
| `/health` | Liveness check — returns `OK` |

::: tip :::
**A restart of the Znuny Daemon after the installation is required.**
:::::::::::

## Ticket metrics

Ticket counts are grouped in several ways to give full visibility into the current workload:

- **By state type** (`znuny_tickets_total`): aggregated counts for open, pending, and closed tickets.
- **By individual state** (`znuny_tickets_by_state`): one data point per configured ticket state.
- **Created today** (`znuny_tickets_created_today`): tickets created since midnight (server local time), useful for daily volume dashboards.

## Queue metrics

For every queue, the exporter reports:

- `znuny_queue_tickets_open` — the number of currently open tickets.
- `znuny_queue_tickets_total` — the total number of tickets regardless of state.

Both metrics carry `queue` and `queue_id` labels.

## Escalation and SLA metrics

The following metrics help monitor SLA compliance at a glance:

- `znuny_tickets_escalated` - Open tickets that have breached the overall escalation deadline
- `znuny_tickets_first_response_overdue` - Open tickets overdue for first agent response
- `znuny_tickets_update_overdue` - Open tickets overdue for a follow-up update
- `znuny_tickets_solution_overdue` - Open tickets overdue for resolution
- `znuny_tickets_escalation_warning` - Open tickets approaching escalation deadline (within 30 minutes)

## Agent and session metrics

- `znuny_agents_total` — count of agent accounts separated by validity (`true` / `false`).
- `znuny_sessions_active` — currently active sessions, broken down by user type (agent / customer / unknown).

## Ticket type metrics

When the `Ticket::Type` feature is enabled in Znuny, two metrics are emitted with `tickettype` and `tickettype_id` labels:

- `znuny_tickets_by_tickettype` — ticket counts per ticket type (all states).
- `znuny_open_tickets_by_tickettype` — open ticket counts per ticket type.

## Service metrics

When the `Ticket::Service` feature is enabled in Znuny, two metrics are emitted with `service` and `service_id` labels. Tickets without a service assigned are reported under the bucket `service=""` / `service_id="0"`:

- `znuny_tickets_by_service` — ticket counts per service (all states).
- `znuny_open_tickets_by_service` — open ticket counts per service.

## Scrape health metrics

Each scrape also emits:

- `znuny_scrape_duration_seconds` — how long metric collection took, useful for alerting on slow database queries.
- `znuny_scrape_success` — `1` if collection completed without errors, `0` otherwise.
