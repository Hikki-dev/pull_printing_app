# 07 Architecture and API

How the pieces fit, what the server decides, and every route with an example.

## The pieces

```
Visitor's browser or phone
   │
   ▼
Flutter app (frontend/lib)
   screens ── PrintRepository ─┬─ MockPrintRepository    sample data inside the app (offline demo, tests)
                               └─ HttpPrintRepository ──▶ ApiService ──▶ HTTPS
                                                                          │
ASP.NET Core API (backend)                                                ▼
   controllers: Auth · Jobs · Admin ── PrintStore (in memory) ── IPrintDispatcher (simulated)
   authentication: demo tokens, or Microsoft Entra ID tokens
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
| Quota changes are between 0 and 10000 pages | `AdminController.SetQuota` |
| At most 50 documents per print, 12 waiting per person | `JobsController.Release`, `PrintStore.AddSample` |

## Data

- **PrintJob**: `id`, `userId`, `userName`, `fileName`, `pages`, `submittedAt`, `status` (`Held`, `Printed` or `Failed`), `failureReason`.
- **User**: id, display name, whether an administrator, page quota, pages used, last seen, and a **sandbox id**.
- **Sandbox**: who can see and manage whom. Everyone who signs in for real shares the `default` group. Each demo visitor, and each demo administrator, gets a private one. A demo administrator's sandbox holds a private copy of four sample people.

## Signing in

**Demo.** `POST /api/auth/demo-login` creates a sandbox and returns a token signed by the server. It exists only when `Demo__Enabled` is true, and its tokens stop working the moment that is switched off.

**Microsoft Entra ID.** Set `AzureAd__TenantId` and `AzureAd__ClientId`. The server then also accepts Microsoft tokens, checked against your tenant's published keys, with your client id (or `api://<client id>`) as the audience. People with the `PullPrint.Admin` app role are administrators. Written but **not yet tested against a real tenant**.

Both kinds of token are turned into the same three claims (`uid`, `name`, `role`), so nothing else in the server cares which one was used.

## Errors

Errors are JSON: `{ "error": "<code>", "message": "<words for a person>", "pagesOver": <number, only for quota> }`.

| Status | `error` | When |
|---|---|---|
| 400 | `no_jobs`, `too_many`, `bad_request` | Nothing chosen, more than 50 documents, an invalid quota |
| 401 | | No token, or one that is wrong or expired. The app signs the person out with a message |
| 403 | | Signed in but not allowed, for example a normal user on an admin route |
| 404 | `not_found` | Documents that are not yours or not waiting, an unknown person, or demo sign-in switched off |
| 409 | `quota_exceeded` | The documents need more pages than the person has left. Nothing prints |
| 409 | `no_more_samples` | Demo only: twelve documents are already waiting, or all sample documents are in use |
| 429 | | Too many requests from one address in a minute |
| 500 | `server_error` | Something unexpected. The details stay in the server log |

## Routes

All routes except sign-in and `/healthz` need `Authorization: Bearer <token>`.

### `POST /api/auth/demo-login`
```json
// request
{ "admin": false }
// 200
{ "token": "eyJ…", "userId": "demo-3f9a1c2b", "name": "Alice Tan", "isAdmin": false }
```

### `GET /api/auth/me`
```json
{ "userId": "demo-3f9a1c2b", "name": "Alice Tan", "isAdmin": false }
```

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
// request: send jobIds (a single jobId is also accepted)
{ "jobIds": ["a1b2c3d4", "e5f6a7b8"] }
// 200: only the documents that really printed are listed
{ "printed": ["a1b2c3d4", "e5f6a7b8"], "pages": 15, "quota": { "used": 27, "total": 50, "left": 23 } }
// 409: nothing printed, nothing charged
{ "error": "quota_exceeded", "message": "Over your limit by 6 pages.", "pagesOver": 6 }
```

### `POST /api/jobs/sample` (demo only)
Adds one sample document to your list and returns it. 409 `no_more_samples` when there are no more to add.

### `GET /api/jobs` (administrators)
Every job in the administrator's own group, newest first.

### `GET /api/admin/users` (administrators)
```json
[ { "userId": "…", "name": "Priya Nair", "quota": { "used": 8, "total": 200, "left": 192 } } ]
```

### `POST /api/admin/set-quota` (administrators)
```json
{ "userId": "…", "quota": 80 }
```
200 on success, 404 if that person is not in the administrator's group, 400 if the number is outside 0 to 10000.

### `GET /healthz`
`{ "status": "ok" }`, no token needed. Used by hosts to check the server is up.

## Settings

Environment variables, with double underscores for the colon in a setting name.

| Variable | Default | What it does |
|---|---|---|
| `Demo__Enabled` | `false` (`true` in the Docker image) | Allows demo sign-in and sample documents |
| `Demo__SigningKey` | random at start | 32 or more characters. Set it so tokens survive a restart |
| `AzureAd__TenantId`, `AzureAd__ClientId` | empty | Turns on Microsoft sign-in |
| `AzureAd__AdminRole` | `PullPrint.Admin` | App role that makes someone an administrator |
| `RateLimit__LoginPerMinute` | `20` | Demo sign-ins a minute from one address |
| `RateLimit__PerMinute` | `300` | All requests a minute from one address |
| `Cors__AllowAnyOrigin` | `false` | Only for running the web app from a different address |

Other limits are fixed in code: 300 sandboxes at once, sandboxes deleted after 2 hours idle, 16 KB request bodies.

## Replacing the in-memory parts

- **A database:** implement `IPrintStore` (`backend/services/PrintStore.cs`) and register it in `Program.cs`. The tests in `backend.Tests` describe the behaviour to keep.
- **A real printer:** implement `IPrintDispatcher` (`backend/services/PrintDispatcher.cs`). Throw from `Print` to mark a job as failed; the message becomes the reason shown to administrators.
- **Sending files:** nothing creates a waiting job except the demo sample route. Real submission is an open decision in [05](05-open-decisions.md).
