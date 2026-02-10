# cto_simulator

Local build and deployment helpers for this Flutter app.

## iPhone (USB) local deploy

Use this when your iPhone is connected by cable:

```bash
bash scripts/deploy_ios_device.sh
```

If signing is not configured yet, open `ios/Runner.xcworkspace` in Xcode once,
set `Signing & Capabilities` for `Runner`, then run the script again.

## Same network distribution (LAN)

Build web and share it on your local network:

```bash
bash scripts/share_web_on_lan.sh 8080
```

Then open the printed URL from your phone (same Wi-Fi), for example:
`http://192.168.x.x:8080`

## Standard Flutter commands

- `flutter pub get`
- `flutter analyze`
- `flutter test`
