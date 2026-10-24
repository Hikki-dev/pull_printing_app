# Fixing problems

Quick answers first, then fixes. If your problem is not here, [open an issue](https://github.com/Hikki-dev/pull_printing_app/issues/new/choose) and say what you pressed, what you saw, and what you expected.

## Quick answers

The short ones are in [Questions and answers](FAQ.md). The fixes are below.

## People printing

| You see | Why | What to do |
|---|---|---|
| **Over your limit by N pages. Untick one.** | The documents ticked need more pages than you have left | Untick a document. Your limit starts again on the 1st |
| **No pages left this month.** | You have used your pages | Ask your administrator for more, or wait for the 1st |
| **No printer available** | No printer is set up, or all are switched off | Ask your administrator to add one |
| **The printer could not print your documents. They are still waiting.** | The printer rejected them | Try again, or pick another printer. You were not charged |
| **Your list has been refreshed.** | The list on screen was out of date (for example you printed on another device) | Check the list and press Print again |
| **Your session has ended. Please sign in again.** | The session ran out (8 hours), or the server restarted | Sign in again |
| **Cannot reach the print server.** | No connection, or a free host is waking up | Wait a minute and press **Try again** |
| **Nothing waiting to print.** | You have no documents | In the demo, press **Send sample documents** |

## People signing in

| You see | Why | What to do |
|---|---|---|
| **That account is not allowed here** | Wrong organisation, wrong domain, or a personal account | Sign in with your work account |
| **Your email address is not verified** | Google says the address is not verified | Verify it in your Google account |
| **Your account did not tell us who you are** | The provider sent no identity | Tell your administrator |
| **Sign-in did not work. Please try again.** | The provider or the server failed, or you cancelled | Try again. Administrators: see below |
| Only a demo button, no work sign-in | Work sign-in is not set up, or its settings are incomplete | Administrators: see below |

## Administrators

| Problem | What to check |
|---|---|
| The Setup card lists things to do | Each line says what. They map to the settings in [Connecting your workspace](09-connecting-your-workspace.md#settings) |
| Sign-in shows only the demo | Open `/api/auth/config`. If `provider` is `none`, a `Workspace__*` setting is missing. The server log names the missing one |
| The provider says "redirect URI mismatch" | The address registered with Microsoft or Google must match exactly. The Setup card shows it, with a **Copy** button. It must be `https` |
| Everyone is signed out whenever the server restarts | Set `Auth__SigningKey` to 32 or more random characters |
| Someone who should be an administrator is not | Their email must be in `Workspace__Admins`, written as their work email. Microsoft: or assign the `PullPrint.Admin` app role. They must sign in again |
| A printer's own screen asks which printer | Open the **Copy panel link** address, not the plain address. It ends with `?printer=` and the printer's id |
| A panel link says No printer available | The printer in the link was removed or switched off |
| A person is missing from the list | People appear the first time they sign in |
| "Give everyone" changed someone I set by hand | It replaces every limit. Set their row again afterwards |
| Quota boxes refuse a number | Whole numbers from 0 to 10000 only |

## Running it

| Problem | What to do |
|---|---|
| `flutter run` shows sample data only | That is the default. For a real server pass `--dart-define=USE_MOCK=false` ([README](../README.md#run-it-yourself)) |
| The web app cannot reach the API | Build with `--dart-define=API_BASE_URL=...`, or serve the web build from the API's `wwwroot` so they share an address |
| `dotnet run` says demo sign-in is off | Set `Demo__Enabled=true`, or run with `ASPNETCORE_ENVIRONMENT=Development` |
| Sign-in works but you are bounced to sign-in at once | The signing key changed, or the server restarted. Set `Auth__SigningKey` |
| First visit to a free host is slow | Free hosts sleep when idle and take about a minute to wake |
| Tests fail on a fresh checkout | Run `flutter pub get`, then `flutter test` and `dotnet test backend.Tests`. CI runs the same |

## Still stuck?

Open an issue with the template. Say what you tried, and attach the server log with any secret removed. For anything about security, read [SECURITY.md](../SECURITY.md) first.
