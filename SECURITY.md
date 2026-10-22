# Security

## Reporting a problem

Please **do not open a public issue** for a security problem. Use GitHub's private reporting instead: on the repository page choose **Security**, then **Report a vulnerability**. Say what you found, how to reproduce it, and what it lets someone do.

You will get an answer as soon as someone can look at it. This is a demo project maintained by one person, so there is no promised response time.

## What this project is, and is not

This is a **demo**. Its hosted version lets anyone sign in to a private sandbox of sample data. Do not put real documents, real people or real printers behind it.

## What is protected

- Every route except sign-in and `/healthz` needs a valid signed token.
- People only reach their own waiting documents. Administrators only reach people in their own group.
- Printing is checked against the person's page quota on the server.
- Demo sign-in is rate limited, sandboxes are capped and deleted after two hours idle, and request bodies are limited to 16 KB.
- Replies carry basic security headers, and unexpected errors never return details.

## What is not done yet

- Microsoft Entra ID token validation is written but **has not been tested against a real tenant**.
- Data is in memory only, with no encryption at rest because there is nothing at rest.
- Limits are per network address and trust the host's `X-Forwarded-For` header, which is right behind Render or similar hosts and wrong anywhere that does not set it.
- No audit log.

## Settings that matter

| Setting | What to do |
|---|---|
| `Demo__Enabled` | Turn **off** for anything that is not a demo. Its tokens stop working immediately |
| `Demo__SigningKey` | Set to a long random value (32 characters or more) and keep it secret |
| `AzureAd__TenantId`, `AzureAd__ClientId` | Set both to enable Microsoft sign-in |

`frontend/lib/services/MsAuthService.dart` contains a tenant id and client id. These are identifiers, not secrets, but they belong to a specific app registration. Replace them with your own.
