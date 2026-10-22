# 07 Architecture and API

How the pieces fit, what the server decides, and every route with an example.

## The pieces

![A person sends a document, the server holds it, they sign in at the printer and press Print, the server checks their pages and sends it to the printer](images/how-it-fits.svg)

In detail:

```
Visitor's browser or phone
   │
   ▼
Flutter app (frontend/lib)
   screens ── PrintRepository ─┬─ MockPrintRepository    sample data inside the app (offline demo, tests)
                               └─ HttpPrintRepository ──▶ ApiService ──▶ HTTPS
                                                                          │
ASP.NET Core API (backend)                                                ▼
   controllers: Auth · Printers · Jobs · Admin ── PrintStore (in memory) ── IPrintDispatcher (simulated)
   sign-in: demo sandbox, or Microsoft / Google work account (OpenID Connect, done by the server)
   session: one kind of server-signed token, whichever way the person signed in
   limits: rate limits, size limits, sandbox caps
```

There are two ways to run the demo:

| | Static (Vercel) | Full stack (Docker, for example Render) |
|---|---|---|
| What runs | The Flutter web app on built-in sample data | The API and the web app together |
| Where data lives | In the visitor's browser tab | In the server's memory, one private sandbox per visitor |
| Resets when | The page is reloaded | The server restarts, or 2 hours without use |
| Needs a server | No | Yes |
| Shows the real API and its rules | No | Yes |

## Who decides what

The app only shows things. **The server decides** who may do what, so a changed or hand-made request cannot get around the rules.

| Rule | Where it is enforced |
|---|---|
| You need a valid, unexpired, correctly signed token | `Program.cs` (JWT bearer authentication) |
| Admin routes need the Admin role | `AdminController`, `JobsController.All` (policy `Admin`) |
| You only ever see and print your own waiting documents | `PrintStore.HeldJobs`, `PrintStore.Release` |
| Printing never takes you over your page quota | `PrintStore.Release` (all or nothing) |
| An administrator only reaches people in their own group | `PrintStore.AllJobs`, `Users`, `SetQuota` |
| Quota changes are between 0 and 10000 pages | `AdminController` (`set-quota`, `default-quota`, `set-quota-all`) |
| Only people from your organisation sign in | `WorkspaceIdentity.Map` (tenant, domain, verified email) |
| Administrators are decided by the server | `Workspace__Admins`, or the Microsoft app role; never by the app |
| Pages start again each month | `PrintStore` (period = UTC year and month) |
| Printing only goes to a printer in your own group that is on | `PrintStore.Release` |
| At most 50 documents per print, 12 waiting per person | `JobsController.Release`, `PrintStore.AddSample` |

## Data

- **PrintJob**: `id`, `userId`, `userName`, `fileName`, `pages`, `submittedAt`, `status` (`Held`, `Printed` or `Failed`), `failureReason`, `printerName` (once printed).
- **User**: id (`g-…` for Google, `m-…` for Microsoft), display name, email, whether an administrator, page quota, pages used and the month they belong to, last seen, and a **sandbox id**.
- **Printer**: `id`, `name`, `location`, `enabled`. Kept per sandbox, so a work organisation has one list and each demo visitor has their own three.
- **Sandbox**: who can see and manage whom. Everyone who signs in for real shares the `default` group. Each demo visitor, and each demo administrator, gets a private one. A demo administrator's sandbox holds a private copy of four sample people.

## Signing in

**Demo.** `POST /api/auth/demo-login` creates a sandbox and returns a token signed by the server. It exists only when `Demo__Enabled` is true, and its tokens stop working the moment that is switched off.

**Work account (Microsoft 365 or Google Workspace).** When the `Workspace__*` settings are complete the server does the whole sign-in, so the app holds no secrets:

