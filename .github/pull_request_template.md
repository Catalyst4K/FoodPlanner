## Summary

<!-- What changed and why, in a few sentences. -->

## Linked plan task

<!-- e.g. "Phase 1.4" or "R.12" from docs/IMPLEMENTATION_PLAN.md -->

## Test layers touched

<!-- Tick at least one, or explain why none apply. -->

- [ ] Unit
- [ ] Integration
- [ ] Rules
- [ ] UI
- [ ] None, because:

## Security checklist

- [ ] No secrets or real user data in code, fixtures or screenshots
- [ ] If a Firestore/Storage path or field changed: `firestore.rules` and the rules tests are updated
- [ ] User-supplied content (especially shared recipes) is rendered as plain text
- [ ] If data now goes somewhere new: a `docs/decisions.md` entry exists

## Built and tested on Xcode?

<!-- yes / no. Cloud sessions can't build the app and must say "no"; such a PR can't merge until CI's `build-test` is green. -->

## Screenshots

<!-- For UI changes: light and dark. Delete this section otherwise. -->
