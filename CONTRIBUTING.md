# Contributing

Thanks for helping. This is a small project, so the process is light.

## Get set up

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install) and the [.NET 8 SDK](https://dotnet.microsoft.com/download).

```bash
flutter pub get
flutter run -t frontend/lib/main.dart        # the app on built-in sample data

dotnet run --project backend                 # the API (ASPNETCORE_ENVIRONMENT=Development turns demo sign-in on)
```

The README has the full list of ways to run it, and [`docs/07-architecture-and-api.md`](docs/07-architecture-and-api.md) explains how the pieces fit.

## Before you open a pull request

Run what CI runs:

```bash
dotnet test backend.Tests
flutter analyze --no-fatal-infos
flutter test
```

- **Add a test with every behaviour change.** Server rules go in `backend.Tests`; screens and the API client go in `test/`.
- **Check large text.** `test/widget_test.dart` runs the phone screens at 1.5 and 2 times text size and fails on any overflow. New screens should be added there.
- **Keep the server in charge.** The app only shows things; any rule about who may do what belongs in the backend, with a test.
- **Match the style around you.** Run `dart format` on Flutter code you touch.
- **Wording is part of the design.** Use the plain words in [`docs/03-screen-specs.md`](docs/03-screen-specs.md#wording), and keep messages saying what to do next.
- **No stock or generated imagery, no emoji.** See [`docs/04-design-guidelines.md`](docs/04-design-guidelines.md).

## Pull requests

- One change per pull request, with a description that says what changed, why, and how you checked it.
- Say what you did **not** check.
- Update the docs in `docs/` and `CHANGELOG.md` when behaviour changes.

## Reporting problems

Use the issue templates. For anything security related, read [SECURITY.md](SECURITY.md) first.
