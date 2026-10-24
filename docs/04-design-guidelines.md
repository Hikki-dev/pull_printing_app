# 04 Design guidelines

The visual style is deliberately plain: a utility people use in ten seconds and forget.

## Imagery and logos

**Not used:** AI-generated images or mascots, stock photos, emoji, gradient washes, glow or glass effects.

**Used:**

| Item | Source | Notes |
|---|---|---|
| Microsoft logo on the sign-in button | Microsoft's published four-square mark and sign-in button rules | Required for "Sign in with Microsoft". Colours `#F25022 #7FBA00 #00A4EF #FFB900`, white button, grey border, grey text. Replace the drawn copy with the asset from Microsoft's branding page before release. |
| Pull Print mark | Our own, a document with text lines on the primary blue | Placeholder until the organisation supplies its own logo. |
| Printer illustration | Our own flat vector, two blues, one animated sheet | Used on sign-in and confirmation screens. Replace with a photo of the real printer once available. |
| Document thumbnails | Drawn from the file type: page with title bar and text lines, a file-type strip (PDF, DOCX, PNG) | In the build, replace with a real first-page preview from the server. |
| Avatars | Initials on a flat colour | Replace with the Microsoft profile photo if available. |

Only outline icons where text cannot do the job (sign out, printer, status). Each has a text or accessible label.

Guide images: the mockups in [`design/screens/`](design/screens/) for now. After build, use real screenshots with numbered callouts and a photo of the actual printer panel.

## Colour

| Role | Value | Use |
|---|---|---|
| Background | `#F4F6F8` | Screen background |
| Surface | `#FFFFFF` | Cards, header, footer |
| Text | `#16212C` | Body and headings |
| Muted text | `#4A5866` | Secondary text (7:1 on white) |
| Border | `#D5DBE1` | Card and field outlines |
| Primary | `#0B5CAD` | Print button, selection |
| Hero navy | `#0E2A47` | Headers, sign-in and confirmation backgrounds |
| Waiting | text on `#FFF0D1`, text `#6B4200` | Status label |
| Failed | text on `#FBE3E3`, text `#7A1F1F` | Status label |

One accent colour. Status is always a word, never colour alone.

## Type

Inter, falling back to the system font. Sizes in px.

| Use | Phone and web | Printer panel |
|---|---|---|
| Screen heading | 20–32 | 28–44 |
| Row title | 16 | 20 |
| Secondary text | 14 | 16–18 |
| Primary button | 17 | 24 |

Minimum text size is 13 px on phone and web, 16 px on the panel.

## Sizing and spacing

- Touch targets: 44 px minimum, 64 px on the panel.
- Rows are whole-row tap targets.
- Spacing steps: 8, 12, 16, 24, 32.
- Corner radius: 10–12 px on controls and cards.
- Primary button is the largest element on the screen.

## Mapping to Flutter

`frontend/lib/utils/theme.dart` currently uses `Colors.blue` and a blue app bar. Replace it with a `ThemeData` built from the table above (`ColorScheme.fromSeed` is not enough on its own, set the values explicitly). Keep `JobCard` as the row widget but make it a checkbox row with the sizes above, and make `QuotaIndicator` read "38 of 50 pages left" rather than "used / total pages".

## Checklist before a screen is done

- One primary action, visible without scrolling.
- Works at 390 px wide (phone) or 1024 × 600 (panel).
- Contrast checked, targets measured.
- Empty, over-quota and error states exist.
- Wording matches the [word list](03-screen-specs.md#wording).