1. The app sends the browser to `GET /api/auth/login?returnTo=/…`. The server redirects to Microsoft or Google (authorization code flow with PKCE, `prompt=select_account`).
2. The provider sends the browser back to `/api/auth/callback`. The server exchanges the code, then checks who it is (`WorkspaceIdentity.Map`): the right organisation, a verified email for Google, the right domain.
3. `GET /api/auth/complete` adds the person if new (default pages a month), decides if they are an administrator, issues the server's own token and redirects to `returnTo#token=…`. A refused account goes to `returnTo#error=<code>` with `wrong_account`, `unverified_email`, `no_identity` or `sign_in_failed`.
4. The page keeps the fragment for the app and removes it from the address bar before the app starts. `returnTo` must be a path on this site, so sign-in cannot be used to send people elsewhere.

Whatever way someone signed in, the token carries the same claims (`uid`, `name`, `role`, `kind`) and nothing else in the server cares which it was. Turning work sign-in or demo sign-in off makes that kind of token stop working at once. Setup steps: [09](09-connecting-your-workspace.md).

## Errors

Errors are JSON: `{ "error": "<code>", "message": "<words for a person>", "pagesOver": <number, only for quota> }`.

| Status | `error` | When |
|---|---|---|
| 400 | `no_jobs`, `too_many`, `bad_request` | Nothing chosen, more than 50 documents, an invalid quota |
| 401 | | No token, or one that is wrong or expired. The app signs the person out with a message |
| 403 | | Signed in but not allowed, for example a normal user on an admin route |
| 404 | `not_found` | Documents that are not yours or not waiting, an unknown person, or demo sign-in switched off |
| 409 | `quota_exceeded` | The documents need more pages than the person has left. Nothing prints |
| 409 | `no_printer`, `printer_unavailable` | No printer is set up, or the chosen one is off or unknown. Nothing prints |
| 409 | `too_many` | At most 50 printers |
| 409 | `no_more_samples` | Demo only: twelve documents are already waiting, or all sample documents are in use |
| 429 | | Too many requests from one address in a minute |
| 500 | `server_error` | Something unexpected. The details stay in the server log |

## Routes

All routes except sign-in and `/healthz` need `Authorization: Bearer <token>`.

### `GET /api/auth/config`
No token. What the sign-in screen offers.
```json
{ "provider": "google", "providerName": "Google", "domain": "example.com", "demo": false }
```
`provider` is `microsoft`, `google` or `none`.

### `POST /api/auth/demo-login`
```json
// request
{ "admin": false }
// 200
{ "token": "eyJ…", "userId": "demo-3f9a1c2b", "name": "Alice Tan", "isAdmin": false }
```

### `GET /api/auth/me`
```json
{ "userId": "demo-3f9a1c2b", "name": "Alice Tan", "isAdmin": false, "email": null }
```

### `GET /api/printers`
```json
[ { "id": "a190fbb8", "name": "Level 3 East", "location": "Third floor, east wing", "enabled": true } ]
```
Switched-off printers are listed only for administrators.

### `GET /api/jobs/held`
Your waiting documents, newest first.
```json
[ { "id": "a1b2c3d4", "userId": "demo-3f9a1c2b", "userName": "Alice Tan",
    "fileName": "Q3 budget review.pdf", "pages": 12,
    "submittedAt": "2026-10-22T09:00:00+00:00", "status": "Held", "failureReason": null } ]
```

### `GET /api/jobs/quota`
```json
{ "used": 12, "total": 50, "left": 38 }
```

### `POST /api/jobs/release`
```json
// request: send jobIds (a single jobId is also accepted). printerId is optional;
// without it the first printer that is on is used
{ "jobIds": ["a1b2c3d4", "e5f6a7b8"], "printerId": "a190fbb8" }
// 200: only the documents that really printed are listed
{ "printed": ["a1b2c3d4", "e5f6a7b8"], "pages": 15, "quota": { "used": 27, "total": 50, "left": 23 }, "printerName": "Level 3 East" }
// 409: nothing printed, nothing charged
{ "error": "quota_exceeded", "message": "Over your limit by 6 pages.", "pagesOver": 6 }
```

