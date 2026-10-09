# Security policy

## Reporting a vulnerability

Please report vulnerabilities **privately** using GitHub's
[private vulnerability reporting](https://github.com/Catalyst4K/FoodPlanner/security/advisories/new)
(Security tab ▸ Report a vulnerability). Please don't open a public issue.

This is a solo, spare-time project: I'll respond on a best-effort basis. There is
no bug bounty.

## Supported versions

The latest TestFlight / App Store build, and `main`.

## In scope

- Firestore and Storage security rules: reading or modifying another user's
  data, bypassing validation, or reading recipes that haven't been shared.
- Authentication flows: account takeover, or account deletion leaving data
  behind.
- Shared-recipe content that can do anything beyond being displayed as text.
- A credential or secret leaked in the repository or its history.
- The app's dependency supply chain.

## Out of scope

- **The public Firebase iOS configuration itself.** Values such as the API key
  and project ID in `GoogleService-Info.plist` are identifiers, not secrets.
  They are protected by API key restrictions, security rules and App Check, so
  finding them in this repository's history is not a vulnerability.
- Vulnerabilities in Firebase, iOS or Google Cloud themselves; please report
  those to the respective vendor.
- Attacks that require an unlocked device.
- Missing hardening with no demonstrated impact.
