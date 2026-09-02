# Omarchy WHOOP Privacy Policy

Effective: September 2, 2026

Omarchy WHOOP is a local desktop integration that lets a WHOOP member view
selected WHOOP metrics in the Omarchy status bar.

## Data accessed

With the member's explicit authorization, the plugin requests read-only access
to WHOOP recovery, cycle, and sleep data. This includes recovery score, heart
rate variability, day strain, sleep performance, and sleep duration. It does
not request profile, body-measurement, or workout access.

## Storage and use

The member supplies credentials for a WHOOP developer app they control. The
client secret and OAuth tokens are stored in the member's operating-system
keyring. A compact seven-day dashboard cache is stored in the member's local
state directory with owner-only permissions.

The plugin has no hosted service, analytics, advertising, or third-party data
pipeline. WHOOP data is transmitted only between WHOOP and the member's device
as required to refresh the dashboard. The plugin does not sell or share data.

## Retention and deletion

The local dashboard cache is replaced when the plugin refreshes. Running the
included `uninstall` script removes the plugin's client secret, OAuth tokens,
configuration, cached metrics, and callback log. A member may also revoke the
integration through WHOOP.

## Contact

Privacy questions and security reports may be opened at
<https://github.com/timsweetman1/omarchy-whoop/issues>.
