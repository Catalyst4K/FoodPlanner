# Firebase emulators

Local Auth and Firestore emulators for development, UI tests and screenshots. They use the made-up
project ID `demo-foodplanner`, so nothing here needs a Firebase account, credentials or network access
to the real project.

## Setup

- Node 22+ and Java 21+ (`brew install openjdk@21`; the scripts look in `/opt/homebrew/opt/openjdk@21`).
- `cd firebase && npm ci` (installs `firebase-tools` locally; nothing is installed globally).

## Use

```bash
cd firebase
npm run emulators   # Auth on :9099, Firestore on :8080
npm run seed        # in another terminal: demo account + made-up recipes, pantry and shopping list
```

Run the app with the launch argument `-use-firebase-emulator` (Xcode scheme ▸ Run ▸ Arguments). It is
honoured in DEBUG builds only. The app's Firebase config must point at `demo-foodplanner`, i.e. use
`ci/GoogleService-Info.plist`, otherwise it reads a different project than the one seeded.

Demo sign-in: `demo@example.com` / `demo-password-123` (emulator only).

## Screenshots

`make screenshots` (from the repo root) starts the emulators, seeds them, runs `ScreenshotTests` in light
and dark mode and writes the PNGs to `docs/screenshots/`. It temporarily swaps in the CI plist and
restores your own `GoogleService-Info.plist` afterwards.

The seed data follows the current (v1) Firestore schema; update `seed.mjs` whenever the schema changes.
