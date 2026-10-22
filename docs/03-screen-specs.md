# 03 Screen specs

Seven screens. Images are the mockups in [`design/screens/`](design/screens/).

## Wording

| Avoid | Use |
|---|---|
| Release | Print |
| Held job, spooled | Waiting to print, "Your documents" |
| Quota | Pages left this month |
| Authenticate, credentials | Sign in |
| Error: 403 | A sentence that says what happened and what to do |

---

## P1 Phone: sign in

![Phone sign in](design/screens/01-phone-sign-in.png)

**Purpose:** get the person signed in, and tell a first-time user what the product does in three lines.

- One button: **Sign in with Microsoft**. Plain text, no vendor logo.
- "How it works" is three numbered steps. This is the in-app guide for new users.
- No registration, no password field. Identity comes from the work account.

## P2 Phone: waiting to print

![Phone job list](design/screens/02-phone-my-jobs.png)

**Purpose:** see own waiting documents and print the ones wanted.

- Pages-left bar at the top.
- Each job is a whole row that toggles a checkbox (72 px tall). Shows file name, page count, when it was sent.
- Selected rows have a thick blue border and a tick, so selection is not shown by colour alone.
- Bottom bar: chosen printer and one button that states what it will do, "Print 2 jobs · 15 pages".
- Sign-out is an icon button with an accessible label.

## P3 Phone: sent to printer

![Phone confirmation](design/screens/03-phone-sent.png)

**Purpose:** confirm it worked and show pages left.

- Tick, "Sent to Level 3 East", the list of what was sent, and the new pages-left figure.
- One secondary button: **Back to my jobs**.

## K1 Printer panel: sign in

![Panel sign in](design/screens/04-panel-sign-in.png)

**Purpose:** identify the person at the printer. Screen is 1024 × 600, touch.

- Left: heading and one reassurance line ("You will only see your own documents").
- Right, primary: sign in with phone. A short code is shown large; the person enters it at `microsoft.com/devicelogin` on their own phone, then taps **I have entered the code**. This is the standard Microsoft device-code sign-in, so no keyboard is needed on the panel.
- Right, secondary: tap staff card, marked "Coming later". This becomes the fast path once readers exist.
- Header shows the printer name and status so people know which printer they are at.

## K2 Printer panel: your documents

![Panel release](design/screens/05-panel-release.png)

**Purpose:** print everything with one tap. The most important screen.

- Header: name, pages left, **Sign out** (always visible).
- Rows are 64 px, whole row toggles. Documents the person sent most recently are ticked by default.
- Footer: running total ("2 documents · 15 pages"), pages left after printing, and the **Print** button (300 × 72 px, largest element).
- If the selection is over quota, the footer says by how many pages and Print is disabled.

## K3 Printer panel: printing

![Panel printing](design/screens/06-panel-printing.png)

**Purpose:** confirm and clear the session.

- "Printing 15 pages", "Collect your documents from the tray", pages left.
- **Print more** returns to K2. **Sign out** returns to K1.
- Signs out automatically after 20 seconds, with a visible message saying so.

## A1 Admin: jobs and quotas

![Admin](design/screens/07-admin.png)

**Purpose:** see everything, fix quota problems, find failed jobs.

- Four counts at the top: waiting, printed today, failed today, users out of quota.
- Jobs table with search and status filter. Status is a text label, with a failure reason where there is one.
- Users and quotas table with an editable number and **Save** per row.
- Layout is fluid. Tables scroll sideways inside their box on narrow screens.

---

## States to design next

These are described, not yet drawn.

| Screen | State | Message |
|---|---|---|
| P2, K2 | No documents | "Nothing waiting to print." Under it: "Send a file to Pull Print from your computer." |
| P2, K2 | Over quota | "This is 5 pages over your limit. Untick a document to continue." |
| P2, K2 | Zero pages left | "You have no pages left this month. Ask your administrator." |
| K1 | Code expired | "That code has expired." Button: "Get a new code" |
| K1, K2 | Cannot reach server | "Cannot reach the print server." Button: "Try again" |
| K3 | Printer problem | "The printer is out of paper. Your documents are still waiting." |
| A1 | No jobs match filter | "No jobs match." Button: "Clear filters" |

## Accessibility checks applied

- Controls are real buttons, links, inputs and labels.
- Text contrast is at least 4.5:1 against its background.
- Touch targets: 44 px minimum on phone and web, 64 px on the panel.
- Selected and status states use a label, shape or border as well as colour.