### `POST /api/jobs/sample` (demo only)
Adds one sample document to your list and returns it. 409 `no_more_samples` when there are no more to add.

### `GET /api/jobs` (administrators)
Every job in the administrator's own group, newest first.

### `GET /api/admin/setup` (administrators)
What the **Setup** card shows.
```json
{ "provider": "Google", "providerName": "Google", "domain": "example.com", "demoEnabled": false,
  "defaultQuota": 50, "people": 12, "printers": 0,
  "redirectUri": "https://print.example.com/api/auth/callback",
  "warnings": ["No printers yet. Add one so people can print."] }
```
`redirectUri` is the address to register with Microsoft or Google. `warnings` is empty when nothing is left to do.

### `GET /api/admin/users` (administrators)
```json
[ { "userId": "…", "name": "Priya Nair", "email": null, "quota": { "used": 8, "total": 200, "left": 192 } } ]
```

### `POST /api/admin/set-quota` (administrators)
```json
{ "userId": "…", "quota": 80 }
```
200 on success, 404 if that person is not in the administrator's group, 400 if the number is outside 0 to 10000.

### `POST /api/admin/default-quota`, `POST /api/admin/set-quota-all` (administrators)
```json
{ "quota": 80 }
```
`default-quota` sets the pages a month for people who sign in from now on. `set-quota-all` gives everyone in the group the same pages and replies `{ "changed": 12 }`. Both are 400 outside 0 to 10000.

### `POST /api/admin/printers`, `PUT /api/admin/printers/{id}`, `DELETE /api/admin/printers/{id}` (administrators)
```json
{ "name": "Level 3 East", "location": "Third floor", "enabled": true }
```
`name` is required (up to 60 characters). `enabled` applies to `PUT`. Up to 50 printers. 404 for an unknown printer.

### `GET /healthz`
`{ "status": "ok" }`, no token needed. Used by hosts to check the server is up.

## Settings

Environment variables, with double underscores for the colon in a setting name.

| Variable | Default | What it does |
|---|---|---|
| `Demo__Enabled` | `false` (`true` in the Docker image) | Allows demo sign-in and sample documents |
| `Auth__SigningKey` | random at start | 32 or more characters. Set it so tokens survive a restart |
| `Workspace__Provider` | empty | `Microsoft` or `Google`. Turns on work-account sign-in |
| `Workspace__ClientId`, `__ClientSecret` | empty | From the app registration or OAuth client |
| `Workspace__TenantId` | empty | Microsoft only: the directory id |
| `Workspace__Domain` | empty | Required for Google. Optional for Microsoft: limits sign-in to one email domain |
| `Workspace__Admins` | empty | Administrator email addresses, separated by commas or spaces |
| `Workspace__AdminRole` | `PullPrint.Admin` | Microsoft app role that also makes an administrator |
| `Workspace__DefaultQuota` | `50` | Pages a month for a first sign-in. Changeable on the administrator screen |
| `RateLimit__LoginPerMinute` | `20` | Demo sign-ins a minute from one address |
| `RateLimit__PerMinute` | `300` | All requests a minute from one address |
| `Cors__AllowAnyOrigin` | `false` | Only for running the web app from a different address |

Other limits are fixed in code: 300 sandboxes at once, sandboxes deleted after 2 hours idle, 16 KB request bodies.

## Replacing the in-memory parts

- **A database:** implement `IPrintStore` (`backend/services/PrintStore.cs`) and register it in `Program.cs`. The tests in `backend.Tests` describe the behaviour to keep.
- **A real printer:** implement `IPrintDispatcher` (`backend/services/PrintDispatcher.cs`). Throw from `Print` to mark a job as failed; the message becomes the reason shown to administrators.
- **Groups and directory:** quotas are per person. Per-group limits would read the Microsoft Graph or Google Admin SDK and are not built.
- **Sending files:** nothing creates a waiting job except the demo sample route. Real submission is an open decision in [05](05-open-decisions.md).
