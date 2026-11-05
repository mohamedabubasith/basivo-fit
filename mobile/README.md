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

## Google sign-in setup (once)

Use the same Google Cloud project as the web app, with the Google Health API enabled and the 7 scopes added under **Data access**. Then:

### Android
1. Go to **Google Auth Platform → Clients → Create client**.
2. Fill it in:
   - **Application type:** Android
   - **Package name:** `in.basivo.fit`
   - **SHA-1 certificate fingerprint:** `01:D5:24:D8:9B:E9:C4:B5:64:78:E3:9B:28:10:A0:0B:02:97:49:BD`
3. Keep your **Web application** client too. The Android app uses its Client ID as the "server client ID". It is set in `lib/data/auth.dart`; change it with `--dart-define=GOOGLE_WEB_CLIENT_ID=...`.
4. Make sure your Google account is listed under **Audience → Test users**.

The SHA-1 belongs to `android/app/debug.keystore`. That is a public debug key (password `android`), so every build, including the GitHub Actions ones, has the same fingerprint. Before publishing on Google Play, sign with your own private key and register that key's SHA-1 too.

### iPhone setup
1. Create an **iOS** client with bundle ID `in.basivo.basivoFit`, or the one you set in Xcode.
2. Build with `--dart-define=GOOGLE_IOS_CLIENT_ID=<ios client id>`.
3. In `ios/Runner/Info.plist`, add a `CFBundleURLTypes` entry whose URL scheme is the iOS client's **reversed** client ID (`com.googleusercontent.apps.…`).

## Develop

```bash
flutter pub get
flutter test          # 17 tests: API parsing, sleep rules, every screen at 3 sizes and 150% text, sign-in flows
flutter run           # on a phone or emulator
```

On the web build, Google sign-in is off; use the demo. Share links work there:
- `?demo=1` opens the demo
- `&tab=heart|sleep|activity|profile` picks a tab
- `&theme=dark|light` sets the theme

## Layout

```
lib/
  data/      Google Health API client, models, demo data, sleep quality rules, Google sign-in
  state/     App state (sign-in, data refresh every 60 s, live heart rate every 20 s) and theme
  theme/     Colour, spacing and motion tokens (same values as the web app)
  ui/        Screens, cards, custom-painted charts, animations, circular theme reveal
test/        Unit and widget tests
```
