# Changelog

All notable changes. Newest first.

## Unreleased (pull request #1)

### Added
- **Work-account sign-in.** People sign in with their Microsoft 365 or Google Workspace account. The server does the sign-in, only lets in people from your organisation, adds them on first sign-in, and decides who is an administrator.
- **Printers and quotas managed on the server.** Administrators add, switch off and remove printers, set pages a month for new people, for everyone or for one person, and see a setup check that names anything still to do. Pages start again each month.
- A printer picker on the phone, and printer panels fixed to one printer by their address (`?printer=`).
- `docs/09-connecting-your-workspace.md`: the ten-minute setup for Microsoft and Google.
- A new README and guides with pictures of every screen taken from the running app (`docs/Getting%20started.md`, `docs/Fixing%20problems.md`), two diagrams, a short demo GIF, and `tools/screenshots/` to make them again.
- Phone and printer-panel screens: sign in, choose documents, print, confirmation, administrator view.
- A working .NET 8 backend with protected routes, quota checks on the server, and private demo sandboxes.
- Demo banner and "What is this?" dialog on every screen, sample documents on demand, and **Start over**.
- Select all and Clear, plain messages for a long document and for no pages left, partial-print notice.
- The printer panel signs out after 60 seconds without a touch.
- Static hosting on Vercel (`vercel.json`, `scripts/vercel-build.sh`) and a `Dockerfile` and `render.yaml` for the full stack.
- A branded loading screen, page title, description, icons and manifest for the web build.
- Design documents, mockups, an architecture and API reference, and a review record in `docs/`.
- CI for the backend, the app, and the Docker image.
- 112 backend tests and 64 app tests, including a simulated Microsoft/Google sign-in.

### Changed
- `PullPrintingBackend.csproj` is no longer empty; the backend builds.
- Routes match what the app calls. `POST /api/jobs/release` takes `jobIds` and returns what really printed.
- The app uses the server's answer about what printed, and refreshes a stale list.

### Fixed
- Sign in button pushed off screen at large text sizes and on short phones.
- Overflows at 1.5 and 2 times text size.
- A demo administrator could see every visitor's documents.
- Unexpected server errors, missing security headers, and unbounded request sizes.

### Removed
- The MSAL wrapper (`msal_flutter`, `MsAuthService.dart`) and the `AUTH_MODE` and `MS_SCOPE` build settings. Sign-in no longer needs anything in the app.
- The `AzureAd__*` settings, replaced by `Workspace__*`. `Demo__SigningKey` is now `Auth__SigningKey` (the old name still works).
- Windows-only printing code (`System.Printing`), replaced by `IPrintDispatcher` with a simulated implementation.
- The mock JSON server data (`frontend/db.json`).

## Before this

An early prototype: screens and an API shape that were not connected, and a backend that did not build.
