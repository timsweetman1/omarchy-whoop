# Security Policy

## Reporting a vulnerability

Please use GitHub's **Report a vulnerability** button on this repository's
Security tab. That creates a private report visible only to the maintainer and
the reporter. Do not disclose secrets, OAuth codes, tokens, or private health
data in a public issue.

For ordinary bugs that do not involve sensitive information, use GitHub Issues.

## Security model

This is a local-only integration. Every installer creates and controls their
own WHOOP developer app. Client secrets and OAuth tokens are stored in the
desktop keyring, not in the repository or dashboard cache. The plugin requests
only recovery, cycle, and sleep scopes.

Never share developer credentials. This repository contains no client ID or
client secret; each install uses credentials created and controlled by that
installer. The local desktop is the trusted endpoint for this personal-use
integration.

The custom callback URI is protected by a cryptographically random, single-use,
10-minute OAuth state value. As with other custom desktop URI schemes, another
local application could try to claim the same scheme; do not install untrusted
desktop software, and cancel authorization if the browser opens an unexpected
application.

The local cache contains health metrics and is created with owner-only
permissions. Anyone with access to your unlocked desktop session or user
account may still be able to view it.

## Supported versions

Security fixes are applied to the latest release on the default branch.
