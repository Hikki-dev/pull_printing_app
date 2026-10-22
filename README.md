# pull_printing_app

A **secure pull-printing** system. A user sends a document to print, the server **holds** it, and it only prints when the user walks up to a printer, signs in and releases it. Built with a **Flutter** app and an **ASP.NET Core** backend, with **Microsoft Entra ID** supported for sign-in.

[![CI](https://github.com/Hikki-dev/pull_printing_app/actions/workflows/ci.yml/badge.svg)](https://github.com/Hikki-dev/pull_printing_app/actions/workflows/ci.yml)
![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![.NET](https://img.shields.io/badge/.NET-8-512BD4?logo=dotnet&logoColor=white)
![Status](https://img.shields.io/badge/status-working%20demo-orange)

> **Status: working demo.** The app and API work together end to end, and the whole thing can be hosted for free as a public demo where each visitor gets their own sample documents. Nothing is sent to a real printer. See [Limits](#limits) for what is not built.

## Try the demo

**Live demo: <https://pull-print-demo-hikki-devs-projects.vercel.app>** (runs entirely in your browser on built-in sample data).

Press **Sign in with Microsoft**. In the demo that signs you in to a private sandbox as "Alice Tan".

- You start with four sample documents and 38 of 50 pages left.
- Tick the documents you want and press **Print**. Tick too many and Print switches off and says by how many pages.
- Printing does not use a real printer. It marks the documents as printed and uses up pages.
- Out of documents? **Send sample documents** gives you more.
- **Demo: sign in as administrator** shows every job and lets you change page limits, on a private copy of sample people.
- A banner on every screen says it is a demo, and **What is this?** explains it in plain words.
- Printed everything? **What is this?** in the banner has **Start over**.
- Other visitors never see your documents. In the live demo your data lives only in your browser tab; in the full-stack version your sandbox is deleted after 2 hours without use.

## How it works

1. A user sends a file to print, from anywhere in the company.
2. The server stores the job as **Waiting**. Nothing prints yet.
3. At the printer the user signs in.
4. A screen shows **only their own documents**. They press Print on the ones they want.
5. The job prints and their page quota goes down. An administrator can set quotas.

## Features

| Feature | Where | State |
|---|---|---|
| Phone and printer-panel screens: sign in, choose documents, select all, print, confirmation | `frontend/lib/screens/` | Done |
| Plain messages for a long document, no pages left, partial print, a stale list, an ended session | `release_jobs_screen.dart`, `api_service.dart` | Done, tested |
| Printer panel signs out after 60 seconds without a touch | `release_jobs_screen.dart` | Done, tested |
| Works at 1.5 and 2 times text size and on a 360 px phone | | Done, tested |
| Documents are only ever your own, quota is enforced on the server | `backend/services/PrintStore.cs` | Done, tested |
| Admin: stats, job table with search and filter, per-user quota editing | `admin_dashboard_screen.dart`, `AdminController.cs` | Done, tested |
| Demo sign-in with a private sandbox per visitor | `AuthController.cs`, `PrintStore.cs` | Done, tested |
| Microsoft Entra ID sign-in | `Program.cs`, `MsAuthService.dart` | Written, **not tested against a real tenant** |
| Real printing | `IPrintDispatcher` | Not built. The demo uses a simulated printer |
| Sending a file to be held | | Not built. The demo creates sample documents |

## Design

UX documents, mockups, the design rules, an [architecture and API reference](docs/07-architecture-and-api.md) and a [review of what went wrong and was fixed](docs/08-review-and-fixes.md) are in [`docs/`](docs/README.md). See also [CONTRIBUTING](CONTRIBUTING.md), [SECURITY](SECURITY.md) and the [CHANGELOG](CHANGELOG.md).

## Architecture

```
Flutter app (frontend/)                     ASP.NET Core API (backend/)
 LoginScreen ─┐                                /api/auth/*   sign-in
 ReleaseJobsScreen                             /api/jobs/*   my documents, print
 PrintedScreen ── PrintRepository             /api/admin/*  users and quotas
 AdminDashboardScreen  ├ MockPrintRepository    /healthz
                       └ HttpPrintRepository ─HTTP─▶  PrintStore (in memory)
                                                        IPrintDispatcher (simulated)
```

In the hosted demo the API also serves the web build of the app, so there is one address and no cross-origin set-up.

### API

All routes except sign-in and health need `Authorization: Bearer <token>`.

| Method | Route | Who | What it does |
|---|---|---|---|
| `POST` | `/api/auth/demo-login` | anyone, demo only | Creates a private sandbox and returns a token. Body `{ "admin": false }`. 404 unless `Demo__Enabled` is true |
| `GET` | `/api/auth/me` | signed in | Name and role from the token |
| `GET` | `/api/jobs/held` | signed in | Your waiting documents, newest first |
| `GET` | `/api/jobs/quota` | signed in | `{ used, total, left }` pages |
| `POST` | `/api/jobs/release` | signed in | Body `{ "jobIds": [...] }`. 200 with what printed, 409 `quota_exceeded` with `pagesOver`, 404 if none of them are yours and waiting, 400 if empty |
| `POST` | `/api/jobs/sample` | signed in, demo only | Adds one sample document to your list |
| `GET` | `/api/jobs` | administrator | Every job in the administrator's own group |
| `GET` | `/api/admin/users` | administrator | People in the administrator's group with their quotas |
| `POST` | `/api/admin/set-quota` | administrator | Body `{ "userId", "quota" }`, 0 to 10000 pages |
| `GET` | `/healthz` | anyone | `{ "status": "ok" }` |

## Sign-in and security

- **Every route except sign-in and `/healthz` needs a valid token.** Tokens are real signed JWTs, checked on every request. Admin routes need the Admin role.
- **People only reach their own data.** Printing ignores any document id that is not yours and waiting. Administrators only see and change people in their own group, so a demo administrator cannot touch another visitor.
- **Demo sign-in** (`Demo__Enabled=true`) hands out tokens for private sandboxes. It is limited to 20 sign-ins a minute per address and 300 requests a minute overall, at most 300 sandboxes exist at once, and each person can have at most 12 documents waiting. Switch it off for anything real: its tokens stop working immediately.
- **Microsoft Entra ID** is used when `AzureAd__TenantId` and `AzureAd__ClientId` are set. Tokens are validated against your tenant's published keys, the audience must be your client id (or `api://<client id>`), and anyone with the `PullPrint.Admin` app role is an administrator. New people get 50 pages on first sign-in.
  1. Register an app in Entra ID and expose an API scope such as `access_as_user`.
  2. Add an app role `PullPrint.Admin` and assign it to administrators.
  3. Put your tenant and client ids in `frontend/lib/services/MsAuthService.dart`, set `AzureAd__TenantId` and `AzureAd__ClientId` on the server.
  4. Build the app with `--dart-define=USE_MOCK=false --dart-define=AUTH_MODE=microsoft --dart-define=MS_SCOPE=api://<client id>/access_as_user`.

  This path is written but has not been run against a real tenant.

## Run it locally

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install) and the [.NET 8 SDK](https://dotnet.microsoft.com/download).

```bash
git clone https://github.com/Hikki-dev/pull_printing_app.git
cd pull_printing_app

# Just the app, on built-in sample data. No server needed.
flutter pub get
flutter run -t frontend/lib/main.dart

# The whole thing: API plus app, the way the hosted demo runs.
flutter build web -t frontend/lib/main.dart --dart-define=USE_MOCK=false --dart-define=AUTH_MODE=demo
mkdir -p backend/wwwroot && cp -r build/web/. backend/wwwroot/
ASPNETCORE_ENVIRONMENT=Development dotnet run --project backend   # then open the address it prints

# The app against an API running somewhere else (for example flutter run -d chrome)
flutter run -d chrome -t frontend/lib/main.dart \
  --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://localhost:5000/api
```

Run the tests with `flutter test` (43) and `dotnet test backend.Tests` (39).

Screens narrower than 760 px use the phone layout, wider ones the printer-panel layout.

## Host it for free

Two ways, both described in [`docs/06-demo-hosting.md`](docs/06-demo-hosting.md):

- **Static, no server (what the live demo uses).** `vercel.json` and `scripts/vercel-build.sh` build the app on built-in sample data. Connect the repository to a Vercel project.
- **Full stack.** A `Dockerfile` builds the web app and the API into one image, and `render.yaml` deploys it on Render's free plan: create a free account, choose **New, Blueprint**, and pick this repository.

## Repository layout

```
frontend/lib/        Flutter source: main.dart, screens, services, models, widgets, utils
backend/             ASP.NET Core API: controllers, services, models
backend.Tests/       API and store tests
scripts/             Build script for static hosting
CONTRIBUTING.md  SECURITY.md  CHANGELOG.md
test/                Flutter tests
docs/                Design documents, mockup images and mockup source
Dockerfile           One image with the API and the web app
render.yaml          One-click free hosting on Render
.github/workflows/   CI: backend and Flutter tests
android/ ios/ web/ macos/ linux/ windows/   Flutter platform folders
```

The Flutter entry point is **`frontend/lib/main.dart`**, not `lib/main.dart`.

## Limits

This is a demo, so on purpose:

1. **Data lives in memory.** Everything resets when the server restarts, and demo sandboxes are deleted after 2 hours without use. A database would replace `PrintStore` (it sits behind `IPrintStore`).
2. **Nothing is really printed.** `SimulatedPrintDispatcher` only logs. A real printer integration implements `IPrintDispatcher`.
3. **No way to send a file yet.** The demo makes sample documents. Real submission (a print driver, email-to-print or upload) is an open decision, see `docs/05-open-decisions.md`.
4. **Microsoft sign-in is untested** against a real tenant, and the `msal_flutter` package only supports Android and iOS, so a Windows or Linux printer panel needs another approach such as the device code flow.
5. **Free hosts sleep.** The first visit after a quiet period can take a minute to wake the server.
6. **Placeholders to replace:** the Pull Print mark, the printer illustration, drawn document thumbnails and the drawn Microsoft mark (use Microsoft's own asset). See `docs/04-design-guidelines.md`.
7. **Not built:** staff-card sign-in and the phone code sign-in screen from the mockups.
8. **Duplicate MSAL wrappers.** `MsAuthService.dart` and `msal_flutter.dart` overlap. Keep one.

## Roadmap

- [x] Redesigned UI, demo mode and tests
- [x] Backend builds, routes match the app, endpoints protected, tests
- [x] Free hosting for a public demo
- [x] A review from each user's point of view, with fixes ([docs/08](docs/08-review-and-fixes.md))
- [ ] Test Microsoft sign-in against a real tenant
- [ ] Persist users, jobs and quotas in a database
- [ ] A way to send a file to be held
- [ ] A real printer integration
- [ ] Card login at the printer

## Author

Built by [Yusuf (Hikki-dev)](https://github.com/Hikki-dev).
