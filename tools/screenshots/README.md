# Pictures for the docs

Every picture in `docs/images/` and the README is taken from the running app, so they stay true. Run these when a screen changes.

## What you need

* Node.js and [Playwright](https://playwright.dev) (`npm i -g playwright`), and a Chromium. Set `CHROMIUM=/path/to/chrome` if it is not at `/opt/pw-browsers/chromium`.
* Optional: `ROBOTO=/path/to/Roboto-Regular.ttf` so the page does not wait for Google Fonts.
* `ffmpeg` for the GIF.
* The web app built against the API, served by the API:

  ```bash
  flutter build web -t frontend/lib/main.dart --release --no-web-resources-cdn --dart-define=USE_MOCK=false
  dotnet publish backend -c Release -o /tmp/pp
  rm -rf /tmp/pp/wwwroot && cp -r build/web /tmp/pp/wwwroot
  ```

## Start four copies of the server

They differ only in how sign-in is set up, so each kind of screen can be shown.

```bash
cd /tmp/pp
KEY=0123456789012345678901234567890123456789          # for pictures only
# 1  the demo                                          (port 5055)
ASPNETCORE_URLS=http://127.0.0.1:5055 Demo__Enabled=true dotnet PullPrintingBackend.dll &
# 2  Google Workspace, demo off                        (port 5056)
ASPNETCORE_URLS=http://127.0.0.1:5056 Demo__Enabled=false Workspace__Provider=Google \
  Workspace__ClientId=x Workspace__ClientSecret=x Workspace__Domain=example.com Auth__SigningKey=$KEY \
  dotnet PullPrintingBackend.dll &
# 3  Microsoft 365, demo off                           (port 5057)
ASPNETCORE_URLS=http://127.0.0.1:5057 Demo__Enabled=false Workspace__Provider=Microsoft \
  Workspace__ClientId=x Workspace__ClientSecret=x Workspace__TenantId=11111111-1111-1111-1111-111111111111 \
  Auth__SigningKey=$KEY dotnet PullPrintingBackend.dll &
# 4  Google with the demo on, no signing key           (port 5058)
ASPNETCORE_URLS=http://127.0.0.1:5058 Demo__Enabled=true Workspace__Provider=Google \
  Workspace__ClientId=x Workspace__ClientSecret=x Workspace__Domain=example.com \
  dotnet PullPrintingBackend.dll &
```

## Take the pictures

```bash
node tools/screenshots/shoot.js docs/images            # every screenshot
node tools/screenshots/record.js /tmp/video            # the phone walk-through video
tools/screenshots/make-gif.sh /tmp/video/*.webm docs/images/demo.gif 5
```

`shoot.js` takes the four server addresses as optional arguments after the output folder. It reports any step that failed and exits with an error.

The two diagrams, `docs/images/how-it-fits.svg` and `sign-in-flow.svg`, are plain SVG files. Edit them by hand.

## Rules for pictures

* Take them from the app, never mock them up.
* Use the sample people and documents the demo starts with. No real names, addresses or secrets.
* Give every picture useful alt text where it is used.
