# Basivo Fit (PulseFolio) for Android and iPhone

The Flutter version of [PulseFolio](../README.md). It has the same screens and design as the web app, with richer animations.

- **Animations:**
  - spring-style card entrances and count-up numbers
  - charts that draw themselves in
  - a heart that beats at your real heart rate
  - a circular reveal when switching theme
  - press feedback on cards and buttons
  - a sliding tab indicator
- **Screens:**
  - Today
  - Heart (day and week zone charts you can scrub, time in zones)
  - Sleep (stage chart and open quality rules)
  - Activity
  - Profile and Privacy
  - Sign in with Google, with a **No device connected** screen for accounts without a Fitbit or Pixel Watch
- **Live heart rate over Bluetooth:**
  - on the Heart tab, tap **Find a sensor** and pick your device
  - see every beat with a zone tag, a rolling chart (30 seconds widening to 2 minutes), session lowest/average/highest and live HRV (RMSSD)
  - the Today heart card switches to the live reading
  - the app reconnects to your last sensor on launch and after dropouts
  - works with any device that sends heart rate in the standard Bluetooth format: most chest straps and arm bands, and watches with a "broadcast heart rate" setting
  - Fitbit bands such as the Fitbit Air keep heart rate private to the Google Health app; for those, the app shows the latest reading from Google
- **No backend.** The app signs in with Google on the phone and reads the [Google Health API](https://developers.google.com/health) directly.
- **Accessible:**
  - 48dp touch targets and screen-reader labels
  - honours the reduce-motion setting
  - checked at 320px, 390px and tablet widths in both themes

## Install on Android

Every push to `main` builds the app on GitHub Actions:

1. Open the [latest Android build](../../releases/tag/mobile-latest) on your phone.
2. Download `app-release.apk` and open it.
3. Allow "Install unknown apps" for your browser if asked.

**iPhone:** installing needs a Mac with Xcode and an Apple Developer account. The project includes everything else; see "iPhone setup" below. Without those, use the web app, which installs from Safari with **Share → Add to Home Screen**.

## Google sign-in

The app signs in through Google's own page in your phone's browser (a Custom Tab on Android, the system sign-in sheet on iPhone).

**It uses the same Web OAuth client as the web app, so there is nothing extra to set up in Google Cloud.**

1. The app opens Google sign-in with the web client ID and the web app's address as the return address. That address is already allowed on the client.
2. Google returns to the web app. The web app sees that the sign-in came from the phone app and passes the result straight to the app through a `basivofit://` link. Nothing is stored on the web side.
3. The app keeps the access token on the phone and sends it only to Google. Signing out revokes it.

Notes:
- Google access tokens from this flow last about an hour. After that the app asks you to tap **Sign in with Google** again; Google remembers your choice, so it is quick.
- Your account must be in **Audience → Test users** while the Google app is in Testing.
- To use your own web deployment, build with `--dart-define=GOOGLE_WEB_CLIENT_ID=...` and `--dart-define=OAUTH_REDIRECT=https://your-site/`.

## Develop

```bash
flutter pub get
flutter test          # 32 tests: API parsing, Bluetooth packets, live sensor flows, sleep rules, every screen at 3 sizes and 150% text, sign-in flows
flutter run           # on a phone or emulator
```

On the web build, Google sign-in is off; use the demo. Share links work there:
- `?demo=1` opens the demo
- `&tab=heart|sleep|activity|profile` picks a tab
- `&theme=dark|light` sets the theme

## Layout

```
lib/
  data/      Google Health API client, Bluetooth heart rate sensor, models, demo data, sleep rules, Google sign-in
  state/     App state (sign-in, refresh every 60 s, cloud heart rate every 20 s), live Bluetooth sensor, theme
  theme/     Colour, spacing and motion tokens (same values as the web app)
  ui/        Screens, cards, custom-painted charts, animations, circular theme reveal
test/        Unit and widget tests
```

## Permissions

| Permission | Why |
|---|---|
| Internet | Reads your data from Google |
| Bluetooth (Android 12+: Nearby devices) | Finds and connects to a heart rate sensor, only when you tap **Find a sensor** or the app reconnects your saved sensor. Not used for location. |
| Location (Android 11 and older only) | Older Android versions require it to scan for Bluetooth devices |
