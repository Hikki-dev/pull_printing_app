# 08 Review and fixes

A review of the demo from each kind of user's point of view, what went wrong or could go wrong, and what was done about it. "How it was found" says whether the problem came from reading the code, from an automated test, or from running the real app in a browser.

## Fixed

### First-time visitor
| What went wrong | Why it mattered | How it was found | Fix |
|---|---|---|---|
| The web page was still the Flutter template: tab title "pull_printing_app", description "A new Flutter project.", Flutter's icons | The first thing every visitor sees, and what link previews show | Reading the deployed page | Real title, description, link preview text, brand icons and manifest (`web/`) |
| A blank white page for several seconds while about 8 MB loads | Looks broken | Reading the page source | A branded loading screen that disappears at the first frame |
| The manifest locked the app to portrait | The printer panel is landscape | Reading the manifest | `orientation: any` |
| "Sign in with Microsoft" in the demo suggested a Microsoft account is needed | Visitors may hesitate or give up | Review | "No account needed. You get your own sample documents, and nothing is really printed." |
| A visitor who printed everything had no way back to the start | Stuck with an empty list | Review | **Start over** in the "What is this?" dialog |

### Large text and small screens
| What went wrong | How it was found | Fix |
|---|---|---|
| At 1.5 times text size on a phone, **the Sign in button was pushed below the screen** with nothing to say it was there | Automated test at 1.5x text | Sign-in layout shrinks the printer picture, drops the step cards and adapts to text size |
| The Microsoft button text, the pages-left ring, the confirmation row and the panel's left column overflowed at large text | Same test, then 2x and the panel at 1.3x | Text wraps or scales down inside fixed shapes; document cards grow with text size |
| A 360 by 640 phone with the demo banner pushed Sign in off screen | Automated test | Compact sign-in layout |

### Someone using the printer panel
| What went wrong | Fix |
|---|---|
| A person could walk away leaving their documents on a shared screen | The panel signs out after 60 seconds without a touch, with a message saying why. Any touch restarts the count |

### Someone with a long document or few pages left
| What went wrong | Fix |
|---|---|
| "Untick one" when only one document is chosen made no sense | "This document needs 28 pages. You have 8 left." |
| Zero pages left gave the same message as being a few pages over | "No pages left this month." |
| Ticking each document by hand to print everything | **Select all** and **Clear** |
| Nowhere to go from a quota block in the demo | A demo tip points to the administrator demo, where limits can be raised |

### When printing does not go as expected
| What went wrong | How it was found | Fix |
|---|---|---|
| The app assumed every chosen document printed, even if the server said only some did | Review of the API contract | The app uses the server's list of what printed, and says which documents are still waiting |
| If nothing printed, the person got a raw error | Review | A plain message, and they stay on their list |
| A list that was out of date ("documents are not waiting") left the person confused | Review | The message says the list was refreshed, and it is |
| Hitting the rate limit showed "error 429" | Review | "Too many requests. Please wait a minute and try again." |
| A session that ended (server restart, 8 hours) looked like "cannot reach the server" | Browser run | The person is signed out with "Your session has ended" |

### Privacy and safety
| What went wrong | How it was found | Fix |
|---|---|---|
| The demo administrator's list showed **every visitor's documents**, against the promise that nobody else can see yours | Browser run with two visitors and an administrator | Every demo administrator gets a private copy of the sample people, and can only reach their own group |
| An unexpected server error could return details | Review | Always a short JSON error, details only in the server log |
| No basic security headers | Review | `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `frame-ancestors 'none'` |
| No limit on request size or on how many documents one request names | Review | 16 KB bodies, at most 50 documents, repeats counted once |
| A sample document that was just printed came straight back as the next sample | Browser run | New documents first |

## Known and not fixed

Each one is a GitHub issue.

- Work-account sign-in (Microsoft and Google) has not been run against a real tenant. [#2](https://github.com/Hikki-dev/pull_printing_app/issues/2)
- Data is in memory only. [#3](https://github.com/Hikki-dev/pull_printing_app/issues/3)
- There is no way to send your own file. [#4](https://github.com/Hikki-dev/pull_printing_app/issues/4)
- Nothing is really printed. [#5](https://github.com/Hikki-dev/pull_printing_app/issues/5)
- Staff-card sign-in and the phone code sign-in from the mockups are not built. [#6](https://github.com/Hikki-dev/pull_printing_app/issues/6)
- The Pull Print mark, printer picture, thumbnails and Microsoft and Google marks are placeholders. [#7](https://github.com/Hikki-dev/pull_printing_app/issues/7)
- The browser Back button leaves the demo instead of going to the previous screen. [#8](https://github.com/Hikki-dev/pull_printing_app/issues/8)
- The app is light-only, English-only, and has not been checked with a screen reader on a real device. [#9](https://github.com/Hikki-dev/pull_printing_app/issues/9)
- Limits are per address, so a whole room behind one network address shares them. (Noted in [SECURITY.md](../SECURITY.md).)

## How to repeat this review

1. `dotnet test backend.Tests` and `flutter test` (the large-text, small-screen and idle tests are in `test/widget_test.dart`).
2. Build the web app, serve it, and click through it in a browser as a visitor, a visitor who runs out of pages, and an administrator.
3. Try 1.5 times and 2 times text size on a phone, and the panel at 1024 by 600.
