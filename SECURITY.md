# Security

## Reporting a problem

Please **do not open a public issue** for a security problem. Use GitHub's private reporting instead: on the repository page choose **Security**, then **Report a vulnerability**. Say what you found, how to reproduce it, and what it lets someone do.

You will get an answer as soon as someone can look at it. This is a demo project maintained by one person, so there is no promised response time.

## What this project is, and is not

This is a **demo**. Its hosted version lets anyone sign in to a private sandbox of sample data. Do not put real documents, real people or real printers behind it.

## What is protected

- Every route except sign-in, the sign-in options and `/healthz` needs a valid signed token.
- People only reach their own waiting documents. Administrators only reach people in their own group.
- Printing is checked against the person's page quota on the server.
- Demo sign-in is rate limited, sandboxes are capped and deleted after two hours idle, and request bodies are limited to 16 KB.
- Work-account sign-in uses the authorization code flow with PKCE, only accepts people from your organisation, and sends the session token back after `#` so it is not sent to any server or left in the history.
- Replies carry basic security headers, and unexpected errors never return details.

## What is not done yet

- Microsoft and Google work-account sign-in is tested against a simulated provider only. It **has not been run against a real tenant**.
- A session token lasts 8 hours and cannot be revoked early. Someone removed from your organisation keeps access until it ends.
- Data is in memory only, with no encryption at rest because there is nothing at rest.
- Limits are per network address and trust the host's `X-Forwarded-For` header, which is right behind Render or similar hosts and wrong anywhere that does not set it.
- No audit log.

## Settings that matter

| Setting | What to do |
|---|---|
| `Demo__Enabled` | Turn **off** for anything that is not a demo. Its tokens stop working immediately |
| `Auth__SigningKey` | Set to a long random value (32 characters or more) and keep it secret. Without it everyone is signed out on every restart |
| `Workspace__Provider`, `__ClientId`, `__ClientSecret`, `__TenantId`, `__Domain` | Turn on Microsoft or Google sign-in. See [docs/09](docs/09-connecting-your-workspace.md). The client secret belongs only on the server |
| `Workspace__Admins` | Who is an administrator. Keep it short |

The client secret is never sent to the app. Google sign-in refuses to turn on without `Workspace__Domain`, so it cannot be left open to every Google account.
