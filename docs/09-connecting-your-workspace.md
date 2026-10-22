# 09 Connecting your workspace

How to make Pull Print use your organisation's own accounts, so people sign in with the work account they already have, and you control the printers and each person's pages from one screen.

Pick the one you use. It takes about ten minutes, and you do it once.

> **Honest status.** The sign-in is built and tested against a **simulated** Microsoft/Google sign-in (the whole round trip, including refusing the wrong organisation). It has **not been run against a real tenant**, because that needs your account. Follow the steps below on a test tenant first. If something does not work, the **Setup** card on the administrator screen says what is missing, and [issue #2](https://github.com/Hikki-dev/pull_printing_app/issues/2) is where to report it.

## How it works, in one picture

```
Person ──▶ "Sign in with Microsoft / Google" ──▶ their normal work sign-in
                                                       │
Pull Print server ◀── who they are (checked here) ─────┘
   │
   ├─ is this person from our organisation?      no  ─▶ turned away, with a reason
   ├─ new here? ─▶ added, with the default pages a month
   ├─ on the administrators list? ─▶ gets the administrator screen
   └─ shows only their own documents; prints only on printers you added
```

Two things live on the server, so there is one place to manage them:

- **Printers.** You add each printer once (name and place). People pick one, or the printer's own screen is fixed to it.
- **People and pages.** Everyone appears the first time they sign in with the default pages a month. You change one person, or everyone, from the administrator screen. Pages start again on the 1st of each month (UTC).

## What you need

| | Microsoft 365 / Entra ID | Google Workspace |
|---|---|---|
| An account that can register apps | Application Administrator, or Global Administrator | Super admin of a Google Cloud project |
| The address people use | `https://<your-host>` | `https://<your-host>` |
| What you copy out | Application (client) ID, Directory (tenant) ID, a client secret | Client ID and client secret, and your domain such as `example.com` |

`<your-host>` is where you run the server (for example the Render address, or your own domain). It must be **https**.

## Microsoft 365 (Entra ID)

1. Open the **Microsoft Entra admin centre**, then **App registrations**, **New registration**.
2. Name it `Pull Print`. Under supported account types choose **Accounts in this organizational directory only**.
3. Under **Redirect URI** choose **Web** and enter `https://<your-host>/api/auth/callback`. Register.
4. On the overview page copy the **Application (client) ID** and the **Directory (tenant) ID**.
5. Go to **Certificates & secrets**, **New client secret**, and copy the secret's **Value** now (it is shown once).
6. *(Optional, to make administrators without a list)* Under **App roles** create a role with value `PullPrint.Admin` for **Users/Groups**, then assign it to your administrators under **Enterprise applications**, **Users and groups**.
7. Set these on the server (see [Settings](#settings)):

   ```
   Workspace__Provider=Microsoft
   Workspace__TenantId=<directory id>
   Workspace__ClientId=<application id>
   Workspace__ClientSecret=<secret value>
   Workspace__Admins=you@yourcompany.com
   ```

Only accounts from that tenant can sign in. To allow just one email domain inside it, also set `Workspace__Domain=yourcompany.com`.

## Google Workspace

1. Open the **Google Cloud console**, create or pick a project, then **APIs & Services**, **OAuth consent screen**. Choose **Internal** (only your Workspace organisation can sign in). Fill in the app name `Pull Print` and your support email.
2. Go to **Credentials**, **Create credentials**, **OAuth client ID**. Type **Web application**.
3. Under **Authorized redirect URIs** add `https://<your-host>/api/auth/callback`. Create.
4. Copy the **Client ID** and **Client secret**.
5. Set these on the server:

   ```
   Workspace__Provider=Google
   Workspace__ClientId=<client id>
   Workspace__ClientSecret=<client secret>
   Workspace__Domain=example.com
   Workspace__Admins=you@example.com
   ```

`Workspace__Domain` is **required** for Google. Without it any Google account could sign in, so the server refuses to turn Google sign-in on.

## Settings

Set these as environment variables on the host. Double underscores stand for the colon.

| Setting | Needed | What it does |
|---|---|---|
| `Workspace__Provider` | yes | `Microsoft` or `Google`. Leave empty for the demo only |
| `Workspace__ClientId` | yes | From the app registration or OAuth client |
| `Workspace__ClientSecret` | yes | Keep it secret. Never put it in the app or in Git |
| `Workspace__TenantId` | Microsoft | The directory (tenant) id |
| `Workspace__Domain` | Google: yes. Microsoft: optional | Only addresses ending `@domain` get in |
| `Workspace__Admins` | recommended | Email addresses of administrators, separated by commas or spaces |
| `Workspace__AdminRole` | no | Microsoft app role that also makes an administrator. Default `PullPrint.Admin` |
| `Workspace__DefaultQuota` | no | Pages a month for someone signing in for the first time. Default 50. Changeable on the administrator screen |
| `Auth__SigningKey` | **yes for real use** | At least 32 random characters. Without it everyone is signed out whenever the server restarts |
| `Demo__Enabled` | set to `false` | Turns the sample-data demo off. Leaving it on lets anyone on the internet open a sandbox |

Generate a signing key with `openssl rand -base64 48`.

## First sign-in: set up in four steps

1. Open `https://<your-host>` and sign in with an account in `Workspace__Admins`. You land on the **administrator** screen.
2. Read the **Setup** card at the top. It lists anything still to do in plain words, and shows the exact sign-in address to register. When nothing is left it says **Setup is complete**.
3. **Printers**: press **Add a printer** for each one (name, and where it is). Use **Copy panel link** to get that printer's own address.
4. **People and quotas**: set **New people start with** to your usual pages a month. People appear in the list as they first sign in. Use **Give everyone** to set the same number for the whole organisation at once, or set one person on their row.

## At the printer

Open the printer's **panel link** (`https://<your-host>/?printer=<id>`) on the screen next to the printer, in full screen. It is fixed to that printer, so people sign in, see their documents, and press **Print**, with no question about which printer. It signs people out after 60 seconds without a touch, and asks which account to use each time so the next person is never signed in as the last.

On a phone, the same address without `?printer=` lets the person pick a printer.

## When someone cannot sign in

| They see | Why | What to do |
|---|---|---|
| "That account is not allowed here" | Wrong organisation or domain, or a personal account | Sign in with the work account. Check `Workspace__TenantId` / `Workspace__Domain` |
| "Your email address is not verified" | Google says the address is not verified | Verify it in the Google account |
| "Your account did not tell us who you are" | The provider sent no identity | Check the app registration, then ask support |
| "Sign-in did not work" | The provider or the server failed | Try again. Check the server log and that the redirect address matches exactly |
| Sign-in button missing, only a demo | Settings incomplete | Open the server's `/api/auth/config`, or read the log: it names the missing setting |

## Security notes

- The provider's sign-in happens on Microsoft's or Google's own page. Pull Print never sees a password.
- The server then issues its own 8-hour session token. It reaches the app in the address after `#` and is removed from the address bar before the app starts, so it is not left in the browser history.
- The client secret stays on the server.
- Only your organisation can sign in. People only ever see their own documents, and quota is checked on the server.
- Administrators are decided by the server (the `Workspace__Admins` list or the app role). The app cannot grant it.
- Someone who is removed from your organisation can still use a session already issued, for up to 8 hours. Removing them from `Workspace__Admins` takes effect at their next sign-in.

## What is not built yet

- **Groups and departments.** Quotas are per person, with a default and "everyone". Setting pages by group (for example a Microsoft 365 group or a Google Workspace organisational unit) needs the directory APIs. Tracked in an issue.
- **Real printers and sending files.** Printers here are names the server prints to through `IPrintDispatcher`, which is simulated. See [05](05-open-decisions.md) and the open issues.
- **Native phone sign-in** with the platform's own account picker. The web app works on phones today.
- **A database.** People, printers and quotas are held in memory and are lost when the server restarts. Production needs `IPrintStore` backed by a database (issue #3).
