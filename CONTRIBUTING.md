# Contributing to Super Sync

Thanks for your interest. Super Sync is a pub workspace; the core lives in
`packages/super_sync`.

## Before you open a PR

```bash
dart pub get
dart format packages/super_sync/lib packages/super_sync/test
dart analyze packages/super_sync
dart test packages/super_sync
```

All four must be clean. CI runs the same steps.

## Guidelines

- Keep the core **pure Dart** (no Flutter) and **backend-agnostic** (no vendor
  SDKs). Backends and UI integrations live in their own packages.
- Match the existing style: `very_good_analysis`, dartdoc on every public
  member, `final`/`const` where possible.
- New behaviour needs a test. The in-memory store + fake remote make end-to-end
  tests cheap.
- Please follow the [Code of Conduct](CODE_OF_CONDUCT.md).
