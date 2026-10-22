# 04 Design guidelines

The visual style is deliberately plain: a utility people use in ten seconds and forget.

## What we will not use

- AI-generated images, illustrations or mascots.
- Decorative icons, emoji, gradient backgrounds, glow or glass effects.
- Stock photos of people or offices.
- Vendor logos in buttons (the sign-in button is text).

Where guidance images are needed, use real screenshots of the real app and of the real printer panel, taken once the screens are built, and add numbered callouts in a plain tool. Until then the mockups in [`design/screens/`](design/screens/) serve as the guide images.

Icons are allowed only where text cannot do the job: sign out, tick. They are simple outline shapes drawn in the same stroke weight, always with a text or accessible label.

## Colour

| Role | Value | Use |
|---|---|---|
| Background | `#F4F6F8` | Screen background |
| Surface | `#FFFFFF` | Cards, header, footer |
| Text | `#16212C` | Body and headings |
| Muted text | `#4A5866` | Secondary text (7:1 on white) |
| Border | `#D5DBE1` | Card and field outlines |
| Primary | `#0B5CAD` | Print button, selection, progress |
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
