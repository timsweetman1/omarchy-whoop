# WHOOP for Omarchy

A private, local WHOOP dashboard for the Omarchy bar. It follows the native
Agents-panel design language and shows current recovery, HRV, sleep, strain,
and seven-day recovery and sleep trends.

## What it shows

- Recovery score and HRV
- Sleep performance and time asleep
- Current day strain
- Seven-day recovery and sleep trends
- Last successful refresh time

The toolbar uses WHOOP's official puck icon. Left click opens the panel,
middle click refreshes, and right click opens WHOOP. In the panel, `R`
refreshes, `O` opens WHOOP, `Tab` switches panels, and `Esc` closes it.

## Privacy model

This plugin has no hosted service. Each installer creates a personal WHOOP
developer app, and all credentials, tokens, and cached metrics stay on that
person's Omarchy machine. Tokens and the client secret are stored in the OS
keyring; the compact dashboard cache is owner-readable only.

The tradeoff is a few minutes of setup. A shared one-click OAuth app would
require hosted infrastructure, a stronger security program, and WHOOP app
approval. The local-first model is intentionally the first public release.

## Install

```bash
omarchy plugin add https://github.com/timsweetman1/omarchy-whoop --enable
~/.config/omarchy/plugins/io.github.timsweetman1.whoop/setup
```

The guided setup checks dependencies, registers the local callback handler,
and prints the exact values needed for the WHOOP developer app.

## WHOOP developer app

Create an app at <https://developer-dashboard.whoop.com/apps/create> with:

| Field | Value |
|---|---|
| App name | `Omarchy WHOOP` |
| Privacy policy | `https://github.com/timsweetman1/omarchy-whoop/blob/main/PRIVACY.md` |
| Redirect URL | `omarchy-whoop://oauth/callback` |
| Scopes | `read:recovery`, `read:cycles`, `read:sleep` |

Do not enable profile, body-measurement, or workout access. Paste the generated
client ID and secret into the guided terminal setup. The secret input is hidden
and stored directly in the OS keyring.

After WHOOP grants access, the browser asks to open an application. Accept that
prompt so the one-time authorization code reaches the local callback handler.

## Requirements

- Omarchy 4.0 or newer
- A WHOOP membership with recorded data
- A free WHOOP developer account
- `python`, `curl`, `jq`, `secret-tool`, `xdg-open`, and
  `update-desktop-database`

The setup script installs missing Arch packages through `omarchy pkg add`.

## Storage

| Data | Location |
|---|---|
| Client ID and settings | `~/.config/omarchy-whoop/config.json` (owner-only) |
| Client secret and OAuth tokens | OS keyring under `service=omarchy-whoop` |
| Compact dashboard cache | `~/.local/state/omarchy-whoop/latest.json` |
| Privacy-safe callback status | `~/.local/state/omarchy-whoop/callback.log` |

The callback log records only success/failure stages. It never records OAuth
codes, tokens, client secrets, or health values.

## Remove

Run the cleanup before removing the Git checkout:

```bash
~/.config/omarchy/plugins/io.github.timsweetman1.whoop/uninstall
omarchy plugin remove io.github.timsweetman1.whoop
```

You can also revoke the app from WHOOP's connected-app settings.

## Validate

```bash
omarchy plugin validate .
python -m unittest discover -s tests -v
```

Security issues should be reported privately as described in [SECURITY.md](SECURITY.md).

## Brand

WHOOP is a trademark of WHOOP, Inc. The puck assets are the official files
distributed in the WHOOP Developer Platform design kit and are used only to
identify this API integration. This project is not affiliated with or endorsed
by WHOOP, Inc.

## License

Plugin source is available under the MIT License. As detailed in [NOTICE](NOTICE),
WHOOP brand assets are excluded from that license and remain subject to WHOOP's
brand and API terms.
