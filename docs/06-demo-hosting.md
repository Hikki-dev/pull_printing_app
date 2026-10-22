# 06 Hosting the demo

How to put the demo online for free so anyone with the link can try it.

## What you get

One address that serves the web app and the API together. Each visitor signs in to a private sandbox with sample documents. Nothing is printed, nothing is kept for long, and nobody can see anyone else's documents.

## Option 1: Render (free plan)

1. Create a free account at [render.com](https://render.com) and connect your GitHub account.
2. Choose **New**, then **Blueprint**, and pick this repository. Render reads `render.yaml` and sets everything up: one web service, built from the `Dockerfile`, with a generated signing key.
3. Wait for the first build. It builds the web app and the API, so it takes several minutes.
4. Open the address Render gives you. Share it.

To update the demo, push to the branch Render watches. It rebuilds on its own (`autoDeploy`).

## Option 2: any host that runs a Docker image

The `Dockerfile` works anywhere that runs a container and tells it which port to use through the `PORT` environment variable.

```bash
docker build -t pull-print-demo .
docker run -p 8080:8080 -e Demo__SigningKey="$(openssl rand -base64 48)" pull-print-demo
```

Then open `http://localhost:8080`.

## Settings

Set these as environment variables on the host. Double underscores stand for the colon in the setting name.

| Variable | Default | What it does |
|---|---|---|
| `Demo__Enabled` | `true` in the image | Lets visitors sign in to a sandbox. `false` turns demo sign-in off and invalidates demo tokens |
| `Demo__SigningKey` | random at start | At least 32 characters. Set it so visitors stay signed in when the server restarts. The Render blueprint generates one |
| `RateLimit__LoginPerMinute` | `20` | Sign-ins per minute from one address |
| `RateLimit__PerMinute` | `300` | All requests per minute from one address |
| `AzureAd__TenantId`, `AzureAd__ClientId` | empty | Turns on Microsoft sign-in. See the README |
| `AzureAd__AdminRole` | `PullPrint.Admin` | App role that makes someone an administrator |
| `Cors__AllowAnyOrigin` | `false` | Only needed if the web app is served from a different address |

## What to expect from a free host

- **It sleeps when idle.** Free plans usually stop a service after a quiet period. The first visitor afterwards waits a minute or so while it wakes up. The banner and sign-in screen load first, and sign-in works once it is up.
- **It forgets when it sleeps or restarts.** Data is in memory. A visitor who comes back after a restart is signed in again with fresh sample documents, or sees "Your session has ended" and signs in again. That is expected.
- **Limits can change.** Check the host's current free-plan terms before relying on it.

## Checking it works

Open `/healthz` on your address. It should answer `{"status":"ok"}`. Then open the address, sign in, and press Print. The pages-left figure should go down.

## Things to know before sharing the link widely

- Anyone with the link can sign in. That is the point of a demo, so keep real data out of it.
- Sign-in and request limits are per address. Many people behind one office or school network share a limit, which is generous for normal use but can be hit by a classroom all signing in at once.
- The app trusts the host's proxy to say who is calling, which is right for Render and similar hosts. If you put it behind something else, check that it sets `X-Forwarded-For`.
- The Microsoft logo on the sign-in button is drawn to Microsoft's rules. Replace it with Microsoft's own asset before any public launch.

## Option 3: Vercel (static, no server)

The simplest free option needs no server at all. In this mode the app runs on its built-in sample data inside the visitor's browser, so every visitor already has their own private copy and nothing sleeps.

- `vercel.json` and `scripts/vercel-build.sh` build the web app with `USE_MOCK=true`. Connect the repository to a Vercel project and it builds on every push.
- Data lives in the browser tab and resets when the page is reloaded.
- There is no API in this mode, so nothing can be shared between visitors and the administrator view only shows the built-in sample people.
- Use Option 1 or 2 when you want to show the real API.
