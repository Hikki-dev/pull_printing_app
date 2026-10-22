# 05 Open decisions

Questions that change the design. Each has a recommendation, but the answer is yours.

## 1. Is quota counted in pages or in jobs?

The README says quota "goes down by one" per print, which reads as per job. `QuotaIndicator` and the mockups use pages. Pages is fairer and matches paper cost, but it needs the server to know the page count of every job.

**Recommendation:** pages. The mockups assume it.

## 2. How does someone sign in at the printer?

Options: Microsoft device code (as drawn), staff card, or both. Device code needs only a screen and works today. Card is faster, but needs readers and a mapping from card to user.

**Recommendation:** ship device code first, add card when hardware exists. Card would then be the 5-second path.

## 3. Should phone release require being at the printer?

The product promise is that jobs print only when you are standing at the printer. If the phone can release to any printer, someone can print to a printer in another room and leave it in the tray.

Options: (a) phone view only shows jobs and sends people to the panel, (b) the phone must scan a code shown on the panel, (c) allow it, accept the risk.

**Recommendation:** (b). P2 would swap "Printer: Level 3 East" for a scan step.

## 4. What happens to jobs nobody collects?

Waiting jobs stay on the server. Options: expire after a set time (for example 24 hours) and say so on screen, or keep until deleted.

**Recommendation:** expire after 24 hours and show "Deleted after 24 hours" under each job. This is also better for privacy.

## 5. What happens when selection exceeds quota?

Drawn as: Print disabled and the shortfall shown. Alternative: print as many whole documents as fit.

**Recommendation:** as drawn. It is predictable.

## 6. How do files reach the server?

Nothing in the code creates a waiting job. This sets the whole front of the flow: a Windows print driver or print queue, email-to-print, a web upload page, or the phone app. It is not designed here.

**Recommendation:** decide before building the panel, because it determines the file types and the page-count source.

## 7. Does the panel run the Flutter app?

K1–K3 are sized for a 1024 × 600 touch screen. Running the same Flutter app in a kiosk mode on a small Windows or Linux device is the shortest route, and Flutter has Windows and Linux targets in this repo.

**Recommendation:** yes, with a kiosk route that has no back navigation and auto sign-out.
