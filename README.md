<div align="center">
  <a href="https://www.znuny.com">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://www.znuny.com/assets/znuny-logo.svg">
      <img alt="Znuny" src="https://www.znuny.com/assets/znuny-logo-black.svg" width="300">
    </picture>
  </a>

  ![Build status](https://badge.proxy.znuny.com/Znuny-PrometheusExporter/dev)
</div>



Znuny-PrometheusExporter
========================

This add-on exposes a Prometheus-compatible `/metrics` HTTP endpoint directly from within the Znuny Daemon process. It provides ticket, queue, state, agent, session, escalation, and SLA metrics without requiring a separate exporter process or script.

**Prerequisites**

- Znuny 7.3

**Installation**

- Install it via the package manager from the `Znuny Open Source Add-ons` repository.
- Download the package and install it via the admin interface -> package manager.

> [!IMPORTANT]
> The Znuny Daemon needs to be restarted after the installation.

**Configuration**

The exporter is active immediately after installation with sensible defaults. Optional settings are available in SysConfig under `Core::Daemon::PrometheusExporter`:

| Setting | Default | Description |
|---|---|---|
| `Daemon::PrometheusExporter::Port` | `10111` | TCP port the exporter listens on |
| `Daemon::PrometheusExporter::Bind` | `127.0.0.1` | IP address to bind to (`0.0.0.0` for all interfaces) |

**Exposed metrics**

| Metric | Labels | Description |
|---|---|---|
| `znuny_tickets_total` | `state_type` | Ticket count by state type (open / pending / closed) |
| `znuny_tickets_by_state` | `state`, `state_id` | Ticket count per individual ticket state |
| `znuny_queue_tickets_open` | `queue`, `queue_id` | Open tickets per queue |
| `znuny_queue_tickets_total` | `queue`, `queue_id` | All tickets per queue |
| `znuny_tickets_escalated` | — | Open tickets that have breached the escalation deadline |
| `znuny_tickets_first_response_overdue` | — | Open tickets overdue for first agent response |
| `znuny_tickets_update_overdue` | — | Open tickets overdue for follow-up update |
| `znuny_tickets_solution_overdue` | — | Open tickets overdue for resolution |
| `znuny_tickets_escalation_warning` | — | Open tickets approaching escalation deadline (within 30 min) |
| `znuny_agents_total` | `valid` | Agent accounts by validity |
| `znuny_sessions_active` | `user_type` | Active sessions by user type (agent / customer) |
| `znuny_tickets_created_today` | — | Tickets created since midnight (server local time) |
| `znuny_tickets_by_tickettype` | `tickettype`, `tickettype_id` | Ticket count per type (only when `Ticket::Type` is enabled) |
| `znuny_open_tickets_by_tickettype` | `tickettype`, `tickettype_id` | Open ticket count per type (only when `Ticket::Type` is enabled) |
| `znuny_tickets_by_service` | `service`, `service_id` | Ticket count per service; `service=""` means no service assigned (only when `Ticket::Service` is enabled) |
| `znuny_open_tickets_by_service` | `service`, `service_id` | Open ticket count per service; `service=""` means no service assigned (only when `Ticket::Service` is enabled) |
| `znuny_open_tickets_by_priority` | `priority`, `priority_id` | Open ticket count per priority |
| `znuny_scrape_duration_seconds` | — | Time taken to collect all metrics |
| `znuny_scrape_success` | — | `1` if last collection succeeded, `0` otherwise |

The endpoint also responds to `GET /health` and `GET /` with a plain `OK` for liveness checks.

**Commercial Support**

For this add-on and for Znuny in general visit [www.znuny.com](https://www.znuny.com). Looking forward to hear from you!

Your Znuny Team!

[https://www.znuny.com](https://www.znuny.com)
