# 01 Product brief

## The one job

A person has sent a document to print. They walk to a printer, prove who they are, and get their pages. **Everything in the design serves that walk-up moment.** Sending a file and administering quotas matter, but they are not where speed is won or lost.

## Who uses it

| User | What they want | Where |
|---|---|---|
| Staff member | Collect their printing quickly and leave | At a printer panel, sometimes on their phone |
| Administrator | See all jobs, set page quotas, spot failures | Desktop browser |

A staff member is usually standing, often carrying things, and has no patience for menus. Design for that person, not for someone sitting at a desk.

## Speed targets

These are targets to design and test against, not measurements.

| Task | Target |
|---|---|
| Sign in at the printer to seeing own documents | Under 5 seconds with a card, under 15 with a phone code |
| Seeing own documents to pages printing | One tap (documents are pre-selected) |
| Whole walk-up visit | Under 10 seconds with a card |
| Taps needed to print everything waiting | 1 after sign-in |

## Principles

1. **One obvious action per screen.** The Print button is the largest thing on the release screen.
2. **Pre-select everything.** Most people want all their waiting documents. Unticking is the exception.
3. **Show only what is theirs.** No other person's file names, ever. This is the point of the product.
4. **Say how many pages and how many are left.** Quota surprises are the main thing that stops a print.
5. **Big touch targets.** At least 44 px on phone and web, at least 64 px on the printer panel.
6. **Sign out for them.** The panel signs out automatically so the next person never sees the last user's list.
7. **Plain words.** No jargon such as "release", "held" or "spool" in user-facing text. See [wording](03-screen-specs.md#wording).

## Scope of the mockups

In scope: phone sign-in, phone job list, phone confirmation, printer panel sign-in, release and confirmation, admin jobs and quotas.

Out of scope for now: how a file reaches the server (no submission path exists in the code yet), printer settings such as duplex or colour, card reader hardware, notifications.

## What exists in the code today

The Flutter app has a login screen, a held-jobs list and an admin list. The .NET API has release and set-quota endpoints. See the [README status](../README.md#current-status) for what does not work yet. The mockups are the target design; they do not describe current behaviour.
