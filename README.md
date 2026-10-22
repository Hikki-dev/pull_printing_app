# pull_printing_app

A **secure pull-printing** system prototype. A user sends a document to print, the server **holds** it, and it only prints when the user walks up to a printer, signs in and releases it. Built with a **Flutter** client and a **.NET (ASP.NET Core)** backend, with **Microsoft Entra ID (Azure AD)** for identity.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![.NET](https://img.shields.io/badge/.NET-ASP.NET%20Core-512BD4?logo=dotnet&logoColor=white)
![Status](https://img.shields.io/badge/status-prototype-orange)

> **Status: early prototype.** The Flutter app is fully redesigned and works end to end in **demo mode** (sample data, no server). Wiring it to the .NET backend is not finished and the backend does not build. Read [Current status](#current-status) before relying on any part of it.

## About

An app that runs against a server and uses Azure to get the user's login details. When someone prints, the server keeps the job on hold until they go to the printer, sign in with the required credentials, and release it. They only ever see and print **their own** documents.

## How it works

1. A user sends a file to print, in the format they choose, from anywhere in the company (any floor).
2. The server stores the job as **Held**. Nothing prints yet.
3. At the printer the user signs in with their Azure credentials (card login is the intended next step).
4. A screen shows **only their held jobs**. They press print on the ones they want.
5. The job prints and their print quota goes down by one. An admin can set quotas.

## Features

| Feature | Where | State |
|---|---|---|
| Sign in with Microsoft (official mark and button) | `screens/login_screen.dart`, `services/MsAuthService.dart` | Works in demo mode. Real MSAL sign-in is untested (Android and iOS only) |
| Your documents: thumbnails, tap to select, live page total, quota ring | `screens/release_jobs_screen.dart`, `widgets/` | Done, phone and printer-panel layouts |
| Print selected documents, blocked when over quota | `release_jobs_screen.dart`, `services/print_repository.dart` | Done in demo mode |
| Confirmation, pages left, automatic sign-out on the panel (20 s) | `screens/printed_screen.dart` | Done |
| Admin: stats, job table with search and filter, per-user quota editing | `screens/admin_dashboard_screen.dart` | Done in demo mode. Reached through "Demo: sign in as administrator" |
| Release endpoint with quota check | `backend/controllers/JobsController.cs` | Written, backend does not build yet |
| Admin set-quota endpoint | `backend/controllers/AdminController.cs` | Written, backend does not build yet |
| Print to a Windows queue | `backend/services/PrintService.cs` | Written (Windows only) |

## Design

UX documents and mockups for the phone, printer panel and admin screens are in [`docs/`](docs/README.md).

## Architecture

```
Flutter app (frontend/)                     ASP.NET Core API (backend/)
 LoginScreen ─┐                                AuthController   POST /api/auth/login
 ReleaseJobsScreen ── PrintRepository          JobsController   GET  /api/jobs
 PrintedScreen        ├ MockPrintRepository                     POST /api/jobs/release
 AdminDashboardScreen └ HttpPrintRepository ─HTTP─▶ AdminController POST /api/admin/set-quota
                                                   │
                                   AzureAuthService · UserService · PrintService
                                                                    └─ System.Printing queue
```

### Data models

- `User`: `Id`, `DisplayName`, `Email`, `IsAdmin`, `PrintQuota`
- `PrintJob`: `Id`, `UserId`, `FileName`, `IsReleased`, `SubmittedAt`
- `Quota`: `UserId`, `RemainingQuota`

### Backend API

| Method | Route | Purpose |
|---|---|---|
| `POST` | `/api/auth/login` | Body is a token string. 200 if valid, 401 otherwise |
| `GET` | `/api/jobs` | List jobs |
| `POST` | `/api/jobs/release` | Release a job. 403 when the user's quota is 0, otherwise prints and decrements the quota |
| `POST` | `/api/admin/set-quota` | Body `{ "userId", "quota" }` |

## Repository layout

```
frontend/lib/        Flutter source: main.dart, screens, services, models, widgets, utils
docs/                Design documents, mockup images and mockup source
frontend/db.json     Sample held and released jobs for a mock JSON API
backend/             ASP.NET Core API: controllers, services, models, data
android/ ios/ web/ macos/ linux/ windows/   Flutter platform folders
pubspec.yaml         Flutter dependencies (repo root)
```

The Flutter entry point is **`frontend/lib/main.dart`**, not `lib/main.dart`.

## Running the Flutter app

```bash
git clone https://github.com/Hikki-dev/pull_printing_app.git
cd pull_printing_app
flutter pub get
flutter run -t frontend/lib/main.dart            # demo mode, no server needed
flutter test                                      # widget and unit tests
```

- **Demo mode (default).** All data is in memory (`MockPrintRepository`). Sign in as Alice, or use "Demo: sign in as administrator". Data resets on restart.
- **Layouts.** Screens below 760 px wide use the phone layout, wider ones the printer-panel layout. Resize a desktop or web window to see both.
- **Real backend.** `flutter run -t frontend/lib/main.dart --dart-define=USE_MOCK=false`. `ApiService` calls `http://localhost:3000` with `GET /jobs`, `GET /jobs/held`, `POST /jobs/release`, `POST /admin/set-quota`. Point it at your API, or at a mock server fed by `frontend/db.json`.
- `frontend/lib/utils/constants.dart` holds `apiBaseUrl` (default `http://localhost:5000/api`), but `ApiService` does not use it yet.

## Azure AD setup

1. In the Azure portal, register an application in **Microsoft Entra ID**.
2. Add a **Mobile and desktop** redirect URI of the form `msal<client-id>://auth`.
3. Add the delegated permission `User.Read`.
4. Put your tenant and client ID in `frontend/lib/services/MsAuthService.dart` and `backend/services/AzureAuthService.cs`. Both currently contain placeholder or sample values.

## Current status

Done in this round: the Flutter UI is redesigned and runs end to end in demo mode, the placeholder admin token is gone, the sign-in screen no longer hides errors, and the template test is replaced by 16 real tests.

Known gaps, in rough priority order:

1. **`backend/PullPrintingBackend.csproj` is empty**, so `dotnet build` fails. It needs a `Microsoft.NET.Sdk.Web` project that references `Microsoft.Identity.Client`.
2. **Real Microsoft sign-in is untested.** `HttpPrintRepository` now calls `MsAuthService.init()` before `login()`, but `msal_flutter` supports only Android and iOS, so the printer panel on Windows or Linux needs another approach (device code flow is the plan, see `docs/05-open-decisions.md`). The signed-in user's name is not read from the token yet.
3. **`AzureAuthService.ValidateToken` always returns `true`.** Real JWT validation against your tenant is required before this is exposed anywhere.
4. **Endpoints are not protected.** `AdminController` and `JobsController` have no authorization, and the user id comes from the request body.
5. **State is in memory.** Jobs and users live in lists and reset on restart. `ApplicationDbContext` is an empty placeholder.
6. **Frontend and backend do not match.** The app calls `localhost:3000/jobs`, `/jobs/held`, `/jobs/release`, while the .NET API exposes `/api/jobs` and `/api/jobs/release`. There is no "my held jobs", "my quota" or "list users" route, so with `USE_MOCK=false` the quota ring is hidden and the admin user list is empty.
7. **No job submission path.** Nothing creates a held job yet.
8. **Printing is Windows only.** `PrintService` uses `System.Printing`.
9. **Duplicate MSAL wrappers.** `MsAuthService.dart` and `msal_flutter.dart` (`MsalService`) overlap. Keep one.
10. **Placeholders to replace:** the Pull Print mark, the printer illustration, drawn document thumbnails (use real first-page previews) and the drawn Microsoft mark (use Microsoft's asset). See `docs/04-design-guidelines.md`.
11. **Staff card sign-in and the phone sign-in code screen** are designed but not built.

## Roadmap

- [ ] Fill in the `.csproj` and get `dotnet run` working
- [x] Redesigned UI, demo mode and tests
- [ ] Complete and test Microsoft sign-in on a device
- [ ] Validate Entra ID tokens and add `[Authorize]` with an admin role
- [ ] Persist users, jobs and quotas with EF Core
- [ ] Add a job submission path and a "my held jobs" endpoint
- [ ] Align frontend routes with the API
- [ ] Card login at the printer
- [ ] Real tests

## Author

Built by [Yusuf (Hikki-dev)](https://github.com/Hikki-dev).
